// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/dNFT.sol";
import "../src/dyad.sol";
import "../src/pool.sol";

address constant PRICE_ORACLE_GOERLI = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;
// $5 deposit minimum
uint constant DEPOSIT_MINIMUM = 5000000000000000000;

// Pseudo-code, may not compile.
contract DeployGoerli is Script {
  uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

  function run() public {
    vm.startBroadcast(deployerPrivateKey);

    DYAD dyad = new DYAD();

    dNFT _dnft = new dNFT(address(dyad), DEPOSIT_MINIMUM, true); // with insider alloc
    IdNFT dnft = IdNFT(address(_dnft));

    Pool pool = new Pool(address(dnft), address(dyad), PRICE_ORACLE_GOERLI);

    dnft.setPool(address(pool));
    dyad.setMinter(address(pool));

    vm.stopBroadcast();
  }
}

