// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/dyad.sol";
import "../src/pool.sol";
import "ds-test/test.sol";
import {IdNFT} from "../src/IdNFT.sol";
import {dNFT} from "../src/dNFT.sol";
import {PoolLibrary} from "../src/PoolLibrary.sol";
import {OracleMock} from "./Oracle.t.sol";

// mainnnet
address constant PRICE_ORACLE_ADDRESS = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
uint constant ORACLE_PRICE = 120000000000; // $1.2k

interface CheatCodes {
   // Gets address for a given private key, (privateKey) => (address)
   function addr(uint256) external returns (address);
}

contract dNFTTest is Test {
  using stdStorage for StdStorage;

  IdNFT public dnft;
  DYAD public dyad;
  Pool public pool;
  OracleMock public oracle;

  // --------------------- Test Addresses ---------------------
  CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
  address public addr1;
  address public addr2;

  function setOraclePrice(uint price) public {
    vm.store(address(oracle), bytes32(uint(0)), bytes32(price)); 
  }

  function setUp() public {
    oracle = new OracleMock();
    dyad = new DYAD();

    // set oracle price
    setOraclePrice(ORACLE_PRICE); // $1.2k

    // // init dNFT contract
    dNFT _dnft = new dNFT(address(dyad));
    dnft = IdNFT(address(_dnft));

    pool = new Pool(address(dnft), address(dyad), address(oracle));

    dnft.setPool(address(pool));
    dyad.setMinter(address(pool));

    addr1 = cheats.addr(1);
    addr2 = cheats.addr(2);
  }

  // needed, so we can receive eth transfers
  receive() external payable {}

  // --------------------- DYAD Redeem ---------------------
  function testRedeemDyad() public {
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.withdraw(0,     100000000);
    dyad.transfer(addr1, 100000000);
    vm.prank(addr1);
    dyad.approve(address(pool), 100000000);
    assertEq(addr1.balance, 0);
    uint oldPoolBalance = address(pool).balance;
    uint oldDyadTotalSupply = dyad.totalSupply();
    vm.prank(addr1);
    pool.redeem(100000000);
    uint newPoolBalance = address(pool).balance;
    // there should be less eth in the pool as before the redeem
    assertTrue(newPoolBalance < oldPoolBalance); 
    assertEq(addr1.balance, 83333);

    uint newDyadTotalSupply = dyad.totalSupply();
    assertTrue(newDyadTotalSupply < oldDyadTotalSupply);
  }
  function testFailRedeemDyadLessThanRedeemMinimum() public {
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.withdraw(0,     100000000);
    dyad.transfer(addr1, 100000000);
    vm.prank(addr1);
    dyad.approve(address(pool), 100000000);
    vm.prank(addr1);
    // this is less than the redeem minimum by 1
    pool.redeem(100000000-1);
  }
}
