// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/dNFT.sol";
import "../src/dyad.sol";
import "../src/pool.sol";

address constant PRICE_ORACLE_GOERLI = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

// Pseudo-code, may not compile.
contract DeployGoerli is Script {
   function run() public {
      vm.startBroadcast();

      DYAD dyad = new DYAD();

      dNFT _dnft = new dNFT(address(dyad), true); // with insider alloc
      IdNFT dnft = IdNFT(address(_dnft));

      Pool pool = new Pool(address(dnft), address(dyad), 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

      dyad.setMinter(address(pool));
      dnft.setPool(address(pool));

      vm.stopBroadcast();
   }
}

