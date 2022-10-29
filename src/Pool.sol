// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/dyad.sol";
import "../src/IdNFT.sol";
import "../src/AggregatorV3Interface.sol";
import "forge-std/console.sol";
import "../src/Addresses.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Pool {
  using SafeMath for uint256;

  IdNFT public dnft;
  DYAD public dyad;
  AggregatorV3Interface internal priceFeed;

  uint public lastEthPrice;

  constructor(address _dnft, address _dyad) {
    dnft = IdNFT(_dnft);
    dyad = DYAD(_dyad);
    priceFeed = AggregatorV3Interface(Addresses.PRICE_ORACLE_ADDRESS);
  }

  /// @notice get the latest eth price from oracle
  function newEthPrice() public {
    ( , int price, , , ) = priceFeed.latestRoundData();
    lastEthPrice = uint(price);
  }

  /// @dev Check if msg.sender is the nft contract
  modifier onlyNFT() {
    require(msg.sender == address(dnft), "Pool: Only NFT can call this function");
    _;
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
  function withdraw(uint amount, address recipient) external onlyNFT {
    dyad.transfer(recipient, amount);
  }
}

