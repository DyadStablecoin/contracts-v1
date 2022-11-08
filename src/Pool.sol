// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {DYAD} from "../src/dyad.sol";
import {IAggregatorV3} from "../src/AggregatorV3Interface.sol";
import {IdNFT} from "../src/IdNFT.sol";
import {Addresses} from "../src/Addresses.sol";
import {PoolLibrary} from "../src/PoolLibrary.sol";

contract Pool {
  using SafeMath for uint256;

  IdNFT public dnft;
  DYAD public dyad;
  IAggregatorV3 internal priceFeed;

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
    dnft      = IdNFT(_dnft);
    dyad      = DYAD(_dyad);
    priceFeed = IAggregatorV3(Addresses.PRICE_ORACLE_ADDRESS);
  }


  /// @notice get the latest eth price from oracle
  function getNewEthPrice() public returns (int newEthPrice) {
    ( , newEthPrice, , , ) = priceFeed.latestRoundData();

    int deltaPricePercent = int(lastEthPrice)       / newEthPrice;
    int deltaAmount       = int(dyad.totalSupply()) * deltaPricePercent;

    if (uint(newEthPrice) > lastEthPrice) {
      dyad.mint(address(this), uint(deltaAmount));
    } else {
      // What happens if there is not enough to burn?
      dyad.burn(uint(deltaAmount));
    }

    updateNFTs();
    console.logUint(PoolLibrary.getXpMulti(95));

    lastEthPrice    = uint(newEthPrice);
    lastCheckpoint += 1;
    emit NewEthPrice(newEthPrice);
  }

  function updateNFTs() internal {
    uint nftTotalSupply  = dnft.totalSupply();
    uint dyadTotalSupply = dyad.totalSupply();

    for (uint i = 0; i < nftTotalSupply; i++) {
      updateNFT(i);
    }
  }

  function updateNFT(uint id) internal {
    IdNFT.Metadata memory metadata = dnft.idToMetadata(id);

    // update balance
    metadata.dyadInPool = metadata.dyadInPool.add(0);

    // update xp
    uint boostFactor = getBoostFactor(id);
    uint xpFactor    = 1;                   // TODO: calculate xp factor
    metadata.xp      = metadata.xp.add(xpFactor * boostFactor);
  }

  function getBoostFactor(uint id) internal returns (uint boostFactor) {
    if (dnft.idToOwner(id) == msg.sender) {
      // TODO: hardcoded for now!
      boostFactor = 10;
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
}

