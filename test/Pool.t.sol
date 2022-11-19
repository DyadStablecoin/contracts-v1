// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/dyad.sol";
import "../src/pool.sol";
import "ds-test/test.sol";
import {IdNFT} from "../src/IdNFT.sol";
import {dNFT} from "../src/dNFT.sol";

interface CheatCodes {
   // Gets address for a given private key, (privateKey) => (address)
   function addr(uint256) external returns (address);
}

contract PoolTest is Test {
  DYAD public dyad;
  Pool public pool;
  IdNFT public dnft;

  CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

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
    dnft.addTestNft(0, 2161, 146, 3920);
    dnft.addTestNft(1, 7588, 4616, 7496);
    dnft.addTestNft(2, 3892, 2731, 10644);
    dnft.addTestNft(3, 3350, 4515, 2929);
    dnft.addTestNft(4, 3012, 2086, 3149);
    dnft.addTestNft(5, 5496, 7241, 7127);
    dnft.addTestNft(6, 8000, 8197, 7548);
    dnft.addTestNft(7, 7000, 5873, 9359);
    dnft.addTestNft(8, 3435, 1753, 4427);
    dnft.addTestNft(9, 1079, 2002, 244);

    // dnft.addTestNft(1, 2161, 146, 3920);
    // pool.sync();

    // // sanity check
    // assertTrue(pool.lastEthPrice() > 0);

    // overwriteLastEthPrice(100000000000);
    // for (uint i = 0; i < 10; i++) {
    //   dnft.mintNft{value: 1000 ether}(cheats.addr(i+1)); // i+1 to avoid 0x0 address
    // }

    // for (uint i = 0; i < 10; i++) {
    //   vm.prank(cheats.addr(i+1)); 
    //   dnft.withdraw(i, 200000000000000000000000); 
    // }

    // IdNFT.Nft memory metadata = dnft.idToNft(1);

    // overwriteLastEthPrice(100000000000);
    // // overwriteLastEthPrice(130000000000);
    // pool.sync();

    // mint some dyad
    // dnft.mintNft{value: 5 ether}(address(this));
    // dnft.mintDyad{value: 2 ether}(0); 

    // dnft.mintNft{value: 10 ether}(address(this));
    // dnft.mintDyad{value: 3 ether}(1); 

    // dnft.mintNft{value: 8 ether}(address(this));
    // dnft.mintDyad{value: 1 ether}(2); 

    // IdNFT.Nft memory nft0 = dnft.idToNft(0);
    // console.log(nft0.deposit);
    // console.log(nft0.xp);

    // overwriteLastEthPrice(130000000000);
    // pool.sync();

    // nft0 = dnft.idToNft(0);
    // console.log(nft0.deposit);
    // console.log(nft0.xp);
  }
}
