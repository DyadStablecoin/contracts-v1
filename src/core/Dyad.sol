// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract DYAD is ERC20, ERC20Burnable {
  address public minter;

  constructor() ERC20("DYAD Stablecoin", "DYAD") {
    minter = msg.sender;
  }

  function setMinter(address newMinter) public {
    // we set this to the pool in the launch process
    // after that, because the Pool is not controlled by anyone, this
    // can not be changed anymore.
    require(msg.sender == minter, "Only minter can set minter");
    minter = newMinter;
  }

  function mint(address to, uint amount) public {
    require(msg.sender == minter, "Only minter can mint");
    _mint(to, amount);
  }
}
