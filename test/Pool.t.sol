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

// mainnnet
address constant PRICE_ORACLE_ADDRESS = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
uint constant ORACLE_PRICE = 120000000000; // $1.2k
uint constant DEPOSIT_MINIMUM = 5000000000000000000000;

interface CheatCodes {
   // Gets address for a given private key, (privateKey) => (address)
   function addr(uint256) external returns (address);
}

contract PoolTest is Test {
  using stdStorage for StdStorage;

  IdNFT public dnft;
  DYAD public dyad;
  Pool public pool;
  OracleMock public oracle;

  // --------------------- Test Addresses ---------------------
  CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
  address public addr1;
  address public addr2;

  function setOraclePrice(uint price) public {
    vm.store(address(oracle), bytes32(uint(0)), bytes32(price)); 
  }

  function setUp() public {
    oracle = new OracleMock();
    dyad = new DYAD();

    // set oracle price
    setOraclePrice(ORACLE_PRICE); // $1.2k

    // // init dNFT contract
    dNFT _dnft = new dNFT(address(dyad), DEPOSIT_MINIMUM, false);
    dnft = IdNFT(address(_dnft));

    pool = new Pool(address(dnft), address(dyad), address(oracle));

    dnft.setPool(address(pool));
    dyad.setMinter(address(pool));

    addr1 = cheats.addr(1);
    addr2 = cheats.addr(2);
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
    pool.claim(0, addr1);
  }
}
