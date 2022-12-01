// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Deployment} from "./Deployment.sol";

// Pseudo-code, may not compile.
contract DeployGoerli is Script {
  function run() public {
      address ORACLE_GOERLI   = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;
      uint    DEPOSIT_MINIMUM = 1000000000000000000; // $l deposit minimum
      new Deployment().deploy(ORACLE_GOERLI, DEPOSIT_MINIMUM, true);
  }
}

