// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/dNFT.sol";
import "../src/dyad.sol";
import "../src/dyad.sol";
import "../src/pool.sol";
import "ds-test/test.sol";

interface CheatCodes {
   // Gets address for a given private key, (privateKey) => (address)
   function addr(uint256) external returns (address);
}

contract dNFTTest is Test {
  dNFT public dnft;
  DYAD public dyad;
  Pool public pool;

  // --------------------- Test Addresses ---------------------
  CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
  address public addr1;
  address public addr2;

  function setUp() public {
    dyad = new DYAD();
    dnft = new dNFT(address(dyad));
    pool = new Pool(address(dnft), address(dyad));

    dnft.setPool(address(pool));

    addr1 = cheats.addr(1);
    addr2 = cheats.addr(2);
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

  function testMintDyad() public {
    pool.newEthPrice();

    dnft.mint(address(this));
    dnft.mintDyad{value: 1}(0);

    // dnft.mint(address(addr1));
    // vm.expectRevert();
    // dnft.mintDyad(1);
  }
}
