// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";
// import "ds-test/test.sol";

// import {IdNFT} from "../../src/interfaces/IdNFT.sol";
// import {dNFT} from "../../src/core/dNFT.sol";
// import {OracleMock} from "./../Oracle.t.sol";
// import "../../src/core/Dyad.sol";
// import {Deployment} from "../../script/Deployment.sol";
// import {Parameters} from "../../script/Parameters.sol";
// import {Staking, Position} from "../../src/stake/Staking.sol";

// uint constant DEPOSIT_MINIMUM = 5000000000000000000000;
// uint constant ORACLE_PRICE = 120000000000; // $1.2k

// interface CheatCodes {
//    function addr(uint256) external returns (address);
// }

// contract StakeTest is Test, Deployment, Parameters {
//   using stdStorage for StdStorage;

//   OracleMock public oracle;
//   IdNFT public dnft;
//   DYAD public dyad;
//   Staking public staking;
//   CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
//   address public addr1;

//   function setOraclePrice(uint price) public {
//     vm.store(address(oracle), bytes32(uint(0)), bytes32(price)); 
//   }

//   function setUp() public {
//     oracle = new OracleMock();

//     setOraclePrice(ORACLE_PRICE);

//     address _dnft; address _dyad;
//     (_dnft, _dyad) = new Deployment().deploy(address(oracle),
//                                                     DEPOSIT_MINIMUM,
//                                                     BLOCKS_BETWEEN_SYNCS, 
//                                                     MIN_COLLATERIZATION_RATIO, 
//                                                     MAX_SUPPLY,
//                                                     INSIDERS);

//     dyad = DYAD(_dyad);
//     dnft = IdNFT(_dnft);
//     staking = new Staking(_dnft, _dyad);

//     addr1 = cheats.addr(1);
//   }

//   // function testStake() public {
//   //   uint amount = 100*10**18;
//   //   uint id = dnft.mintNft{value: 15 ether}(addr1);

//   //   vm.startPrank(addr1);

//   //   dyad.approve(address(dnft), amount);
//   //   dnft.withdraw(id, amount);
//   //   dnft.approve(address(staking), id);
//   //   Position memory _position = Position(addr1, 100, addr1, 200, 8000 * 10**18);
//   //   staking.stake(id, _position); // fee of 1%
//   //   dyad.approve(address(staking), amount);
//   //   staking.redeem(id, amount - 200);
//   //   staking.unstake(id);

//   //   dnft.approve(address(staking), id);
//   //   staking.stake(id, _position); // fee of 1%

//   //   vm.stopPrank();

//   //   uint balancePre = dyad.balanceOf(address(this));
//   //   staking.mint{value: 5 ether}(id);
//   //   assertTrue(dyad.balanceOf(address(this)) > balancePre);
//   // }
// }
