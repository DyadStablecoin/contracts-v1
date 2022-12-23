// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DYAD} from "./Dyad.sol";
import {IAggregatorV3} from "../interfaces/AggregatorV3Interface.sol";
import {IdNFT} from "../interfaces/IdNFT.sol";
import {PoolLibrary} from "../libraries/PoolLibrary.sol";

contract Pool {
  // IMPORTANT: do not change the ordering of these variables
  // because some tests depend on this specific slot arrangement.
  uint public lastEthPrice;

  IdNFT public dnft;
  DYAD public dyad;
  IAggregatorV3 internal priceFeed;

  // here we store the min/max value of xp over every dNFT,
  // which allows us to do a normalization, without iterating over
  // all of them to find the min/max value.
  uint public MIN_XP; uint public MAX_XP;

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

    // before calling the `sync` function this will be the highest xp possible, 
    // which will be assigned to the first minted nft.
    uint maxSupply = dnft.MAX_SUPPLY();
    MIN_XP = maxSupply;
    MAX_XP = maxSupply * 2;
  }

  function setMinXp(uint _minXp) external onlyNftContract { MIN_XP = _minXp; }

  // get the latest eth price from oracle
  function getNewEthPrice() internal view returns (int newEthPrice) {
    // NOTE: this can not be negative! (hopefully)
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
  function updateNFTs(uint ethChange, Mode mode) private returns (uint) {
    // we boost the nft of the user calling this function with additional
    // xp, but only once! If boosted was used already, it can not be used again.
    bool isBoosted = false;

    // the amount to mint/burn to keep the peg
    uint dyadDelta = PoolLibrary.percentageOf(dyad.totalSupply(), ethChange);

    Multis memory multis = calcMultis(mode);

    // we use these to keep track of the max/min xp values for this sync, 
    // so we can save them in storage to be used in the next sync.
    uint minXp = type(uint256).max;
    uint maxXp = MAX_XP;

    uint totalSupply = dnft.totalSupply();
    for (uint i = 0; i < totalSupply; i++) {
      uint tokenId = dnft.tokenByIndex(i);
      // multi normalized by the multi sum
      uint relativeMulti = multis.multiProducts[i]*10000 / multis.multiProductsSum;
      // relative dyad delta for each nft
      uint relativeDyadDelta = PoolLibrary.percentageOf(dyadDelta, relativeMulti);

      IdNFT.Nft memory nft = dnft.idToNft(tokenId);

      // xp accrual happens only when there is a burn.
      uint xpAccrual;
      // there can only be xp accrual if deposit is not 0 
      if (mode == Mode.BURNING && nft.deposit > 0) {
        // normal accrual
        xpAccrual = relativeDyadDelta*100 / (multis.xpMultis[i]);
        // boost for the address calling this function
        if (!isBoosted && msg.sender == dnft.ownerOf(tokenId)) {
          isBoosted = true;
          xpAccrual *= 2;
        }
      }

      // update memory nft data
      if (mode == Mode.BURNING) {
        nft.deposit -= int(relativeDyadDelta);
        nft.xp      += xpAccrual/(10**18); // normalize by the dyad decimals
      } else {
        // NOTE: there is no xp accrual in Mode.MINTING
        nft.deposit += int(relativeDyadDelta);
      }

      // update nft in storage
      dnft.updateNft(tokenId, nft);

      // check if this is a new xp minimum/maximum for this sync
      if (nft.xp < minXp) { minXp = nft.xp; }
      if (nft.xp > maxXp) { maxXp = nft.xp; }
    }

    // save new min/max xp in storage
    MIN_XP = minXp;
    MAX_XP = maxXp;

    return dyadDelta;
  }

  // NOTE: calculation of the multis is determined by the `mode`
  function calcMultis(Mode mode) private returns (Multis memory) {
    uint nftTotalSupply = dnft.totalSupply();
    uint multiProductsSum;
    uint[] memory multiProducts = new uint[](nftTotalSupply);
    uint[] memory xpMultis      = new uint[](nftTotalSupply);

    for (uint i = 0; i < nftTotalSupply; i++) {
      // get nft by token id
      IdNFT.Nft memory nft = dnft.idToNft(dnft.tokenByIndex(i));

      uint multiProduct; // 0 by default
      uint xpMulti;      // 0 by default

      if (nft.deposit > 0) {
        // NOTE: From here on, uint(nft.deposit) is fine because it is not negative
        uint xpDelta =  MAX_XP - MIN_XP;
        if (xpDelta == 0) { xpDelta = 1; } // avoid division by 0
        uint xpScaled = ((nft.xp-MIN_XP)*10000) / xpDelta;
        uint mintAvgMinted = ((nft.withdrawn+uint(nft.deposit))*10000) / (dyad.totalSupply()/(nftTotalSupply+1));
        if (mode == Mode.BURNING && mintAvgMinted > 20000) { mintAvgMinted = 20000; } // limit to 200%
        xpMulti = PoolLibrary.getXpMulti(xpScaled/100);
        if (mode == Mode.BURNING) { xpMulti = 300-xpMulti; } // should be 292: 242+50
        uint depositMulti = (uint(nft.deposit)*10000) / (uint(nft.deposit)+(nft.withdrawn+1));
        multiProduct = xpMulti * (mode == Mode.BURNING ? mintAvgMinted : depositMulti) / 100;
      } 

      multiProducts[i]  = multiProduct;
      multiProductsSum  += multiProduct;
      xpMultis[i]       = xpMulti;
    }

    // so we avoid dividing by 0 in `sync`
    if (multiProductsSum == 0) { multiProductsSum = 1; }

    return Multis(multiProducts, multiProductsSum, xpMultis);
  }

  // Mint dyad to the NFT
  function mintDyad(uint minAmount) payable external onlyNftContract returns (uint) {
    require(msg.value > 0, "Pool: You need to send some ETH");
    uint newDyad = uint(getNewEthPrice()) * msg.value/100000000;
    require(newDyad >= minAmount, "Pool: mintDyad: minAmount not reached");
    dyad.mint(msg.sender, newDyad);
    return newDyad;
  }

  function deposit(uint amount) external onlyNftContract {
    dyad.transferFrom(msg.sender, address(this), amount);
  }

  function withdraw(address receiver, uint amount) external onlyNftContract {
    dyad.transfer(receiver, amount);
  }

  function redeem(address receiver, uint amount) external onlyNftContract returns (uint usdInEth) {
    dyad.burn(amount);
    // the equivalent amount of USD denominated in ETH
    usdInEth = amount*100000000 / lastEthPrice;
    payable(receiver).transfer(usdInEth);
    return usdInEth;
  }

  // Calim a liquidated nft
  // transfer liquidated nft from the old owner to new owner
  // IMPORTANT: the pool has the ability to transfer any nft without
  // any approvals.
  function claim(uint id, address receiver) external payable returns (uint) {
    IdNFT.Nft memory nft = dnft.idToNft(id);
    // emit before we burn, otherwise ownerOf(id) will fail!
    emit NftClaimed(id, dnft.ownerOf(id), receiver); 
    dnft.burn(id); // burn nft
    require(nft.deposit < 0, "dNFT: NFT is not liquidatable");
    // mint new nft with the xp, withdrawn data of the old one.
    return dnft.mintNftCopy{value: msg.value}(receiver, nft);
  }
}
