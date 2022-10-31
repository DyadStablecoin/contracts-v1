// SPDX-License-Identifier: MIT
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

    dyad.setMinter(address(pool));
    pool.getNewEthPrice();
    dnft.setPool(address(pool));
    dnft.mint(address(this));
    pool.getNewEthPrice();

    addr1 = cheats.addr(1);
    addr2 = cheats.addr(2);
  }

  function testSetPool() public {
    dnft.setPool(address(0));
    assertEq(address(dnft.pool()), address(0));
  }

  function testMint() public {
    // we minted one in setUp
    assertEq(dnft.totalSupply(), 1);

    dnft.mint(address(this));
    assertEq(dnft.idToOwner(1), address(this));
    assertEq(dnft.xp(1), 100);
    assertEq(dnft.totalSupply(), 2);

    dnft.mint(address(this));
    assertEq(dnft.xp(2), 100);
    assertEq(dnft.totalSupply(), 3);

    dnft.mint(address(this));
    assertEq(dnft.xp(3), 100);
    assertEq(dnft.totalSupply(), 4);
  }

  function testMintDyad() public {
    dnft.mint(address(this));
    dnft.mintDyad{value: 1}(0);

    // try to mint dyad from an nft that the address does not own
    dnft.mint(address(addr1));
    vm.expectRevert();
    dnft.mintDyad(1);
  }

  function testWithdraw() public {
    dnft.mintDyad{value: 10}(0);

    // amount to withdraw
    uint AMOUNT = 22;
    dnft.withdraw(0, AMOUNT);
    assertEq(dyad.balanceOf(address(this)), AMOUNT);
  }

  function testDeposit() public {
    dnft.mintDyad{value: 100}(0);
    // we need to approve the dnft here to transfer our dyad
    dyad.approve(address(dnft), 100);

    uint AMOUNT = 22;
    dnft.withdraw(0, AMOUNT);
    dnft.deposit(0, AMOUNT);
    assertEq(dyad.balanceOf(address(this)), 0);
    pool.getNewEthPrice();
  }
}
