// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/dyad.sol";
import "../src/IdNFT.sol";
import "../src/AggregatorV3Interface.sol";
import "forge-std/console.sol";

contract Pool {
  // mainnnet
  address private constant PRICE_ORACLE_ADDRESS = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;


  IdNFT public dnft;
  DYAD public dyad;
  AggregatorV3Interface internal priceFeed;

  uint public lastEthPrice;

  constructor(address _dnft, address _dyad) {
    dnft = IdNFT(_dnft);
    dyad = DYAD(_dyad);

    // mainnnet 
    priceFeed = AggregatorV3Interface(PRICE_ORACLE_ADDRESS);
  }

  function newEthPrice() public {
    (
      /*uint80 roundID*/,
      int price,
      /*uint startedAt*/,
      /*uint timeStamp*/,
      /*uint80 answeredInRound*/
    ) = priceFeed.latestRoundData();

    lastEthPrice = uint(price);
  }

  function mintDyad() external returns (uint) {

    return 9999;
  }
}

