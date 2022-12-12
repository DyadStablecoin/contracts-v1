// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {IdNFT} from "../interfaces/IdNFT.sol";
import "forge-std/console.sol";

contract Stake {
  IdNFT public dnft;

  constructor(address _dnft) {
    dnft = IdNFT(_dnft);
  }

  receive() external payable {}

  function ss(uint id) public  {
    console.log("id", id);
    console.log(msg.sender);
    dnft.transferFrom(msg.sender, address(this), id);
  }

  function unstake(uint id) public {
  }

}
