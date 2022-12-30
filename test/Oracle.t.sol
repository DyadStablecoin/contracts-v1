// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract OracleMock {
  // NOTE: this value has to be overwritten in the tests
  // 
  // Some examples for quick copy/pasta:
  // 95000000  -> - 5%
  // 110000000 -> +10%
  // 100000000 -> +-0%
  uint public price = 0;

  function fetchPrice() external view returns (uint)  {

    return price;
  }
}
