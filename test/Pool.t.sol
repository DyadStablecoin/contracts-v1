// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/dyad.sol";
import "../src/dNFT.sol";
import "../src/pool.sol";

contract PoolTest is Test {
  DYAD public dyad;
  Pool public pool;
  dNFT public dnft;

  function setUp() public {
    dyad = new DYAD();
    dnft = new dNFT(address(dyad));
    pool = new Pool(address(dnft), address(dyad));
  }

  function testNewEthPrice() public {
    assertEq(pool.lastEthPrice(), 0);

    // get new eth price and do sanity check
    pool.newEthPrice();
    assertTrue(pool.lastEthPrice() > 0);
  }
}