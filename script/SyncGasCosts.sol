// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/dyad.sol";
import "../src/pool.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/dNFT.sol";
import "forge-std/console.sol";
import {Deployment} from "./Deployment.sol";

contract SyncGasCosts is Script {
  function run() public {
    address ORACLE_MAINNET  = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address dNftAddr;
    address poolAddr;

    (dNftAddr, poolAddr) = new Deployment().deploy(ORACLE_MAINNET, 0, false);
    IdNFT dnft = IdNFT(dNftAddr);
    Pool pool = Pool(poolAddr);

    for (uint i = 0; i < 300; i++) {
      dnft.mintNft{value: 5 ether}(address(this));
    }
    uint g1 = gasleft();
    pool.sync();
    console.log("gas used: ", g1 - gasleft());
  }
}
