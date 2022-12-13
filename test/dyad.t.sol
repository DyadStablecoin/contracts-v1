// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/core/dyad.sol";

contract DYADTest is Test {
  DYAD public dyad;

  function setUp() public {
    dyad = new DYAD();
  }

  function testMinter() public {
    assertEq(dyad.minter(), address(this));
    dyad.setMinter(address(0));
    assertEq(dyad.minter(), address(0));
  }

  function testMint() public { }
}
