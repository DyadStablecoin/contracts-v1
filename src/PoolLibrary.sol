// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library PoolLibrary {
  function getXpMulti(uint scaledXp) public view returns (uint) {
    return scaledXp + (scaledXp / 2);
  }
}
