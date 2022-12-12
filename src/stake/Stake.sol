// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {IdNFT} from "../interfaces/IdNFT.sol";
import "forge-std/console.sol";
import "../../src/dyad.sol";

contract Stake {
  IdNFT public dnft;
  DYAD public dyad;
  mapping (uint => address) public stakes;

  constructor(address _dnft, address _dyad) {
    dnft = IdNFT(_dnft);
    dyad = DYAD(_dyad);
  }

  function stake(uint id) public  {
    stakes[id] = msg.sender;
    dnft.transferFrom(msg.sender, address(this), id);
  }

  function unstake(uint id) public {
    require(stakes[id] == msg.sender, "not your stake");
    dnft.transferFrom(address(this), msg.sender, id);
  }

  function redeem(uint id, uint amount) public {
    console.log(address(dyad));
    dyad.transferFrom(msg.sender, address(this), amount);
    // dyad.approve(address(dnft), amount);
    // dnft.redeem(id, amount);
  }
}
