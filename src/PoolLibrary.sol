// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

library PoolLibrary {

  function getXpMulti(uint8 xp) public view returns (uint) {
    // xp is like an index which maps exactly to one value in the table. That is why
    // xp must be uint and between 0 and 100.
    require(xp >= 0 && xp <= 100, "PoolLibrary: xp must be between 0 and 100");

    uint8[40] memory XP_TABLE = [51, 51, 51, 51, 52, 53, 53, 54, 55, 57, 58, 60, 63, 66, 69, 74, 79, 85, 92, 99, 108, 118, 128, 139, 150, 160, 171, 181, 191, 200, 207, 214, 220, 225, 230, 233, 236, 239, 241, 242];

    // why 61?, because:
    // the first 61 values in the table are all 50, which means we do not need 
    // to store them in the table, but can do this compression.
    // But we need to subtract 61 in the else statement to get the correct lookup.
    if (xp < 61) {
      return 50;
    } else {
      return XP_TABLE[xp - 61];
    }
  }

}
