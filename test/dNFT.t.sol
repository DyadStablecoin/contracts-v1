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
import {Util} from "./util/Util.sol";
import {Deployment} from "../script/Deployment.sol";
import {Parameters} from "../script/Parameters.sol";

uint constant ORACLE_PRICE = 120000000000; // $1.2k

contract dNFTTest is Test, Deployment, Parameters, Util {
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
                                 MAX_SUPPLY,
                                 new address[](0));
    dnft = IdNFT(_dnft);
    pool = Pool(_pool);
    dyad = DYAD(_dyad);
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

    assertEq(id,                                             0);
    assertEq(dnft.totalSupply(),                             1);
    assertEq(metadata.withdrawn,                             0);
    assertEq(metadata.deposit  , int(ORACLE_PRICE*50000000000));
    assertEq(metadata.xp       ,                          1000); 

    stdstore.target(address(dnft)).sig("MIN_XP()").checked_write(uint(0));    // min xp
    stdstore.target(address(dnft)).sig("MAX_XP()").checked_write(uint(1000)); // max xp
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
    assertEq(metadata.deposit, int(ORACLE_PRICE*60000000000));
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
    assertEq(dnft.idToNft(0).deposit, int(ORACLE_PRICE*60000000000-AMOUNT_TO_WITHDRAW));
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
  function testFailWithdrawCollaterizationRationTooHigh() public {
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.mintDyad{value: 1 ether}(0);
    // this pushes the CR over 150% which disables the ability for anyone
    // to withdraw more dyad
    dnft.withdraw(0, 5000000000000000000000);
    dnft.withdraw(0, 2 ether);
  }
  function testUnblockCollaterizationRatioLock() public {
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.mintDyad{value: 1 ether}(0);
    uint AMOUNT = 5000000000000000000000;
    // this pushes the CR over 150% 
    dnft.withdraw(0, AMOUNT);
    dyad.approve(address(dnft), AMOUNT);
    // this returns the CR to something below 150%, which enables withdrawls
    // again
    dnft.deposit(0, AMOUNT);
    dnft.withdraw(0, 2 ether);
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
    assertEq(dnft.idToNft(0).deposit, int(ORACLE_PRICE*50000000000));
  }
  function testFailDepositDyadNotNftOwner() public {
    dnft.mintNft{value: 5 ether}(address(this));
    vm.prank(address(0));
    dnft.deposit(0, 7000000);
  }
  function testFailDepositDyadExceedsWithdrawn() public {
    // msg.sender needs some dyad to deposit something
    dnft.mintNft{value: 5 ether}(address(this));
    dyad.approve(address(dnft), 100);
    // msg.sender does not own any dyad withdrawn so we can't deposit
    dnft.deposit(0, 100); 
  }

  // --------------------- DYAD Redeem ---------------------
  uint REDEEM_AMOUNT = 100000000;

  function mintAndTransfer(uint amount) public {
    // mint -> withdraw -> transfer -> approve dNFT
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.withdraw(0,     amount);
    dyad.approve(address(dnft), amount);
  }
  function testRedeemDyad() public {
    mintAndTransfer(REDEEM_AMOUNT);
    dnft.redeem(0, REDEEM_AMOUNT);
  }
  function testRedeemDyadSenderDyadBalance() public {
    mintAndTransfer(REDEEM_AMOUNT);
    uint ethBalanceBefore = address(this).balance;
    dnft.redeem(0, REDEEM_AMOUNT);
    // before redeeming, the eth balance should be lower than after it
    assertTrue(ethBalanceBefore < address(this).balance);
  }
  function testRedeemDyadPoolBalance() public {
    mintAndTransfer(REDEEM_AMOUNT);
    uint oldPoolBalance = address(pool).balance;
    dnft.redeem(0, REDEEM_AMOUNT);
    // before redeeming, the pool balance should be higher than after it
    assertTrue(address(pool).balance < oldPoolBalance); 
  }
  function testRedeemDyadTotalSupply() public {
    mintAndTransfer(REDEEM_AMOUNT);
    uint oldDyadTotalSupply = dyad.totalSupply();
    dnft.redeem(0, REDEEM_AMOUNT);
    // the redeem burns the dyad so the total supply should be less
    assertTrue(dyad.totalSupply() < oldDyadTotalSupply);
  }
  function testFailRedeemNotNftOwner() public {
    // this should fail beacuse msg.sender is not the owner of dnft 1
    mintAndTransfer(REDEEM_AMOUNT);
    dnft.redeem(1, REDEEM_AMOUNT);
  }
}
