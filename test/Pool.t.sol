// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/core/dyad.sol";
import "../src/core/Pool.sol";
import "ds-test/test.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/core/dNFT.sol";
import {PoolLibrary} from "../src/libraries/PoolLibrary.sol";
import {OracleMock} from "./Oracle.t.sol";
import {Deployment} from "../script/Deployment.sol";
import {Parameters} from "../script/Parameters.sol";
import {Util} from "./util/Util.sol";

uint constant ORACLE_PRICE = 120000000000; // $1.2k

contract PoolTest is Test, Deployment, Parameters, Util {
  using stdStorage for StdStorage;

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
                                 new address[](0));
    dnft = IdNFT(_dnft);
    pool = Pool(_pool);
    dyad = DYAD(_dyad);
  }

  // needed, so we can receive eth transfers
  receive() external payable {}

  // --------------------- NFT Claim ---------------------
  function testClaimNft() public {
    dnft.mintNft{value: 5 ether}(address(this));
    IdNFT.Nft memory nft = dnft.idToNft(0);
    // TODO: it seems that we have to set isClaimable to true, through our logic
    // and not directly through state manipulation
    nft = dnft.idToNft(0);
  }
  function testFailClaimNftNotClaimable() public {
    dnft.mintNft{value: 5 ether}(address(this));
    // can not claim this, because it is not claimable
    pool.claim(0, address(this));
  }
}
