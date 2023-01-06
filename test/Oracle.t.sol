// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/core/Dyad.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/core/dNFT.sol";
import {OracleMock} from "./Oracle.t.sol";
import {Util} from "./util/Util.sol";
import {Deployment} from "../script/Deployment.sol";
import {Parameters} from "../script/Parameters.sol";
import {ITellor} from "test/interfaces/ITellor.sol";
import {IPriceFeed} from "../src/interfaces/IPriceFeed.sol";

address constant CHAINLINK_TELLOR_FALLBACK = 0x4c517D4e2C851CA76d7eC94B805269Df0f2201De;
address constant TELLOR_TOKEN = 0x88dF592F8eb5D7Bd38bFeF7dEb0fBc02cf3778a0;
address constant TELLOR_ORACLE = 0xB3B662644F8d3138df63D2F43068ea621e2981f9;
uint constant DEPOSIT_MINIMUM = 5000000000000000000000;

address constant BIG_HOLDER = 0x39E419bA25196794B595B2a595Ea8E527ddC9856;


contract OracleMock {
  // NOTE: this value has to be overwritten in the tests
  // 
  // Some examples for quick copy/pasta:
  // 95000000  -> - 5%
  // 110000000 -> +10%
  // 100000000 -> +-0%
  uint public price = 0;

  function fetchPrice() external view returns (uint)  {

    return price * 1e10; //liquity values = val * 1e18, whereas dyad oracle values in tests are val * 1e10
  }
}

contract OracleTest is Test, Deployment, Util, Parameters {

  IdNFT public dnft;
  DYAD public dyad;
  ITellor public token;
  ITellor public oracle;

  IPriceFeed public liquityPriceFeed;

  function setUp() public {
    address _dnft;
    address _dyad;
    (_dnft,_dyad) = deploy(CHAINLINK_TELLOR_FALLBACK,
                                 DEPOSIT_MINIMUM,
                                 BLOCKS_BETWEEN_SYNCS, 
                                 MIN_COLLATERIZATION_RATIO, 
                                 MAX_SUPPLY,
                                 new address[](0));
    dnft = IdNFT(_dnft);
    dyad = DYAD(_dyad);

    token = ITellor(TELLOR_TOKEN);
    oracle = ITellor(TELLOR_ORACLE);

    liquityPriceFeed = IPriceFeed(CHAINLINK_TELLOR_FALLBACK);

  }

  function testPriceFeed() public {

    uint oldPrice = liquityPriceFeed.fetchPrice();

    assertGe(oldPrice, 1e18);

    vm.startPrank(BIG_HOLDER);

    IERC20(TELLOR_TOKEN).approve(TELLOR_ORACLE, 1000e18);

    //deposit stake
    oracle.depositStake(1000e18);

    //submit a value
    bytes memory queryData = abi.encode("SpotPrice", abi.encode("eth", "usd"));
    bytes32 queryId = keccak256(queryData);

    skip(60 * 60 * 4 + 1);


    oracle.submitValue(queryId, abi.encode(1200e18), 0, queryData);

    skip(60 * 15 + 1);

    uint newPrice = liquityPriceFeed.fetchPrice();
    assertEq(newPrice, 1200e18);    
  }

}