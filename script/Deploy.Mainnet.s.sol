// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/dNFT.sol";
import "../src/dyad.sol";
import "../src/pool.sol";

address constant PRICE_ORACLE_MAINNET = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
// $5k deposit minimum
uint constant DEPOSIT_MINIMUM = 5000000000000000000000;

// Run on a local mainnet fork
contract DeployMainnet is Script {
   function run() public {
      vm.startBroadcast();

      DYAD dyad = new DYAD();

      dNFT _dnft = new dNFT(address(dyad), DEPOSIT_MINIMUM, true); // with insider alloc
      IdNFT dnft = IdNFT(address(_dnft));

      Pool pool = new Pool(address(dnft), address(dyad), PRICE_ORACLE_MAINNET);

      dyad.setMinter(address(pool));
      dnft.setPool(address(pool));

      vm.stopBroadcast();
   }
}
