// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/core/Dyad.sol";
import "ds-test/test.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/core/dNFT.sol";
import {OracleMock} from "./Oracle.t.sol";
import {Parameters} from "../script/Parameters.sol";
import {Deployment} from "../script/Deployment.sol";

interface CheatCodes {
   // Gets address for a given private key, (privateKey) => (address)
   function addr(uint256) external returns (address);
}

address constant CHAINLINK_ORACLE_ADDRESS = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
uint constant DEPOSIT_MINIMUM = 5000000000000000000000;

// this should simulate the inital lauch on mainnet
// IMPORTANT: you have to run this as a mainnet fork!!!
contract LaunchTest is Test, Parameters, Deployment {
  uint NUMBER_OF_INSIDER_NFTS;

  IdNFT public dnft;
  DYAD public dyad;
  OracleMock public oracle;

  // --------------------- Test Addresses ---------------------
  CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
  address public addr1;
  address public addr2;

  // needed, so we can receive eth transfers
  receive() external payable {}

  function setUp() public {
    address _dnft;
    address _dyad;
    (_dnft,_dyad) = deploy(
      DEPOSIT_MINIMUM,
      MAX_SUPPLY,
      BLOCKS_BETWEEN_SYNCS, 
      MIN_COLLATERIZATION_RATIO, 
      MAX_MINTED_BY_TVL, 
      CHAINLINK_ORACLE_ADDRESS,
      new address[](0)
    );
    dnft = IdNFT(_dnft);
    dyad = DYAD(_dyad);

    // directly after deployment the total supply has to be the number
    // of insider allocations.
    NUMBER_OF_INSIDER_NFTS = dnft.totalSupply();

    addr1 = cheats.addr(1); vm.deal(addr1, 100 ether);
    addr2 = cheats.addr(2); vm.deal(addr2, 100 ether);
  }

  function testInsiderAllocation() public {
    // we have `NUMBER_OF_INSIDER_NFTS` insiders that we allocate for
    assertEq(dnft.totalSupply(), NUMBER_OF_INSIDER_NFTS);
  }

  function testFirstSync() public {
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.sync(99999);
  }

  function testMintNormallyAndSync() public {
    dnft.mintNft{value: 5 ether}(address(this));
    vm.prank(addr1);
    dnft.mintNft{value: 5 ether}(address(this));
    vm.prank(addr2);
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.sync(99999);
  }

  function testWithdrawAndSync() public {
    dnft.mintNft{value: 5 ether}(addr1);
    vm.prank(addr1);
    // remember the nfts are 0 indexed, so we do not need to increment by 1.
    dnft.withdraw(NUMBER_OF_INSIDER_NFTS, 4 ether);

    dnft.mintNft{value: 5 ether}(addr2);
    vm.prank(addr2);
    // remember the nfts are 0 indexed, so we do not need to increment by 1.
    dnft.withdraw(NUMBER_OF_INSIDER_NFTS+1, 3 ether);

    dnft.sync(99999);
  }

  // very self explanatory I think. Do random stuff and see if it breaks.
  // I think you call that fuzzy testing, lol :D
  function testDoRandomStuffAndSync() public {
    uint currentBlockNumber = block.number;
    uint numberOfSyncCalls  = 0;

    dnft.mintNft{value: 5 ether}(address(this));
    dnft.sync(99999);
    numberOfSyncCalls += 1;

    // mint nfts
    uint id1 = dnft.mintNft{value: 5 ether}(address(this));
    vm.prank(addr1);
    uint id2 = dnft.mintNft{value: 12 ether}(addr1);
    vm.prank(addr1);
    uint id3 = dnft.mintNft{value: 5 ether}(addr1);
    vm.prank(addr2);
    uint id4 = dnft.mintNft{value: 14 ether}(addr2);
    vm.prank(addr2);
    uint id5 = dnft.mintNft{value: 5 ether}(addr2);
    uint id6 = dnft.mintNft{value: 8 ether}(address(this));
    uint id7 = dnft.mintNft{value: 5 ether}(address(this));

    vm.roll(currentBlockNumber + (numberOfSyncCalls*BLOCKS_BETWEEN_SYNCS));
    dnft.sync(99999);
    numberOfSyncCalls += 1;

    // do some withdraws
    dnft.withdraw(id1, 2 ether);
    dnft.withdraw(id1, 1 ether);
    vm.prank(addr1);
    dnft.withdraw(id2, 66626626262662);
    vm.prank(addr1);
    dnft.withdraw(id3, 4 ether);
    vm.prank(addr2);
    dnft.withdraw(id4, 100000000000);
    vm.prank(addr2);
    dnft.withdraw(id5, 5 ether);
    dnft.withdraw(id6, 2 ether);
    dnft.withdraw(id7, 4444444444444);

    vm.roll(currentBlockNumber + (numberOfSyncCalls*BLOCKS_BETWEEN_SYNCS));
    dnft.sync(99999);
    numberOfSyncCalls += 1;

    // do some deposits
    dyad.approve(address(dnft), 5 ether);
    dnft.deposit(id1, 1 ether);
    dnft.deposit(id1, 5000000);
    vm.prank(addr2);
    dyad.approve(address(dnft), 5 ether);
    vm.prank(addr2);
    dnft.deposit(id4, 1000);

    for(uint i = 0; i < 4; i++) { 
      vm.roll(currentBlockNumber + (numberOfSyncCalls*BLOCKS_BETWEEN_SYNCS));
      dnft.sync(99999);
      numberOfSyncCalls += 1;
    }

    // do some redeems
    dyad.approve(address(dnft), 5 ether);
    dnft.redeem(id1, 100000002);
    dnft.redeem(id1, 100000202);
    dnft.redeem(id1, 3000000202);

    for(uint i = 0; i < 4; i++) { 
      vm.roll(currentBlockNumber + (numberOfSyncCalls*BLOCKS_BETWEEN_SYNCS));
      dnft.sync(99999);
      numberOfSyncCalls += 1;
    }
  }
}
