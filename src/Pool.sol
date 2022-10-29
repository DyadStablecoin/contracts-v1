// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/dyad.sol";
import "../src/IdNFT.sol";
import "../src/AggregatorV3Interface.sol";
import "forge-std/console.sol";
import "../src/Addresses.sol";

contract Pool {
  IdNFT public dnft;
  DYAD public dyad;
  AggregatorV3Interface internal priceFeed;

  uint public lastEthPrice;

  constructor(address _dnft, address _dyad) {
    dnft = IdNFT(_dnft);
    dyad = DYAD(_dyad);
    priceFeed = AggregatorV3Interface(Addresses.PRICE_ORACLE_ADDRESS);
  }

  function newEthPrice() public {
    ( , int price, , , ) = priceFeed.latestRoundData();
    lastEthPrice = uint(price);
  }

  modifier onlyNFT() {
    require(msg.sender == address(dnft), "Pool: Only NFT can call this function");
    _;
  }

  function deposit(uint amount) external onlyNFT {

  }

  function mintDyad() payable external onlyNFT returns (uint) {
    require(msg.value > 0);

    uint newDyad = msg.value * lastEthPrice / 100000000;
    dyad.mint(address(this), newDyad);

    return newDyad;
  }
}

