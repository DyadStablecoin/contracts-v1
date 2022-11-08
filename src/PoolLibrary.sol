// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

library PoolLibrary {
  bytes constant XP_TABLE = "\x33\x33\x33\x33\x34\x35\x35\x36\x37\x39\x3a\x3c\x3f\x42\x45\x4a\x4f\x55\x5c\x63\x6c\x76\x80\x8b\x96\xa0\xab\xb5\xbf\xc8\xcf\xd6\xdc\xe1\xe6\xe9\xec\xef\xf1\xf2";

  function getXpMulti(uint scaledXp) public view returns (uint) {
    uint8[40] memory xppp = [51, 51, 51, 51, 52, 53, 53, 54, 55, 57, 58, 60, 63, 66, 69, 74, 79, 85, 92, 99, 108, 118, 128, 139, 150, 160, 171, 181, 191, 200, 207, 214, 220, 225, 230, 233, 236, 239, 241, 242];

    require(scaledXp >= 0 && scaledXp <= 100, "PoolLibrary: xp must be between 0 and 100");
    if (scaledXp <= 60) {
      return 50;
    } else {
      return xppp[scaledXp - 61];
    }
  }
}
