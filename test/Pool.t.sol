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

  function mintAndTransfer(uint amount) public {
    // mint -> withdraw -> transfer -> approve pool
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.withdraw(0,     amount);
    dyad.transfer(addr1, amount);
    vm.prank(addr1);
    dyad.approve(address(pool), amount);
  }

  // --------------------- DYAD Redeem ---------------------
  function testRedeemDyad() public {
    uint REDEEM_AMOUNT = 100000000;
    mintAndTransfer(REDEEM_AMOUNT);
    vm.prank(addr1);
    pool.redeem(REDEEM_AMOUNT);
  }
  function testRedeemDyadSenderDyadBalance() public {
    uint REDEEM_AMOUNT = 100000000;
    mintAndTransfer(REDEEM_AMOUNT);
    assertEq(addr1.balance, 0);
    vm.prank(addr1);
    pool.redeem(REDEEM_AMOUNT);
    assertEq(addr1.balance, 83333);
  }
  function testRedeemDyadPoolBalance() public {
    uint REDEEM_AMOUNT = 100000000;
    mintAndTransfer(REDEEM_AMOUNT);
    uint oldPoolBalance = address(pool).balance;
    vm.prank(addr1);
    pool.redeem(REDEEM_AMOUNT);
    assertTrue(address(pool).balance < oldPoolBalance); 
  }
  function testRedeemDyadTotalSupply() public {
    uint REDEEM_AMOUNT = 100000000;
    mintAndTransfer(REDEEM_AMOUNT);
    uint oldDyadTotalSupply = dyad.totalSupply();
    vm.prank(addr1);
    pool.redeem(REDEEM_AMOUNT);
    // the redeem burns the dyad so the total supply should be less
    assertTrue(dyad.totalSupply() < oldDyadTotalSupply);
  }
  function testFailRedeemDyadLessThanRedeemMinimum() public {
    uint REDEEM_AMOUNT = 100000000;
    mintAndTransfer(REDEEM_AMOUNT);

    vm.prank(addr1);
    // this is less than the redeem minimum by 1
    pool.redeem(REDEEM_AMOUNT-1);
  }
  function testFailRedeemDyadNoAllowance() public {
    // this should fail because we do not prak the redeem call, 
    // which means that this contract is the sender, and it has no allowance
    uint REDEEM_AMOUNT = 100000000;
    mintAndTransfer(REDEEM_AMOUNT);
    pool.redeem(REDEEM_AMOUNT);
  }
}
