// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract OracleMock {
  // NOTE: this value has to be overwritten in the tests
  // 
  // Some examples for quick copy/pasta:
  // 95000000  -> - 5%
  // 110000000 -> +10%
  // 100000000 -> +-0%
  int public price = 0;

  function latestRoundData() external returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) {
      return (1, price, 1, 1, 1);  
    }
}
