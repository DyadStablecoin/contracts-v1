// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract IAggregatorV3Test {
  function latestRoundData() external pure returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) {
      // newEthPrice = 110000000; // 110000000 -> +10%
      // newEthPrice = 95000000; // 95000000 -> -5%
      return (1, 95000000, 1, 1, 1);
    }
}
