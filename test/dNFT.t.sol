// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/dNFT.sol";
import "../src/dyad.sol";

contract dNFTTest is Test {
  dNFT public dnft;
  DYAD public dyad;

  function setUp() public {
    dyad = new DYAD();
    dnft = new dNFT(address(dyad));
  }

  function testSetPool() public {
    dnft.setPool(address(0));
    assertEq(address(dnft.pool()), address(0));
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
