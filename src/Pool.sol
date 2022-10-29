// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/dyad.sol";
import "../src/IdNFT.sol";
import "../src/AggregatorV3Interface.sol";
import "forge-std/console.sol";

contract Pool {
  IdNFT public dnft;
  DYAD public dyad;
  AggregatorV3Interface internal priceFeed;

  constructor(address _dnft, address _dyad) {
    dnft = IdNFT(_dnft);
    dyad = DYAD(_dyad);
    priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
  }

  function mintDyad() external returns (uint) {
    (
      /*uint80 roundID*/,
      int price,
      /*uint startedAt*/,
      /*uint timeStamp*/,
      /*uint80 answeredInRound*/
    ) = priceFeed.latestRoundData();

    console.logInt(price);

    return 9999;
  }
}

