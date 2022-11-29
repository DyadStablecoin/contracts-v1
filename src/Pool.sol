// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import {DYAD} from "../src/dyad.sol";
import {IAggregatorV3} from "../src/interfaces/AggregatorV3Interface.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {PoolLibrary} from "../src/PoolLibrary.sol";

contract Pool {
  // IMPORTANT: do not change the ordering of these variables
  // because some tests depend on this specific slot arrangement.
  uint public lastEthPrice;

  IdNFT public dnft;
  DYAD public dyad;
  IAggregatorV3 internal priceFeed;

  uint256 constant private REDEEM_MINIMUM = 100000000;

  // when syncing, the protocol can be in two states:
  //   BURNING: if the price of eth went down
  //   MINTING: if the price of eth went up
  enum Mode{ BURNING, MINTING }

  event Synced (uint newEthPrice);
  event NftClaimed(uint indexed id, address indexed from, address indexed to);

  /// @dev Check if msg.sender is the nft contract
  modifier onlyNftContract() {
    require(msg.sender == address(dnft), "Pool: Only callable by NFT contract");
    _;
  }

  // A convenient way to store the ouptput of the `calcMultis` function
  struct Multis {
    // Holds two different sort of values depending on wheather the 
    // protocoll is in BURNING or MINTING mode.
    //   Mode.MINTING: xp mulit * deposit multi
    //   Mode.BURNING: xp mulit * mintAvg  
    uint[] multiProducts;

    uint   multiProductsSum; // sum of the elements in `multiProducts`
    uint[] xpMultis;         
  }

  constructor(address _dnft, address _dyad, address oracle) {
    dnft         = IdNFT(_dnft);
    dyad         = DYAD(_dyad);
    priceFeed    = IAggregatorV3(oracle);
    lastEthPrice = uint(getNewEthPrice());
  }

  /// @notice get the latest eth price from oracle
  function getNewEthPrice() internal view returns (int newEthPrice) {
    ( , newEthPrice, , , ) = priceFeed.latestRoundData();
  }


  // The "heart" of the protocol.
  // - Gets the latest eth price and determines if new dyad should be minted or
  //   old dyad should be burned to keep the peg.
  // - Updates each dnft metadata to reflect its updated xp, withdrawn and 
  //   deposit.
  // - To incentivize nft holders to call this method, there is a xp boost to 
  //   the first nft of the owner calling it.
  // NOTE: check out this google sheet to get a better overview of the equations:
  // https://docs.google.com/spreadsheets/d/1pegDYo8hrOQZ7yZY428F_aQ_mCvK0d701mygZy-P04o/edit#gid=0
  function sync() public returns (uint) {
    uint newEthPrice = uint(getNewEthPrice());
    // determine the mode we are in
    Mode mode = newEthPrice > lastEthPrice ? Mode.MINTING 
                                           : Mode.BURNING;
 
    // stores the eth price change in basis points
    uint ethChange = newEthPrice*10000/lastEthPrice;
    // we have to do this to get the percentage in basis points
    mode == Mode.BURNING ? ethChange  = 10000 - ethChange 
                         : ethChange -= 10000;

    // the amount of dyad to burn/mint
    uint dyadDelta = updateNFTs(ethChange, mode);

    mode == Mode.MINTING ? dyad.mint(address(this), dyadDelta) 
                         : dyad.burn(dyadDelta);

    lastEthPrice = newEthPrice;
    emit Synced(newEthPrice);
    return dyadDelta;
  }

  /// @param ethChange  Eth price change in basis points
  /// @param mode Is the change negative or positive
  /// @return dyadDelta The amount of dyad to mint or burn
  function updateNFTs(uint ethChange, Mode mode) internal returns (uint) {
    // we boost the nft of the user calling this function with additional
    // xp, but only once! If boosted was used already, it can not be used again.
    bool isBoosted = false;

    // the amount to mint/burn to keep the peg
    uint dyadDelta = PoolLibrary.percentageOf(dyad.totalSupply(), ethChange);

    Multis memory multis = calcMultis(mode);

    // we use these to keep track of the max/min xp values for this sync, 
    // so we can save them in storage to be used in the next sync.
    uint minXp = type(uint256).max;
    uint maxXp = dnft.MAX_XP();

    for (uint i = 0; i < dnft.totalSupply(); i++) {
      uint id = dnft.tokenByIndex(i);
      // multi normalized by the multi sum
      uint relativeMulti = multis.multiProducts[id]*10000/multis.multiProductsSum;
      // relative dyad delta for each nft
      uint relativeDyadDelta = PoolLibrary.percentageOf(dyadDelta, relativeMulti);

      IdNFT.Nft memory nft = dnft.idToNft(id);

      // xp accrual happens only when there is a burn.
      uint xpAccrual;
      if (mode == Mode.BURNING) {
        // normal accrual
        xpAccrual = relativeDyadDelta*100 / (multis.xpMultis[id]);
        // boost for the address calling this function
        if (!isBoosted && msg.sender == dnft.ownerOf(id)) {
          isBoosted = true;
          xpAccrual += PoolLibrary.percentageOf(nft.xp, 10); // 0.10%
        }
      }

      // update memory nft data
      if (mode == Mode.BURNING) {
        nft.deposit -= int(relativeDyadDelta);
        nft.xp      += xpAccrual;
      } else {
        // NOTE: there is no xp accrual in Mode.MINTING
        nft.deposit += int(relativeDyadDelta);
      }

      // update nft in storage
      dnft.updateNft(id, nft);

      // check if this is a new xp minimum/maximum for this sync
      if (nft.xp < minXp) { minXp = nft.xp; }
      if (nft.xp > maxXp) { maxXp = nft.xp; }
    }

    // save new min/max xp in storage
    dnft.updateXP(minXp, maxXp);
    return dyadDelta;
  }


  // NOTE: calculation of the multis is determined by the `mode`
  function calcMultis(Mode mode) internal returns (Multis memory) {
    uint nftTotalSupply = dnft.totalSupply();
    uint multiProductsSum;
    uint[] memory multiProducts = new uint[](nftTotalSupply);
    uint[] memory xpMultis      = new uint[](nftTotalSupply);

    for (uint i = 0; i < nftTotalSupply; i++) {
      uint id = dnft.tokenByIndex(i);
      IdNFT.Nft memory nft = dnft.idToNft(id);

      uint multiProduct; // 0 by default
      uint xpMulti;      // 0 by default

      if (nft.deposit >= 0 ) {
        // NOTE: MAX_XP - MIN_XP could be 0!
        uint xpScaled      = (nft.xp-dnft.MIN_XP())*10000 / (dnft.MAX_XP()-dnft.MIN_XP());
        uint mintAvgMinted = (nft.withdrawn+uint(nft.deposit))*10000 / (dyad.totalSupply()/nftTotalSupply+1);
        xpMulti           = PoolLibrary.getXpMulti(xpScaled/100);
        if (mode == Mode.BURNING) { xpMulti = 300-xpMulti; }
        uint depositMulti = uint(nft.deposit)*10000 / (uint(nft.deposit)+nft.withdrawn+1);
        multiProduct      = xpMulti * (mode == Mode.BURNING ? mintAvgMinted : depositMulti) / 100;
      } 

      multiProducts[id]  = multiProduct;
      multiProductsSum  += multiProduct;
      xpMultis[id]       = xpMulti;
    }

    // so we avoid dividing by 0 in `sync`
    if (multiProductsSum == 0) { multiProductsSum = 1; }

    return Multis(multiProducts, multiProductsSum, xpMultis);
  }

  /// @notice Mint dyad to the NFT
  function mintDyad(uint minAmount) payable external onlyNftContract returns (uint) {
    require(msg.value > 0, "Pool: You need to send some ETH");
    uint newDyad = uint(getNewEthPrice()) * msg.value/100000000;
    require(newDyad >= minAmount, "Pool: mintDyad: minAmount not reached");
    dyad.mint(msg.sender, newDyad);
    return newDyad;
  }

  /// @notice Deposit dyad into the pool
  /// @param amount The amount of dyad to deposit
  function deposit(uint amount) external onlyNftContract {
    dyad.transferFrom(msg.sender, address(this), amount);
  }

  /// @notice Withdraw dyad from the pool to the receiver
  /// @param amount The amount of dyad to withdraw
  /// @param receiver The address to withdraw dyad to
  function withdraw(address receiver, uint amount) external onlyNftContract {
    dyad.transfer(receiver, amount);
  }

  /// @notice Redeem dyad for eth
  function redeem(uint amount) public {
    // we do this to avoid rounding errors
    require(amount >= REDEEM_MINIMUM, "Pool: Redemption must be > 100000000");
    // msg.sender has to approve pool to spend its tokens and burn it
    dyad.transferFrom(msg.sender, address(this), amount);
    dyad.burn(amount);

    uint usdInEth = amount*100000000 / lastEthPrice;
    payable(msg.sender).transfer(usdInEth);
  }

  /// @notice Calim a liquidated nft
  // transfer liquidated nft from the old owner to new owner
  // IMPORTANT: the pool has the ability to transfer any nft without
  // any approvals.
  function claim(uint id, address receiver) external payable returns (uint) {
    IdNFT.Nft memory nft = dnft.idToNft(id);
    // emit before we burn, otherwise ownerOf(id) will fail!
    emit NftClaimed(id, dnft.ownerOf(id), receiver); 
    dnft.burn(id); // burn nft
    require(nft.deposit < 0, "dNFT: NFT is not liquidatable");
    // how much eth is required to cover the negative deposit
    uint ethRequired = uint(-nft.deposit) * lastEthPrice/100000000;
    // mint new nft with the xp of the old one
    return dnft.mintNftCopy{value: msg.value}(receiver, nft, ethRequired);
  }
}
