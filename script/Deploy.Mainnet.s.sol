// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Deployment} from "./Deployment.sol";
import {Parameters} from "./Parameters.sol";

// Run on a local mainnet fork
contract DeployMainnet is Script, Parameters {
   function run() public {
      new Deployment().deploy(ORACLE_MAINNET, DEPOSIT_MINIMUM_MAINNET, INSIDERS);
   }
}
