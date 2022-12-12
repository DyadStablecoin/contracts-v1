// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {IdNFT} from "../../src/interfaces/IdNFT.sol";
import {dNFT} from "../../src/dNFT.sol";
import {PoolLibrary} from "../../src/PoolLibrary.sol";
import {OracleMock} from "./../Oracle.t.sol";
import "../../src/dyad.sol";
import "../../src/pool.sol";
import {Deployment} from "../../script/Deployment.sol";
import {Stake} from "../../src/stake/Stake.sol";

uint constant DEPOSIT_MINIMUM = 5000000000000000000000;
uint constant ORACLE_PRICE = 120000000000; // $1.2k

contract StakeTest is Test,Deployment {
  using stdStorage for StdStorage;

  OracleMock public oracle;
  IdNFT public dnft;
  DYAD public dyad;
  Pool public pool;
  Stake public stake;

  function setOraclePrice(uint price) public {
    vm.store(address(oracle), bytes32(uint(0)), bytes32(price)); 
  }

  function setUp() public {
    oracle = new OracleMock();
    dyad = new DYAD();

    setOraclePrice(ORACLE_PRICE);

    address _dnft; address _pool;
    (_dnft, _pool) = new Deployment().deploy(address(oracle), DEPOSIT_MINIMUM, true);

    dnft = IdNFT(address(_dnft));
    pool = Pool(address(_pool));
    stake = new Stake();
  }

  function testStake() public {
    uint id = dnft.mintNft{value: 5 ether}(address(this));
  }

}
