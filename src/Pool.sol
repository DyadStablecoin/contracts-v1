// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Pool {
  address public dnft;

  constructor(address _dnft) {
    dnft = _dnft;
  }
}

