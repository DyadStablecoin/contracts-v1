// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {IdNFT} from "../interfaces/IdNFT.sol";
import "forge-std/console.sol";
import "../../src/dyad.sol";
import {PoolLibrary} from "../PoolLibrary.sol";

struct Position {
  address owner; 
  uint    fee;          // fee in basis points
  address feeRecipient;
  uint    limit;        // limit the dnft withdrawn amount can not be below
}

contract Staking {
  IdNFT public dnft;
  DYAD public dyad;

  mapping (uint => Position) public positions;

  modifier isPositionOwner(uint id) {
    require(msg.sender == positions[id].owner, "Staking: Not stake owner");
    _;
  }

  constructor(address _dnft, address _dyad) {
    dnft = IdNFT(_dnft);
    dyad = DYAD(_dyad);
  }

  // is needed, because `dnft.redeem` sends us eth
  receive() external payable {}

  function stake(uint id, Position memory _position) public  {
    dnft.transferFrom(_position.owner, address(this), id);
    positions[id] = _position;
  }

  function unstake(uint id) public isPositionOwner(id) {
    dnft.transferFrom(address(this), positions[id].owner, id);
    delete positions[id];
  }

  function setPosition(uint id, Position memory _position) external isPositionOwner(id) {
    positions[id] = _position;
  }

  // redeem DYAD for ETH -> Position `feeRecipient` gets a fee
  function redeem(uint id, uint amount) public {
    Position memory _position = positions[id];
    IdNFT.Nft memory nft = dnft.idToNft(id);
    require(nft.withdrawn - amount >= _position.limit, "Staking: Exceeds limit");
    dyad.transferFrom(msg.sender, address(this), amount);
    dyad.approve(address(dnft), amount);
    uint usdInEth = dnft.redeem(id, amount);
    uint fee = PoolLibrary.percentageOf(usdInEth, _position.fee);
    payable(_position.feeRecipient).transfer(fee); 
    payable(msg.sender).transfer(usdInEth - fee);
  }

  // TODO: deposit + withdraw + redeem?
}
