// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Parameters {
  // mainnet
  address ORACLE_MAINNET = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
  uint DEPOSIT_MINIMUM_MAINNET = 5000000000000000000000; // $5k deposit minimum

  // goerli
  address ORACLE_GOERLI = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;
  uint DEPOSIT_MINIMUM_GOERLI = 1000000000000000000; // $1 deposit minimum
}
