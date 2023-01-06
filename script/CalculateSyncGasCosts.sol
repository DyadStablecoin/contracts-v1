// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/core/Dyad.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/core/dNFT.sol";
import {Parameters} from "./Parameters.sol";
import "forge-std/console.sol";
import {Deployment} from "./Deployment.sol";

contract CalculateSyncGasCosts is Script, Parameters {
  function run() public {
    address dNftAddr; address dyadAddr;

    (dNftAddr, dyadAddr) = new Deployment().deploy(
      0,
      MAX_SUPPLY,
      BLOCKS_BETWEEN_SYNCS,
      MIN_COLLATERIZATION_RATIO,
      MAX_MINTED_BY_TVL, 
      ORACLE_MAINNET,
      new address[](0)
    );
    IdNFT dnft = IdNFT(dNftAddr);

    for (uint i = 0; i < MAX_SUPPLY; i++) {
      dnft.mintNft{value: 5 ether}(address(this));
    }
    uint g1 = gasleft();
    dnft.sync(0);
    console.log("gas used: ", g1 - gasleft());
  }
}
