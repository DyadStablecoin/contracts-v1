// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IdNFT {
  struct Metadata {
    uint dyadInPool; // dyad balance in pool
    uint xp; // always positive, always inflationary
  }

  function pool() external view returns (address);
  function dyadInPool() external view returns (uint);
  function idToOwner(uint id) external view returns (address);
  function mintDyad(uint id) external payable;
  function withdraw(uint id, uint amount) external;

  function setPool(address newPool) external;

  function mint(address receiver) external returns (uint id);
  function burn(uint id) external;
  function balanceOf(uint id) external view returns (int);
  function xpOf(uint id) external view returns (uint);
  function dyadMintedOf(uint id) external view returns (uint);
  function virtualDyadBalanceOf(uint id) external view returns (int);
  function dyadInPoolOf(uint id) external view returns (uint);
  function lastCheckpointForIdOf(uint id) external view returns (uint);

  function totalSupply() external view returns (uint);
  function idToMetadata(uint) external view returns (Metadata memory);
}

