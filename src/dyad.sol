// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DYAD is ERC20 {
  address public minter;

  constructor() ERC20("DYAD Stablecoin", "DYAD") {
    minter = msg.sender;
  }

  function setMinter(address newMinter) public {
    require(msg.sender == minter, "Only minter can set minter");
    minter = newMinter;
  }

  function mint(address to, uint amount) public {
    require(msg.sender == minter, "Only minter can mint");
    _mint(to, amount);
  }
}
