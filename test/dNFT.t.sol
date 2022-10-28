// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/dNFT.sol";

contract dNFTTest is Test {
  dNFT public dnft;

  function setUp() public {
    console.log("setup");
    dnft = new dNFT();
  }

  function testIncrement() public {
    console.log(address(dnft));
  }
}
