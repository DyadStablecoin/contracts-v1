// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/dyad.sol";
import "../src/pool.sol";
import "ds-test/test.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/dNFT.sol";
import {PoolLibrary} from "../src/PoolLibrary.sol";
import {OracleMock} from "./Oracle.t.sol";

interface CheatCodes {
   // Gets address for a given private key, (privateKey) => (address)
   function addr(uint256) external returns (address);
}

address constant CHAINLINK_ORACLE_ADDRESS = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
uint constant DEPOSIT_MINIMUM = 5000000000000000000000;

// this should simulate the inital lauch on mainnet
// IMPORTANT: you have to run this as a mainnet fork!!!
contract LaunchTest is Test {
  uint NUMBER_OF_INSIDER_NFTS;

  IdNFT public dnft;
  DYAD public dyad;
  Pool public pool;
  OracleMock public oracle;

  // --------------------- Test Addresses ---------------------
  CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
  address public addr1;
  address public addr2;

  // needed, so we can receive eth transfers
  receive() external payable {}

  function setUp() public {
    dyad       = new DYAD();
    dNFT _dnft = new dNFT(address(dyad), DEPOSIT_MINIMUM, true); // with insider allocation
    dnft       = IdNFT(address(_dnft));
    pool       = new Pool(address(dnft), address(dyad), CHAINLINK_ORACLE_ADDRESS);
    dnft.setPool  (address(pool));
    dyad.setMinter(address(pool));

    // directly after deployment the total supply has to be the number
    // of insider allocations.
    NUMBER_OF_INSIDER_NFTS = dnft.totalSupply();

    addr1 = cheats.addr(1); vm.deal(addr1, 100 ether);
    addr2 = cheats.addr(2); vm.deal(addr2, 100 ether);
  }

  function testInsiderAllocation() public {
    // we have `NUMBER_OF_INSIDER_NFTS` insiders that we allocate for
    assertEq(dnft.totalSupply(), NUMBER_OF_INSIDER_NFTS);
  }

  function testDnftPoolIsCorrect() public {
    assertEq(dnft.pool(), address(pool));
  }

  function testFailSetSetPoolTwice() public {
    // the pool can only be set once!
    dnft.setPool(address(pool));
  }

  function testFirstSync() public {
    pool.sync();
  }

  function testMintNormallyAndSync() public {
    dnft.mintNft{value: 5 ether}(address(this));
    vm.prank(addr1);
    dnft.mintNft{value: 5 ether}(address(this));
    vm.prank(addr2);
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.mintNft{value: 5 ether}(address(this));
    pool.sync();
  }

  function testWithdrawAndSync() public {
    dnft.mintNft{value: 5 ether}(addr1);
    vm.prank(addr1);
    // remember the nfts are 0 indexed, so we do not need to increment by 1.
    dnft.withdraw(NUMBER_OF_INSIDER_NFTS, 4 ether);

    dnft.mintNft{value: 5 ether}(addr2);
    vm.prank(addr2);
    // remember the nfts are 0 indexed, so we do not need to increment by 1.
    dnft.withdraw(NUMBER_OF_INSIDER_NFTS+1, 3 ether);

    pool.sync();
  }

  // very self explanatory I think. Do random stuff and see if it breaks.
  // I think you call that fuzzy testing, lol :D
  function testDoRandomStuffAndSync() public {
    pool.sync();

    // mint nfts
    uint id1 = dnft.mintNft{value: 5 ether}(address(this));
    vm.prank(addr1);
    uint id2 = dnft.mintNft{value: 12 ether}(addr1);
    vm.prank(addr1);
    uint id3 = dnft.mintNft{value: 5 ether}(addr1);
    vm.prank(addr2);
    uint id4 = dnft.mintNft{value: 14 ether}(addr2);
    vm.prank(addr2);
    uint id5 = dnft.mintNft{value: 5 ether}(addr2);
    uint id6 = dnft.mintNft{value: 8 ether}(address(this));
    uint id7 = dnft.mintNft{value: 5 ether}(address(this));

    pool.sync();

    // do some withdraws
    dnft.withdraw(id1, 2 ether);
    dnft.withdraw(id1, 1 ether);
    vm.prank(addr1);
    dnft.withdraw(id2, 66626626262662);
    vm.prank(addr1);
    dnft.withdraw(id3, 4 ether);
    vm.prank(addr2);
    dnft.withdraw(id4, 100000000000);
    vm.prank(addr2);
    dnft.withdraw(id5, 5 ether);
    dnft.withdraw(id6, 2 ether);
    dnft.withdraw(id7, 4444444444444);

    pool.sync();

    // do some deposits
    dyad.approve(address(dnft), 5 ether);
    dnft.deposit(id1, 1 ether);
    dnft.deposit(id1, 5000000);
    vm.prank(addr2);
    dyad.approve(address(dnft), 5 ether);
    vm.prank(addr2);
    dnft.deposit(id4, 1000);

    for(uint i = 0; i < 4; i++) { pool.sync(); }

    // do some redeems
    dyad.approve(address(pool), 5 ether);
    pool.redeem(100000002);
    pool.redeem(100000202);
    pool.redeem(3000000202);

    for(uint i = 0; i < 4; i++) { pool.sync(); }
  }
}
