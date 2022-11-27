// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/dNFT.sol";
import "../src/dyad.sol";
import "../src/pool.sol";

// Pseudo-code, may not compile.
contract Deploy is Script {
   function run() public {
      vm.startBroadcast();

      DYAD dyad = new DYAD();

      dNFT _dnft = new dNFT(address(dyad), true); // with insider alloc
      IdNFT dnft = IdNFT(address(_dnft));

      Pool pool = new Pool(address(dnft), address(dyad), 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);

      dyad.setMinter(address(pool));
      dnft.setPool(address(pool));

      vm.stopBroadcast();
   }
}
