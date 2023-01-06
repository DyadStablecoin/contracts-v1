// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Deployment} from "./Deployment.sol";
import {Parameters} from "./Parameters.sol";

// Run on a local mainnet fork
contract DeployMainnet is Script, Parameters {
   function run() public {
      new Deployment().deploy(
        DEPOSIT_MINIMUM_MAINNET,
        MAX_SUPPLY,
        BLOCKS_BETWEEN_SYNCS,
        MIN_COLLATERIZATION_RATIO,
        MAX_MINTED_BY_TVL,
        ORACLE_MAINNET,
        INSIDERS
      ); 
   }
}
