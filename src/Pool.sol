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
  uint public lastCheckpoint;

  IdNFT public dnft;
  DYAD public dyad;
  IAggregatorV3 internal priceFeed;

  uint256 constant private REDEEM_MINIMUM = 100000000;

  mapping(uint => int) public dyadDeltaAtCheckpoint;
  mapping(uint => int) public xpDeltaAtCheckpoint;
  mapping(uint => uint) public poolBalanceAtCheckpoint;

  event NewEthPrice(int newEthPrice);

  /// @dev Check if msg.sender is the nft contract
  modifier onlyNFT() {
    require(msg.sender == address(dnft), "Pool: Only NFT can call this function");
    _;
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

  /// @notice returns the amount that we need to mint/burn depending on the new eth price
  function getDeltaAmount(int newEthPrice) internal view returns (int deltaAmountSigned) {
    int  deltaPrice        = newEthPrice - int(lastEthPrice) ;
    uint deltaPricePercent = uint(newEthPrice).mul(10000).div(lastEthPrice);

    // we have to do this to get basis points in the correct range
    if (deltaPrice < 0) {
      deltaPricePercent = 10000 - deltaPricePercent;
    } else {
      deltaPricePercent -= 10000;
    }

    // uint poolBalance = dyad.balanceOf(address(this));
    uint deltaAmount = PoolLibrary.percentageOf(dyad.totalSupply(), deltaPricePercent);

    deltaAmountSigned = int(deltaAmount);

    // if the delta is negative we have to make deltaAmount negative as well
    if (deltaPrice < 0) {
      deltaAmountSigned = int(deltaAmount) * -1;
    }   
  }

  function sync() public returns (int newEthPrice) {
    newEthPrice = getNewEthPrice();

    int  deltaAmount    = getDeltaAmount(newEthPrice);
    uint deltaAmountAbs = PoolLibrary.abs(deltaAmount);

    updateNFTs(deltaAmountAbs);

    if (uint(newEthPrice) > lastEthPrice) {
      dyad.mint(address(this), deltaAmountAbs);
    } else {
      // What happens if there is not enough to burn?
      dyad.burn(deltaAmountAbs);
    }

    lastEthPrice    = uint(newEthPrice);
    lastCheckpoint += 1;
    emit NewEthPrice(newEthPrice);
  }

  // TODO: input eth_change in basis points
  function updateNFTs(uint deltaAmountAbs) internal {
    bool isBoosted = false;

    uint TOTAL_SUPPLY = 10; // of dnfts
    uint TOTAL_DYAD = 96003;

    uint MAX_XP = 8000;
    uint MIN_XP = 1079;

    bool isNegative = true;
    uint ETH_CHANGE = 500; // 10% in basis points

    uint multi_sum;
    uint multi_sum_burn;
    uint[] memory multiplier_products = new uint[](TOTAL_SUPPLY);
    uint[] memory multiplier_products_burn = new uint[](TOTAL_SUPPLY);
    uint[] memory minted_multis = new uint[](TOTAL_SUPPLY);

    uint wanted_mint = PoolLibrary.percentageOf(TOTAL_DYAD, ETH_CHANGE);
    console.log("wanted_mint: ", wanted_mint);

    uint average_minted = TOTAL_DYAD / TOTAL_SUPPLY;
    console.log("average_minted: ", average_minted);

    MintData memory mintData = mint();
    BurnData memory burnData = burn();

    for (uint i = 0; i < TOTAL_SUPPLY; i++) {
      console.log();
      console.logUint(i);

      IdNFT.Nft memory nft = dnft.idToNft(i);
      console.log("xp: ", nft.xp);
      console.log("deposit: ", nft.deposit);
      console.log("balance: ", nft.balance);

      uint xp_scaled = (nft.xp-MIN_XP) * 10000 / (MAX_XP-MIN_XP);
      console.log("xp scaled: ", xp_scaled);

      uint xp_multi = PoolLibrary.getXpMulti(xp_scaled / 100);
      if (isNegative) {
        xp_multi = 300 - xp_multi;
      }
      console.log("xp multi: ", xp_multi);

      uint mint_avg_minted = (nft.balance+nft.deposit)*10000/(average_minted+1);
      console.log("mint_avg_minted: ", mint_avg_minted);

      uint minted_multi = PoolLibrary.getXpMulti(xp_scaled / 100);
      console.log("minted_multi: ", minted_multi);

      uint deposit_multi = nft.deposit*10000/(nft.deposit+nft.balance+1);
      console.log("deposit multi: ", deposit_multi);

      uint multi_product = xp_multi * deposit_multi/100;
      console.log("multi product: ", multi_product);

      uint multi_product_burn = xp_multi * mint_avg_minted/100;
      console.log("multi_product_burn", multi_product_burn);

      multi_sum      += multi_product;
      multi_sum_burn += multi_product_burn;
      multiplier_products[i]      = multi_product;
      multiplier_products_burn[i] = multi_product_burn;
      minted_multis[i] = minted_multi;
    }

    console.log();
    // ROUNDING ERROR OF A COUPLE OF BASIS POINTS
    console.log("multi sum: ", multi_sum_burn);
    console.log();

    uint percentage_change;
    for (uint i = 0; i < TOTAL_SUPPLY; i++) {
      if (isNegative) {
        percentage_change = multiplier_products_burn[i]*10000 / multi_sum_burn;
      } else {
        percentage_change = multiplier_products[i]*10000 / multi_sum;
      }

      console.log("percentage change: ", percentage_change);

      uint minting_allocation = PoolLibrary.percentageOf(wanted_mint, percentage_change);
      console.log("minting allocation: ", minting_allocation);

      uint xp_accrual;
      if (isNegative) {
        xp_accrual = minting_allocation * 100 / (minted_multis[i]);
      }
      console.log("xp_accrual", xp_accrual);

      //--------------- STATE UPDATE ----------------
      IdNFT.Nft memory nft = dnft.idToNft(i);
      nft.deposit += minting_allocation;

      // boost for the address calling this function
      // if (!isBoosted && msg.sender == dnft.idToOwner(i)) {
      //   console.log("boosting");
      //   isBoosted = true;
      //   nft.xp += PoolLibrary.percentageOf(nft.xp, 10); // 0.1%
      // }

      console.log();
    }
  }

  struct MintData {
    uint multiSum;
    uint[] multiProducts;
  }

  struct BurnData {
    uint multiSum;
    uint[] multiProducts;
    uint[] mintedMultis;
  }

  function burn() internal returns (BurnData memory) {
    uint TOTAL_SUPPLY = 10; // of dnfts
    uint MAX_XP = 8000;
    uint MIN_XP = 1079;
    uint TOTAL_DYAD = 96003;

    uint AVG_MINTED = TOTAL_DYAD / TOTAL_SUPPLY;

    uint multiSum;
    uint[] memory multiProducts = new uint[](TOTAL_SUPPLY);
    uint[] memory mintedMultis  = new uint[](TOTAL_SUPPLY);

    for (uint i = 0; i < TOTAL_SUPPLY; i++) {
      IdNFT.Nft memory nft = dnft.idToNft(i);
      uint xpScaled = (nft.xp-MIN_XP)*10000 / (MAX_XP-MIN_XP);
      uint xpMulti  = 300 - (PoolLibrary.getXpMulti(xpScaled/100));
      uint mintAvgMinted = (nft.balance+nft.deposit)*10000 / (AVG_MINTED+1);
      uint mintedMulti   = PoolLibrary.getXpMulti(xpScaled/100);
      uint depositMulti  = nft.deposit*10000 / (nft.deposit+nft.balance+1);
      uint multiProduct  = xpMulti * mintAvgMinted/100;

      multiSum        += multiProduct;
      multiProducts[i] = multiProduct;
      mintedMultis[i]  = mintedMulti;
    }

    return BurnData(multiSum, multiProducts, mintedMultis);
  }

  function mint() internal returns (MintData memory) {
    uint TOTAL_SUPPLY = 10; // of dnfts
    uint MAX_XP = 8000;
    uint MIN_XP = 1079;
    uint TOTAL_DYAD = 96003;

    uint AVG_MINTED = TOTAL_DYAD / TOTAL_SUPPLY;

    uint multiSum;
    uint[] memory multiProducts = new uint[](TOTAL_SUPPLY);

    for (uint i = 0; i < TOTAL_SUPPLY; i++) {
      IdNFT.Nft memory nft = dnft.idToNft(i);
      uint xpScaled = (nft.xp-MIN_XP)*10000 / (MAX_XP-MIN_XP);
      uint xpMulti  = PoolLibrary.getXpMulti(xpScaled/100);
      uint mintAvgMinted = (nft.balance+nft.deposit)*10000 / (AVG_MINTED+1);
      uint mintedMulti   = PoolLibrary.getXpMulti(xpScaled/100);
      uint depositMulti  = nft.deposit*10000 / (nft.deposit+nft.balance+1);
      uint multiProduct  = xpMulti * depositMulti/100;

      multiSum        += multiProduct;
      multiProducts[i] = multiProduct;
    }

    return MintData(multiSum, multiProducts);
  }

  /// @notice Mint dyad to the NFT
  function mintDyad(uint minAmount) payable external onlyNFT returns (uint) {
    require(msg.value > 0,        "Pool: You need to send some ETH");
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
    require(amount > REDEEM_MINIMUM, "Pool: Amount must be greater than 100000000");
    // msg.sender has to approve pool to spend its tokens
    dyad.transferFrom(msg.sender, address(this), amount);
    dyad.burn(amount);

    uint usdInEth = amount.mul(100000000).div(lastEthPrice);
    payable(msg.sender).transfer(usdInEth);
  }
}

