// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Pool} from "../src/core/Pool.sol";

contract ReadData is Script {
  Pool public pool;

  function run() public {
    pool = Pool(0xAf593430b86a0560818a9dF5858B14dDC469Ab98);
  }

}
