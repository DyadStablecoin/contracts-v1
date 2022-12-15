// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {OracleMock} from "./../Oracle.t.sol";

contract Util is Test {

  function setOraclePrice(OracleMock oracle, uint price) public {
    vm.store(address(oracle), bytes32(uint(0)), bytes32(price)); 
  }
}

