// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract DYAD is ERC20, Ownable {
  constructor() ERC20("DYAD Stablecoin", "DYAD") {}

  function mint(uint amount) public onlyOwner { _mint(owner(), amount); }
  function burn(uint amount) public onlyOwner { _burn(owner(), amount); }
}
