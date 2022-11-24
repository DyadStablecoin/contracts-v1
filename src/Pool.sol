// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {DYAD} from "../src/dyad.sol";
import {IAggregatorV3} from "../src/AggregatorV3Interface.sol";
import {IdNFT} from "../src/IdNFT.sol";
import {PoolLibrary} from "../src/PoolLibrary.sol";

contract Pool {
  using SafeMath for uint256;

  // IMPORTANT: do not change the ordering of these variables
  // because some tests depend on this specific slot arrangement.
  uint public lastEthPrice;

  IdNFT public dnft;
  DYAD public dyad;
  IAggregatorV3 internal priceFeed;

  uint256 constant private REDEEM_MINIMUM = 100000000;

  // -------------------- ONLY FOR TESTING --------------------
  uint TOTAL_SUPPLY = 10; // of dnfts
  uint MAX_XP = 8000;
  uint MIN_XP = 1079;
  uint TOTAL_DYAD = 96003;
  uint AVG_MINTED = TOTAL_DYAD / TOTAL_SUPPLY;
  int OLD_ETH_PRICE = 100000000;
  int NEW_ETH_PRICE = 95000000;  // 95000000  ->  -5%
  // int NEW_ETH_PRICE = 110000000; // 110000000 -> +10%
  // ---------------------------------------------------------

  // when syncing, the protocol can be in two states:
  //   BURNING: if the price of eth went down
  //   MINTING: if the price of eth went up
  enum Mode{ BURNING, MINTING }

  event Synced(int newEthPrice);

  /// @dev Check if msg.sender is the nft contract
  modifier onlyNFT() {
    require(msg.sender == address(dnft), "Pool: Only NFT can call this function");
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

  constructor(address _dnft, address _dyad) {
    dnft         = IdNFT(_dnft);
    dyad         = DYAD(_dyad);
    priceFeed    = IAggregatorV3(PoolLibrary.PRICE_ORACLE_ADDRESS);
    lastEthPrice = uint(getNewEthPrice());
  }

  /// @notice get the latest eth price from oracle
  function getNewEthPrice() internal view returns (int newEthPrice) {
    // TODO: testing
    // ( , newEthPrice, , , ) = priceFeed.latestRoundData();
    newEthPrice = 115000000000;
  }


  // The "heart" of the protocol.
  // - Gets the latest eth price and determines if new dyad should be minted or
  //   old dyad should be burned to keep the peg.
  // - Updates each dnft metadata to reflect its updated xp, balance and deposit.
  // - To incentivize nft holders to call this method, there is a xp boost to the first
  //   nft of the owner calling it.
  function sync() public {
    // determine the mode we are in
    Mode mode = NEW_ETH_PRICE > OLD_ETH_PRICE ? Mode.MINTING : Mode.BURNING;
 
    // stores the eth price change in basis points
    uint ethChange = uint(NEW_ETH_PRICE).mul(10000).div(uint(OLD_ETH_PRICE));
    // we have to do this to get the percentage in basis points
    mode == Mode.BURNING ? ethChange = 10000 - ethChange : ethChange -= 10000;

    // the amount of dyad to burn/mint
    uint dyadDelta = updateNFTs(ethChange, mode);
    console.log("dyadDelta: %s", dyadDelta);

    if (mode == Mode.MINTING) {
      dyad.mint(address(this), dyadDelta);
    } else {
      // What happens if there is not enough to burn?
      // TODO
      // dyad.burn(dyadDelta);
    }

    lastEthPrice = uint(NEW_ETH_PRICE);
    emit Synced(NEW_ETH_PRICE);
  }

  /// @param ethChange  Eth price change in basis points
  /// @param mode Is the change negative or positive
  /// @return dyadDelta The amount of dyad to mint or burn
  function updateNFTs(uint ethChange, Mode mode) internal returns (uint dyadDelta) {
    // we boost the nft of the user calling this function with additional
    // xp, but only once! If boosted was used already, it can not be used again.
    bool isBoosted = false;

    // the amount to mint/burn to keep the peg
    dyadDelta = PoolLibrary.percentageOf(TOTAL_DYAD, ethChange);

    Multis memory multis = calcMultis(mode);

    // we use these to keep track of the max/min xp values for this sync, 
    // so we can save them in storage to be used in the next sync.
    uint minXp = type(uint256).max;
    uint maxXp = MAX_XP;

    for (uint id = 0; id < TOTAL_SUPPLY; id++) {
      // multi normalized by the multi sum
      uint relativeMulti     = multis.multiProducts[id]*10000/multis.multiProductsSum;
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
        // we cap nft.deposit at 0, so it can never become negative
        nft.deposit  = nft.deposit < relativeDyadDelta ? 0 : nft.deposit - relativeDyadDelta;
        nft.xp      += xpAccrual;
      } else {
        // NOTE: there is no xp accrual in Mode.MINTING
        nft.deposit += relativeDyadDelta;
      }

      // check for liquidation
      if (mode == Mode.BURNING) {
        // liquidation limit is 5% of the minted dyad
        uint liquidationLimit = PoolLibrary.percentageOf(nft.deposit+nft.balance, 500);
        if (nft.deposit < liquidationLimit) { nft.isClaimable = true; }
      }

      // update nft in storage
      dnft.updateNft(id, nft);

      // check if this is a new xp minimum/maximum for this sync
      if (nft.xp < minXp) { minXp = nft.xp; }
      if (nft.xp > maxXp) { maxXp = nft.xp; }
    }

    // save new min/max xp in storage
    MIN_XP = minXp;
    MAX_XP = maxXp;
  }


  // NOTE: calculation of the multis is determined by the `mode`
  function calcMultis(Mode mode) internal view returns (Multis memory) {
    uint multiProductsSum;
    uint[] memory multiProducts = new uint[](TOTAL_SUPPLY);
    uint[] memory xpMultis      = new uint[](TOTAL_SUPPLY);

    for (uint id = 0; id < TOTAL_SUPPLY; id++) {
      IdNFT.Nft memory nft = dnft.idToNft(id);

      uint xpScaled      = (nft.xp-MIN_XP)*10000 / (MAX_XP-MIN_XP);
      uint mintAvgMinted = (nft.balance+nft.deposit)*10000 / (AVG_MINTED+1);
      uint xpMulti       = PoolLibrary.getXpMulti(xpScaled/100);
      if (mode == Mode.BURNING) { xpMulti = 300-xpMulti; }
      uint depositMulti = nft.deposit*10000 / (nft.deposit+nft.balance+1);
      uint multiProduct = xpMulti/100 * (mode == Mode.BURNING ? mintAvgMinted : depositMulti);

      multiProducts[id]  = multiProduct;
      multiProductsSum  += multiProduct;
      xpMultis[id]       = xpMulti;
    }

    return Multis(multiProducts, multiProductsSum, xpMultis);
  }

  /// @notice Mint dyad to the NFT
  function mintDyad(uint minAmount) payable external onlyNFT returns (uint) {
    require(msg.value > 0, "Pool: You need to send some ETH");
    uint newDyad = lastEthPrice.mul(msg.value).div(100000000);
    require(newDyad >= minAmount, "Pool: mintDyad: minAmount not reached");
    dyad.mint(msg.sender, newDyad);
    return newDyad;
  }

  /// @notice Deposit dyad into the pool
  /// @param amount The amount of dyad to deposit
  function deposit(uint amount) external onlyNFT {
    dyad.transferFrom(msg.sender, address(this), amount);
  }

  /// @notice Withdraw dyad from the pool to the recipient
  /// @param amount The amount of dyad to withdraw
  /// @param recipient The address to withdraw dyad to
  function withdraw(address recipient, uint amount) external onlyNFT {
    dyad.transfer(recipient, amount);
  }

  /// @notice Redeem dyad for eth
  function redeem(uint amount) public {
    // we do this to avoid rounding errors
    require(amount > REDEEM_MINIMUM, "Pool: Amount must be greater than 100000000");
    // msg.sender has to approve pool to spend its tokens
    dyad.transferFrom(msg.sender, address(this), amount);
    dyad.burn(amount);

    uint usdInEth = amount.mul(100000000).div(lastEthPrice);
    payable(msg.sender).transfer(usdInEth);
  }

  /// @notice Calim a liquidated nft
  // transfer liquidated nft from the old owner to new owner
  // IMPORTANT: the pool has the ability to transfer any nft without
  // any approvals.
  function claim(uint id, address recipient) external {
    IdNFT.Nft memory nft = dnft.idToNft(id);
    require(nft.isClaimable, "dNFT: NFT is not liquidated");
    address owner = dnft.ownerOf(id);
    dnft.transferFrom(owner, recipient, id);
  }

}

