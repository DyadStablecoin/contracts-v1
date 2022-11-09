// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

library PoolLibrary {

  // return "normalized" value between 1-100
  function normalize(uint value, uint maxValue) public view returns (uint8) {
    require(maxValue >= 100, "PoolLibrary: maxValue must be >= 100");
    return uint8(value / (maxValue / 100));
  }

  function getXpMulti(uint8 xp) public view returns (uint) {
    // xp is like an index which maps exactly to one value in the table. That is why
    // xp must be uint and between 0 and 100.
    require(xp >= 0 && xp <= 100, "PoolLibrary: xp must be between 0 and 100");

    // why 61?, because:
    // the first 61 values in the table are all 50, which means we do not need 
    // to store them in the table, but can do this compression.
    // But we need to subtract 61 in the else statement to get the correct lookup.
    if (xp < 61) {
      return 50;
    } else {
      uint8[40] memory XP_TABLE = [51, 51, 51, 51, 52, 53, 53, 54, 55, 57, 58, 60,
                                   63, 66, 69, 74, 79, 85, 92, 99, 108, 118, 128, 139,
                                   150, 160, 171, 181, 191, 200, 207, 214, 220, 225,
                                   230, 233, 236, 239, 241, 242];
      return XP_TABLE[xp - 61]; 
    }
  }

  function getBalanceMulti(uint8 balance) public view returns (uint) {
    // balance is like an index which maps exactly to one value in the table. That is why
    // balance must be uint and between 0 and 100.
    require(balance >= 0 && balance <= 100, "PoolLibrary: balance must be between 0 and 100");

    // why 56?, because:
    // the first 56 values in the table are all 100, which means we do not need 
    // to store them in the table, but can do this compression.
    // But we need to subtract 56 in the else statement to get the correct lookup.
    if (balance < 56) {
      return 100;
    } else {
      uint8[56] memory BALANCE_TABLE = [101, 101, 101, 102, 102, 103, 104, 105, 106,
                                        108, 109, 112, 114, 117, 121, 124, 129, 134,
                                        139, 144, 150, 155, 160, 165, 170, 175, 178,
                                        182, 185, 187, 190, 191, 193, 194, 195, 196,
                                        197, 197, 198, 198, 198, 199, 199, 199, 199,
                                        199, 199, 199, 199, 199, 199, 199, 199, 199,
                                        199, 199];
      return BALANCE_TABLE[balance - 56]; 
    }
  }

  function getDepositMulti(uint8 deposit) public view returns (uint) {
    // deposit is like an index which maps exactly to one value in the table. That is why
    // deposit must be uint and between 0 and 100.
    require(deposit >= 0 && deposit <= 100, "PoolLibrary: deposit must be between 0 and 100");

    // why 56?, because:
    // the first 56 values in the table are all 100, which means we do not need 
    // to store them in the table, but can do this compression.
    // But we need to subtract 56 in the else statement to get the correct lookup.
    if (deposit < 21) {
      return 0;
    } else if (deposit < 59) {
      uint8[18] memory DEPOSIT_TABLE = [1, 3, 8, 16, 31, 50, 69, 83, 91, 96, 98, 99,
                                        99, 99, 99, 99, 99, 99];
      return DEPOSIT_TABLE[deposit - 21]; // -1 because it is 0 indexed
    } else {
      return 100; 
    }
  }
}
