// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Deployment} from "./Deployment.sol";
import {Parameters} from "./Parameters.sol";

// Pseudo-code, may not compile.
contract DeployGoerli is Script, Parameters {
  function run() public {
      new Deployment().deploy(
        DEPOSIT_MINIMUM_GOERLI,
        MAX_SUPPLY,
        BLOCKS_BETWEEN_SYNCS,
        MIN_COLLATERIZATION_RATIO,
        MAX_MINTED_BY_TVL, 
        ORACLE_GOERLI,
        INSIDERS
      );
  }
}

