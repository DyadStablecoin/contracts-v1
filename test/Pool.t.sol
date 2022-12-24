// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/core/Dyad.sol";
import "../src/core/Pool.sol";
import "ds-test/test.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT, Nft} from "../src/core/dNFT.sol";
import {PoolLibrary} from "../src/libraries/PoolLibrary.sol";
import {OracleMock} from "./Oracle.t.sol";
import {Deployment} from "../script/Deployment.sol";
import {Parameters} from "../script/Parameters.sol";
import {Util} from "./util/Util.sol";

uint constant ORACLE_PRICE = 120000000000; // $1.2k

contract PoolTest is Test, Deployment, Parameters, Util {
  IdNFT public dnft;
  DYAD public dyad;
  Pool public pool;
  OracleMock public oracle;

  function setUp() public {
    oracle = new OracleMock();
    setOraclePrice(oracle, ORACLE_PRICE); 

    address _dnft;
    address _pool;
    address _dyad;
    (_dnft,_pool,_dyad) = deploy(address(oracle),
                                 DEPOSIT_MINIMUM_MAINNET,
                                 MIN_COLLATERIZATION_RATIO, 
                                 MAX_SUPPLY,
                                 new address[](0));
    dnft = IdNFT(_dnft);
    pool = Pool(_pool);
    dyad = DYAD(_dyad);
  }

  // needed, so we can receive eth transfers
  receive() external payable {}

  function testSyncMaxSupply() public {
    for (uint i = 0; i < MAX_SUPPLY; i++) {
      dnft.mintNft{value: 5 ether}(address(this));
    }
    dnft.sync();
  }
}
