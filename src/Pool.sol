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

  IdNFT public dnft;
  DYAD public dyad;
  IAggregatorV3 internal priceFeed;

  uint256 constant private REDEEM_MINIMUM = 100000000;

  mapping(uint => int) public dyadDeltaAtCheckpoint;
  mapping(uint => int) public xpDeltaAtCheckpoint;
  mapping(uint => uint) public poolBalanceAtCheckpoint;

  uint public lastEthPrice;
  uint public lastCheckpoint;

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

  function getNewEthPrice() internal returns (int newEthPrice) {
    ( , newEthPrice, , , ) = priceFeed.latestRoundData();
  }


  /// @notice get the latest eth price from oracle
  function sync() public returns (int newEthPrice) {
    newEthPrice = getNewEthPrice();

    int  deltaPrice        = int(lastEthPrice) - newEthPrice;
    uint deltaPricePercent = uint(newEthPrice).mul(1000).div(lastEthPrice);
    uint deltaAmount       = PoolLibrary.percentageOf(dyad.totalSupply(), deltaPricePercent);
    int  deltaAmountSigned = int(deltaAmount);  

    // if the delta is negative we have to make deltaAmount negative as well
    if (deltaPrice < 0) {
      deltaAmountSigned = -1 * deltaAmountSigned;
    }

    if (uint(newEthPrice) > lastEthPrice) {
      dyad.mint(address(this), uint(deltaAmount));
    } else {
      // What happens if there is not enough to burn?
      dyad.burn(uint(deltaAmount));
    }

    updateNFTs(deltaAmountSigned);

    lastEthPrice    = uint(newEthPrice);
    lastCheckpoint += 1;
    emit NewEthPrice(newEthPrice);
  }

  function updateNFTs(int deltaAmount) internal {
    uint nftTotalSupply  = dnft.totalSupply();
    uint dyadTotalSupply = dyad.totalSupply();

    for (uint i = 0; i < nftTotalSupply; i++) {
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
  function getBoostFactor(uint id) internal returns (uint boostFactor) {
    if (dnft.idToOwner(id) == msg.sender) {
      boostFactor = 3;
    } else {
      // if the dnft holder is not the owner the boost factor is 1;
      boostFactor = 1;
    }
  }

  /// @notice Mint dyad to the NFT
  function mintDyad() payable external onlyNFT returns (uint) {
    require(msg.value > 0);
    uint newDyad = lastEthPrice.mul(msg.value).div(100000000);
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

