// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/dyad.sol";
import "../src/pool.sol";
import "ds-test/test.sol";
import {IdNFT} from "../src/IdNFT.sol";
import {dNFT} from "../src/dNFT.sol";
import {PoolLibrary} from "../src/PoolLibrary.sol";
import {OracleMock} from "./Oracle.t.sol";

// mainnnet
address constant PRICE_ORACLE_ADDRESS = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
uint constant ORACLE_PRICE = 120000000000; // $1.2k

interface CheatCodes {
   // Gets address for a given private key, (privateKey) => (address)
   function addr(uint256) external returns (address);
}

contract dNFTTest is Test {
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
    dNFT _dnft = new dNFT(address(dyad), false);
    dnft = IdNFT(address(_dnft));

    pool = new Pool(address(dnft), address(dyad), address(oracle));

    dnft.setPool(address(pool));
    dyad.setMinter(address(pool));

    addr1 = cheats.addr(1);
    addr2 = cheats.addr(2);
  }

  // needed, so we can receive eth transfers
  receive() external payable {}

  function testFailSetPoolOnlyOnce() public {
    // you can only set the pool once. As it was already set in the setUp function
    // this should fail.
    dnft.setPool(address(this));
  }

  // --------------------- Nft Mint ---------------------
  function testMintOneNft() public {
    uint id = dnft.mintNft{value: 5 ether}(address(this));
    IdNFT.Nft memory metadata = dnft.idToNft(0);

    assertEq(id,                                        0);
    assertEq(dnft.totalSupply(),                        1);
    assertEq(metadata.withdrawn,                        0);
    assertEq(metadata.deposit  , ORACLE_PRICE*50000000000);
    assertEq(metadata.xp       ,                   900300); 

    stdstore.target(address(dnft)).sig("MIN_XP()").checked_write(uint(0));    // min xp
    stdstore.target(address(dnft)).sig("MAX_XP()").checked_write(uint(900300)); // max xp
    pool.sync();
  }
  function testMintNftTotalSupply() public {
    for (uint i = 0; i < 50; i++) {
      dnft.mintNft{value: 5 ether}(address(this));
    }
    assertEq(dnft.totalSupply(), 50);
  }
  function testFailMintNftDepositMinimum() public {
    // to mint an nft, we need to send 5 ETH
    dnft.mintNft{value: 4 ether}(address(this));
  }
  function testFailMintNftMaximumSupply() public {
    // only `dnft.MAXIMUM_SUPPLY` nfts can be minted
    for (uint i = 0; i < dnft.MAX_SUPPLY()+1; i++) {
      dnft.mintNft{value: 5 ether}(address(this));
    }
  }
  function testMintNftNotClaimable() public {
    // nft is not claimable by default
    dnft.mintNft{value: 5 ether}(address(this));
    assertEq(dnft.idToNft(0).isClaimable, false);
  }

  // --------------------- DYAD Minting ---------------------
  function testFailMintDyadNotNftOwner() public {
    // only the owner of the nft can mint dyad
    dnft.mintNft{value: 5 ether}(address(this));
    vm.prank(address(0));
    dnft.mintDyad{value: 1 ether}(0);
  }
  function testFailMintDyadWithoutOwner() public {
    dnft.mintDyad{value: 1 ether}(99);
  }
  function testFailMintDyadWithoutEth() public {
    // to mint dyad, we need to send ETH > 0
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.mintDyad{value: 0 ether}(0);
  }
  function testMintDyad() public {
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.mintDyad{value: 1 ether}(0);
  }
  function testMintDyadDepositUpdated() public {
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.mintDyad{value: 1 ether}(0);
    IdNFT.Nft memory metadata = dnft.idToNft(0);
    // its 6 ETH because we minted 1 ETH dyad and deposited 5 whilte
    // minting the nft.
    assertEq(metadata.deposit, ORACLE_PRICE*60000000000);
  }
  function testMintDyadWithdrawnNotUpdated() public {
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.mintDyad{value: 1 ether}(0);
    IdNFT.Nft memory metadata = dnft.idToNft(0);
    assertEq(metadata.withdrawn, 0);
  }

  // --------------------- DYAD Withdraw ---------------------
  function testWithdrawDyad() public {
    uint AMOUNT_TO_WITHDRAW = 7000000;
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.mintDyad{value: 1 ether}(0);
    dnft.withdraw(0, AMOUNT_TO_WITHDRAW);
    assertEq(dnft.idToNft(0).withdrawn, AMOUNT_TO_WITHDRAW);
    assertEq(dnft.idToNft(0).deposit, ORACLE_PRICE*60000000000-AMOUNT_TO_WITHDRAW);
  }
  function testFailWithdrawDyadNotNftOwner() public {
    dnft.mintNft{value: 5 ether}(address(this));
    vm.prank(address(0));
    dnft.withdraw(0, 7000000);
  }
  function testFailWithdrawDyadExceedsBalance() public {
    dnft.mintNft{value: 5 ether}(address(this));
    // exceeded nft deposit by exactly 1
    dnft.withdraw(0, ORACLE_PRICE*50000000000+1); 
  }

  // --------------------- DYAD Deposit ---------------------
  function testDepositDyad() public {
    uint AMOUNT_TO_DEPOSIT = 7000000;
    dnft.mintNft{value: 5 ether}(address(this));
    // withdraw dyad -> so we have something to deposit
    dnft.withdraw(0, AMOUNT_TO_DEPOSIT);
    // we need to approve the dnft contract to spend our dyad
    dyad.approve(address(dnft), AMOUNT_TO_DEPOSIT);
    dnft.deposit (0, AMOUNT_TO_DEPOSIT);
    assertEq(dnft.idToNft(0).withdrawn, 0);
    assertEq(dnft.idToNft(0).deposit, ORACLE_PRICE*50000000000);
  }
  function testFailDepositDyadNotNftOwner() public {
    dnft.mintNft{value: 5 ether}(address(this));
    vm.prank(address(0));
    dnft.deposit(0, 7000000);
  }
  function testFailDepositDyadExceedsBalance() public {
    // msg.sender needs some dyad to deposit something
    dnft.mintNft{value: 5 ether}(address(this));
    // exceeded nft deposit by exactly 1
    dyad.approve(address(dnft), 100);
    // msg.sender does not own any dyad so this should fail
    dnft.deposit(0, 100); 
  }
}
