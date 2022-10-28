// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract dNFT {
  address public minter;

  constructor() {
    minter = msg.sender;
  }

  function mint(address receiver) public { }
}
