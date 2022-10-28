// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/dNFT.sol";

contract dNFTTest is Test {
  dNFT public dnft;

  function setUp() public {
    dnft = new dNFT();
  }

  function testMint() public {
    assertEq(dnft.totalSupply(), 0);

    dnft.mint(address(this));
    assertEq(dnft.idToOwner(0), address(this));
    assertEq(dnft.xp(0), 100);
    assertEq(dnft.totalSupply(), 1);

    dnft.mint(address(this));
    assertEq(dnft.xp(1), 100);
    assertEq(dnft.totalSupply(), 2);

    dnft.mint(address(this));
    assertEq(dnft.xp(2), 100);
    assertEq(dnft.totalSupply(), 3);
  }
}
