// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/dyad.sol";
import "../src/Pool.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/dNFT.sol";
import {Parameters} from "./Parameters.sol";
import "forge-std/console.sol";
import {Deployment} from "./Deployment.sol";

contract CalculateSyncGasCosts is Script, Parameters {
  function run() public {
    address dNftAddr; address poolAddr; address dyadAddr;

    (dNftAddr, poolAddr, dyadAddr) = new Deployment().deploy(ORACLE_MAINNET, 0, false);
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
