// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/dyad.sol";
import "../src/dyad.sol";
import "../src/pool.sol";
import "ds-test/test.sol";
import {IdNFT} from "../src/IdNFT.sol";
import {dNFT} from "../src/dNFT.sol";

interface CheatCodes {
   // Gets address for a given private key, (privateKey) => (address)
   function addr(uint256) external returns (address);
}

contract dNFTTest is Test {
  IdNFT public dnft;
  DYAD public dyad;
  Pool public pool;

  // --------------------- Test Addresses ---------------------
  CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
  address public addr1;
  address public addr2;

  function setUp() public {
    dyad = new DYAD();

    // init dNFT contract
    dNFT _dnft = new dNFT(address(dyad));
    dnft = IdNFT(address(_dnft));

    pool = new Pool(address(dnft), address(dyad));

    dyad.setMinter(address(pool));
    pool.sync();
    dnft.setPool(address(pool));
    dnft.mint(address(this));
    pool.sync();

    addr1 = cheats.addr(1);
    addr2 = cheats.addr(2);
  }

  // needed, so we can receive eth transfers
  receive() external payable {}

  function testSetPool() public {
    dnft.setPool(address(0));
    assertEq(address(dnft.pool()), address(0));
  }

  function testMint() public {
    // we minted one in setUp
    assertEq(dnft.totalSupply(), 1);

    dnft.mint(address(this));
    assertEq(dnft.idToOwner(1), address(this));

    IdNFT.Nft memory metadata = dnft.idToNft(1);
    assertEq(metadata.xp, 100);
    assertEq(dnft.totalSupply(), 2);

    dnft.mint(address(this));
    metadata = dnft.idToNft(2);
    assertEq(metadata.xp, 100);
    assertEq(dnft.totalSupply(), 3);

    dnft.mint(address(this));
    metadata = dnft.idToNft(3);
    assertEq(metadata.xp, 100);
    assertEq(dnft.totalSupply(), 4);

    // for(uint i = 0; i < 500; i++) {
    //   dnft.mint(address(this));
    // }

    // pool.sync();
  }

  function testMintDyad() public {
    // mint dyad for 1 wei
    dnft.mintDyad{value: 1}(0); // value in wei
    IdNFT.Nft memory metadata = dnft.idToNft(0);

    // check struct 
    uint lastEthPrice = pool.lastEthPrice() / 1e8;
    assertEq(metadata.deposit, lastEthPrice);

    // check global var
    uint deposit = dyad.balanceOf(address(pool));
    assertEq(deposit, lastEthPrice);

    // mint again for 1 gwie
    dnft.mintDyad{value: 1}(0); // value in gwei

    // check global var
    deposit = dyad.balanceOf(address(pool));
    // dyad in pool should be doubled
    assertEq(deposit, lastEthPrice*2);
  }

  function testMintDyadForNonOwner() public {
    // try to mint dyad from an nft that the address does not own
    dnft.mint(address(addr1));
    vm.expectRevert();
    dnft.mintDyad(1);
  }

  function testWithdraw() public {
    uint ethBalancePreMint = address(this).balance;
    dnft.mintDyad{value: 1 ether}(0);
    uint ethBalancePostMint = address(this).balance;
    // after the mint, we should have less eth
    assertTrue(ethBalancePreMint > ethBalancePostMint);
    IdNFT.Nft memory nft = dnft.idToNft(0);
    // after the mint, the nft should have a deposit
    assertTrue(nft.deposit >  0);
    // but no balance, 
    assertTrue(nft.balance == 0);
    // because all dyad is in the pool.
    assertTrue(dyad.balanceOf(address(pool)) > 0);

    assertEq(dyad.balanceOf(address(this)), 0);
    dnft.withdraw(0, nft.deposit);
    uint dyadBalancePostWithdraw = dyad.balanceOf(address(this));
    // after the withdraw, we should have more dyad
    assertTrue(dyadBalancePostWithdraw > 0);
  }

  function testDeposit() public {
    dnft.mintDyad{value: 100}(0);
    // we need to approve the dnft here to transfer our dyad
    dyad.approve(address(dnft), 100);
    uint AMOUNT = 42;
    // withdraw transfers dyad out of the pool to the owner
    dnft.withdraw(0, AMOUNT);
    assertTrue(dyad.balanceOf(address(this)) != 0);
    // deposit transfers dyad back into the pool
    dnft.deposit(0, AMOUNT);
    assertEq(dyad.balanceOf(address(this)), 0);
  }

  function testRedeem() public {
    uint ethBalancePreMint = address(this).balance;
    dnft.mintDyad{value: 1 ether}(0);
    uint ethBalancePostMint = address(this).balance;
    // after the mint, we should have less eth
    assertTrue(ethBalancePreMint > ethBalancePostMint);

    IdNFT.Nft memory nft = dnft.idToNft(0);
    assertEq(dyad.balanceOf(address(this)), 0);
    dnft.withdraw(0, nft.deposit);
    uint dyadBalancePostWithdraw = dyad.balanceOf(address(this));
    // after the withdraw, we should have more dyad
    assertTrue(dyadBalancePostWithdraw > 0);

    dyad.approve(address(pool), dyadBalancePostWithdraw);
    pool.redeem(dyadBalancePostWithdraw);
    uint dyadBalancePostRedeem = dyad.balanceOf(address(this));
    // after we redeem, we should have no dyad
    assertEq(dyadBalancePostRedeem, 0);
    uint ethBalancePostRedeem = address(this).balance;
    // after we redeem, we should have more eth
    assertTrue(ethBalancePostRedeem >  ethBalancePostMint);
    // after we redeem all dyad we have, we should have exactly the same eth
    // as before the mint.
    assertTrue(ethBalancePostRedeem == ethBalancePreMint);
  }
}
