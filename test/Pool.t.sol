// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/dyad.sol";
import "../src/pool.sol";
import "ds-test/test.sol";
import {IdNFT} from "../src/IdNFT.sol";
import {dNFT} from "../src/dNFT.sol";

contract PoolTest is Test {
  DYAD public dyad;
  Pool public pool;
  IdNFT public dnft;

  function setUp() public {
    dyad = new DYAD();

    // init dNFT contract
    dNFT _dnft = new dNFT(address(dyad));
    dnft = IdNFT(address(_dnft));

    pool = new Pool(address(dnft), address(dyad));

    dyad.setMinter(address(pool));
    dnft.setPool(address(pool));
  }

  function overwriteLastEthPrice(uint newPrice) public {
    vm.store(address(pool), 0, bytes32(newPrice));
  }

  function testSync() public {
    pool.sync();
    // sanity check
    assertTrue(pool.lastEthPrice() > 0);

    // mint some dyad
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.mintDyad{value: 2 ether}(0); 

    dnft.mintNft{value: 10 ether}(address(this));
    dnft.mintDyad{value: 3 ether}(1); 

    dnft.mintNft{value: 8 ether}(address(this));
    dnft.mintDyad{value: 1 ether}(2); 

    IdNFT.Nft memory nft0 = dnft.idToNft(0);
    console.log(nft0.deposit);
    console.log(nft0.xp);

    overwriteLastEthPrice(130000000000);
    pool.sync();

    nft0 = dnft.idToNft(0);
    console.log(nft0.deposit);
    console.log(nft0.xp);
  }
}
