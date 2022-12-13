// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Deployment} from "./Deployment.sol";
import {Parameters} from "./Parameters.sol";

// Pseudo-code, may not compile.
contract DeployGoerli is Script, Parameters {
  function run() public {
      new Deployment().deploy(ORACLE_GOERLI, DEPOSIT_MINIMUM_GOERLI, INSIDERS);
  }
}

