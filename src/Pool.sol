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
    ( , newEthPrice, , , ) = priceFeed.latestRoundData();
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

    uint poolBalance = dyad.balanceOf(address(this));
    uint deltaAmount = PoolLibrary.percentageOf(poolBalance, deltaPricePercent);

    // if the delta is negative we have to make deltaAmount negative as well
    if (deltaPrice < 0) {
      deltaAmountSigned = int(deltaAmount) * -1;
    }
  }

  function sync() public returns (int newEthPrice) {
    newEthPrice = getNewEthPrice();

    int  deltaAmount    = getDeltaAmount(newEthPrice);
    uint deltaAmountAbs = PoolLibrary.abs(deltaAmount);

    if (uint(newEthPrice) > lastEthPrice) {
      dyad.mint(address(this), deltaAmountAbs);
    } else {
      // What happens if there is not enough to burn?
      dyad.burn(deltaAmountAbs);
    }

    updateNFTs(deltaAmount);

    lastEthPrice    = uint(newEthPrice);
    lastCheckpoint += 1;
    emit NewEthPrice(newEthPrice);
  }

  function updateNFTs(int deltaAmount) internal {
    uint nftTotalSupply  = dnft.totalSupply();

    for (uint i = 0; i < nftTotalSupply; i++) {
      // TODO: delta amount relative to each nft
      updateNFT(i, deltaAmount);
    }
  }

  function updateNFT(uint id, int deltaAmount) internal {
    IdNFT.Nft memory nft = dnft.idToNft(id);

    // --------------- calculte factors -------------
    // boost factor
    uint  boostFactor   = getBoostFactor(id);

    // xp factor
    uint8 xpNormal      = PoolLibrary.normalize(nft.xp, dnft.MAX_XP());
    uint  xpFactor      = PoolLibrary.getXpMulti(xpNormal);

    if (deltaAmount < 0) {
      xpFactor = 292 - xpFactor;
    }

    // balance factor
    uint8 balanceNormal = PoolLibrary.normalize(nft.balance, dnft.MAX_BALANCE());
    uint  balanceFactor = PoolLibrary.getBalanceMulti(balanceNormal);

    // deposit factor
    uint8 depositNormal = PoolLibrary.normalize(nft.deposit, dnft.MAX_DEPOSIT());
    uint  depositFactor = PoolLibrary.getDepositMulti(depositNormal);

    // --------------- update -------------
    // IMPORTANT: deposit can not be < 0
    console.log("deposit: %s", nft.deposit);
    console.log("xpNormal: %s", xpNormal);
    console.logInt(deltaAmount);
    nft.deposit = uint(int(nft.deposit) + (int(uint256(xpNormal)) * deltaAmount));

    // update xp
    uint factors = xpFactor * balanceFactor * depositFactor * boostFactor;
    uint newXP   = nft.xp + (nft.xp * factors);
    nft.xp       = newXP;

    dnft.updateNft(id, nft);

    // update xp max value
    dnft.updateMaxXP(newXP);
  }

  // As a reward for calling the `getNewEthPrice` function, we give the caller
  // a special xp boost.
  function getBoostFactor(uint id) internal view returns (uint boostFactor) {
    if (dnft.idToOwner(id) == msg.sender) {
      boostFactor = 2;
    } else {
      // if the dnft holder is not the owner the boost factor is 1;
      boostFactor = 1;
    }
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

