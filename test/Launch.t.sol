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

interface CheatCodes {
   // Gets address for a given private key, (privateKey) => (address)
   function addr(uint256) external returns (address);
}

address constant CHAINLINK_ORACLE_ADDRESS = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

// this should simulate the inital lauch on mainnet
// IMPORTANT: you have to run this as a mainnet fork!!!
contract LaunchTest is Test {
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
  }

  function testInsiderAllocation() public {
    // we have 3 insiders that we allocate for
    assertEq(dnft.totalSupply(), 3);
  }

  function testSetPool() public {
    assertEq(dnft.pool(), address(pool));
  }

  function testFirstSync() public {
    pool.sync();
  }
}
