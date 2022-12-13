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
    uint limit;
  }

  mapping (uint => Stake) public stakes;

  modifier isStakeOwner(uint id) {
    require(msg.sender == stakes[id].owner, "Staking: Not stake owner");
    _;
  }

  constructor(address _dnft, address _dyad) {
    dnft = IdNFT(_dnft);
    dyad = DYAD(_dyad);
  }

  // is needed, because `dnft.redeem` sends us eth
  receive() external payable {}

  function stake(uint id, uint fee, uint limit) public  {
    dnft.transferFrom(msg.sender, address(this), id);
    stakes[id] = Stake(msg.sender, fee, limit);
  }

  function unstake(uint id) public isStakeOwner(id) {
    delete stakes[id];
    dnft.transferFrom(address(this), msg.sender, id);
  }

  function setLimit(uint id, uint newLimit) external isStakeOwner(id) {
    stakes[id].limit = newLimit;
  }

  function redeem(uint id, uint amount) public {
    Stake memory _stake = stakes[id];
    IdNFT.Nft memory nft = dnft.idToNft(id);
    require(nft.withdrawn - amount >= _stake.limit, "Staking: Exceeds limit");
    dyad.transferFrom(msg.sender, address(this), amount);
    dyad.approve(address(dnft), amount);
    uint usdInEth = dnft.redeem(id, amount);
    uint fee = PoolLibrary.percentageOf(usdInEth, _stake.fee);
    payable(_stake.owner).transfer(fee); 
    payable(msg.sender).transfer(usdInEth - fee);
  }

  // TODO: deposit + withdraw + redeem?
}
