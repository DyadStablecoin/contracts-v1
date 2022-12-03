// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/dyad.sol";
import "../src/pool.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/dNFT.sol";
import "forge-std/console.sol";

contract SyncGasCosts is Script {
  function run() public {
    DYAD dyad = new DYAD();

    dNFT _dnft = new dNFT(address(dyad), 5000000000000000000000, false);
    IdNFT dnft = IdNFT(address(_dnft));

    Pool pool = new Pool(address(dnft), address(dyad), 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    dyad.setMinter(address(pool));
    dnft.setPool(address(pool));

    for (uint i = 0; i < 300; i++) {
      dnft.mintNft{value: 5 ether}(address(this));
    }
    uint g1 = gasleft();
    pool.sync();
    console.log("gas used: ", g1 - gasleft());
  }
}
