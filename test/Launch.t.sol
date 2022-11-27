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

  function setUp() public {
    dyad       = new DYAD();
    dNFT _dnft = new dNFT(address(dyad), true); // with insider allocation
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
}
