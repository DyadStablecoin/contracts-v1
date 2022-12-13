// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {IdNFT} from "../interfaces/IdNFT.sol";
import "forge-std/console.sol";
import "../../src/dyad.sol";
import {PoolLibrary} from "../PoolLibrary.sol";

contract Staking {
  IdNFT public dnft;
  DYAD public dyad;

  struct Stake {
    address owner;
    uint fee;
  }

  mapping (uint => Stake) public stakes;

  constructor(address _dnft, address _dyad) {
    dnft = IdNFT(_dnft);
    dyad = DYAD(_dyad);
  }

  // is needed, because `dnft.reddem` sends us eth
  receive() external payable {}

  function stake(uint id, uint fee) public  {
    dnft.transferFrom(msg.sender, address(this), id);
    stakes[id] = Stake(msg.sender, fee);
  }

  function unstake(uint id) public {
    require(stakes[id].owner == msg.sender, "not your stake");
    delete stakes[id];
    dnft.transferFrom(address(this), msg.sender, id);
  }

  function redeem(uint id, uint amount) public {
    dyad.transferFrom(msg.sender, address(this), amount);
    dyad.approve(address(dnft), amount);
    uint usdInEth = dnft.redeem(id, amount);
    Stake memory stake = stakes[id];
    uint fee = PoolLibrary.percentageOf(usdInEth, stake.fee);
    payable(stake.owner).transfer(fee); 
    payable(msg.sender).transfer(usdInEth - fee);
  }
}
