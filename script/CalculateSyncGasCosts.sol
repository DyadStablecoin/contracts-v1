// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/core/Dyad.sol";
import "../src/core/Pool.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/core/dNFT.sol";
import {Parameters} from "./Parameters.sol";
import "forge-std/console.sol";
import {Deployment} from "./Deployment.sol";

contract CalculateSyncGasCosts is Script, Parameters {
  function run() public {
    address dNftAddr; address poolAddr; address dyadAddr;

    (dNftAddr, poolAddr, dyadAddr) = new Deployment().deploy(ORACLE_MAINNET,
                                                             0,
                                                             MAX_SUPPLY,
                                                             new address[](0));
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
