// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract DYAD is Ownable, ERC20, ERC20Burnable, ERC20Permit  {
  constructor() 
    ERC20("DYAD Stablecoin", "DYAD") 
    ERC20Permit("DYAD Stablecoin") 
  {}

  function mint(address to, uint256 amount) public onlyOwner {
      _mint(to, amount);
  }
}
