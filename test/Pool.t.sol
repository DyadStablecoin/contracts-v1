// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/core/Dyad.sol";
import "ds-test/test.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/core/dNFT.sol";
import {OracleMock} from "./Oracle.t.sol";
import {Deployment} from "../script/Deployment.sol";
import {Parameters} from "../script/Parameters.sol";
import {Util} from "./util/Util.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

uint constant ORACLE_PRICE = 120000000000; // $1.2k

contract PoolTest is Test, Deployment, Parameters, Util, ERC721Holder {
  IdNFT public dnft;
  DYAD public dyad;
  OracleMock public oracle;

  function setUp() public {
    oracle = new OracleMock();
    setOraclePrice(oracle, ORACLE_PRICE); 

    address _dnft;
    address _dyad;
    (_dnft,_dyad) = deploy(
      DEPOSIT_MINIMUM_MAINNET,
      MAX_SUPPLY,
      BLOCKS_BETWEEN_SYNCS, 
      MIN_COLLATERIZATION_RATIO, 
      MAX_MINTED_BY_TVL,
      address(oracle),
      new address[](0)
    );
    dnft = IdNFT(_dnft);
    dyad = DYAD(_dyad);
  }

  // needed, so we can receive eth transfers
  receive() external payable {}

  function testSyncMaxSupply() public {
    for (uint i = 0; i < MAX_SUPPLY; i++) {
      dnft.mintNft{value: 5 ether}(address(this));
    }
    uint gas = gasleft();
    dnft.sync(99999);
    console.log("gas used", gas - gasleft());
  }

  function testFailSyncTooSoon() public {
    // we need to wait at least `BLOCKS_BETWEEN_SYNCS` blocks between syncs
    dnft.sync(99999);
    dnft.sync(99999);
  }
  function testSync() public {
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.sync(99999);
    vm.roll(block.number + BLOCKS_BETWEEN_SYNCS);
    dnft.sync(99999);
  }
}
