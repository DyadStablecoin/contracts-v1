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

  function updateNFTs(uint deltaAmountAbs) internal {
    bool isBoosted = false;
    uint nftTotalSupply  = dnft.totalSupply();

    for (uint i = 0; i < nftTotalSupply; i++) {
      updateNFT(i, deltaAmountAbs, isBoosted);
    }
  }


  function updateNFT(uint i, uint deltaAmountAbs, bool isBoosted) internal {
    console.log();
    console.logUint(i);
    // TODO: delta amount relative to each nft
    // updateNFT(i, deltaAmount);
    IdNFT.Nft memory nft = dnft.idToNft(i);
    console.logUint(nft.xp);

    // pool deposit percentage in basis points
    uint depositPoolRatio = nft.deposit * 10000 / dyad.balanceOf(address(this));
    console.logUint(depositPoolRatio);

    uint totalMinted = nft.deposit + nft.balance;
    uint mintedRatio = totalMinted * 10000 / dyad.totalSupply();
    console.logUint(mintedRatio);

    uint xpRatio = nft.xp * 10000 / dnft.totalXp();
    console.logUint(xpRatio);

    uint xpDeviation = 0;

    uint prorata  = PoolLibrary.percentageOf(deltaAmountAbs, depositPoolRatio);
    uint withXP   = prorata.mul(xpDeviation);
    uint smoothed = ((xpDeviation * prorata)+withXP)/(xpDeviation+1);
    console.logUint(prorata);

    // give xp boost to caller
    // boost can only happen once
    if (!isBoosted && dnft.idToOwner(i) == msg.sender) {
      isBoosted = true;
      nft.xp = nft.xp.add(PoolLibrary.percentageOf(nft.xp, 100)); // 1% boost
    }

    dnft.updateNft(i, nft);
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

