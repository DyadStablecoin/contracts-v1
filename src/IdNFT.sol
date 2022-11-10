// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IdNFT {
  struct Nft {
    // TODO: remove this!
    uint balance; // dyad directly owned by the dnft holder 
    uint deposit; // dyad balance in pool
    uint xp;      // always positive, always inflationary
  }

  function updateMaxXP(uint newMaxXP) external;
  function MAX_XP() external view returns (uint);
  function MAX_BALANCE() external view returns (uint);
  function MAX_DEPOSIT() external view returns (uint);

  function pool() external view returns (address);
  function idToOwner(uint id) external view returns (address);
  function updateNft(uint id, Nft memory metadata) external;
  function mintDyad(uint id) external payable;
  function withdraw(uint id, uint amount) external;
  function deposit(uint id, uint amount) external;
  function setPool(address newPool) external;
  function mint(address receiver) external payable returns (uint id);
  function burn(uint id) external;
  function balanceOf(uint id) external view returns (int);
  function xpOf(uint id) external view returns (uint);
  function dyadMintedOf(uint id) external view returns (uint);
  function virtualDyadBalanceOf(uint id) external view returns (int);
  function dyadInPoolOf(uint id) external view returns (uint);
  function lastCheckpointForIdOf(uint id) external view returns (uint);
  function totalSupply() external view returns (uint);
  function idToNft(uint) external view returns (Nft memory);
}

