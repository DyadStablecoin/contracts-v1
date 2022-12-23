// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/core/Dyad.sol";

contract DYADTest is Test {
  DYAD public dyad;

  function setUp() public {
    dyad = new DYAD();
  }

  function testMinter() public {
    assertEq(dyad.owner(), address(this));
    dyad.transferOwnership(address(1));
    assertEq(dyad.owner(), address(1));

    // we can't transfer ownership again
    vm.expectRevert();
    dyad.transferOwnership(address(1));
  }

  function testMint() public { }
}
