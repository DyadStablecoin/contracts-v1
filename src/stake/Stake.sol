// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {IdNFT} from "../interfaces/IdNFT.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Stake is IERC721Receiver {
  IdNFT public dnft;

  constructor(address _dnft) {
    dnft = IdNFT(_dnft);
  }

  function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

  receive() external payable {}

  function stake(uint id) public  {
    console.log(address(this));
    dnft.transferFrom(msg.sender, address(this), id);
  }

  function unstake(uint id) public {
  }

}
