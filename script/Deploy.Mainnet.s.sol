// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Deployment} from "./Deployment.sol";

// Run on a local mainnet fork
contract DeployMainnet is Script {
   function run() public {
      address ORACLE_MAINNET  = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
      uint    DEPOSIT_MINIMUM = 5000000000000000000000; // $5k deposit minimum
      new Deployment().deploy(ORACLE_MAINNET, DEPOSIT_MINIMUM, true);
   }
}
