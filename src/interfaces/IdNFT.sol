// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IdNFT {
  struct Nft {
    uint withdrawn;   // dyad withdrawn from the pool deposit
    int deposit;      // dyad balance in pool
    uint xp;          // always positive, always inflationary
    bool isLiquidatable;
  }

  function updateMaxXP(uint newMaxXP) external;
  function MIN_XP() external view returns (uint);
  function MAX_XP() external view returns (uint);
  function MAX_BALANCE() external view returns (uint);
  function MAX_DEPOSIT() external view returns (uint);
  function MAX_SUPPLY() external view returns (uint);
  function totalXp() external view returns (uint);
  function pool() external view returns (address);
  function ownerOf(uint tokenId) external view returns (address);
  function updateNft(uint id, Nft memory metadata) external;
  function mintDyad(uint id) external payable returns (uint);
  function withdraw(uint id, uint amount) external;
  function deposit(uint id, uint amount) external;
  function redeem(uint id, uint amount) external returns (uint);
  function mintNft(address receiver) external payable returns (uint id);
  function mintCopy(address receiver, IdNFT.Nft memory nft) external payable returns (uint id);
  function burn(uint id) external;
  function balanceOf(uint id) external view returns (int);
  function xpOf(uint id) external view returns (uint);
  function dyadMintedOf(uint id) external view returns (uint);
  function virtualDyadBalanceOf(uint id) external view returns (int);
  function lastCheckpointForIdOf(uint id) external view returns (uint);
  function totalSupply() external view returns (uint);
  function idToNft(uint) external view returns (Nft memory);
  function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
  function approve(address to, uint tokenId) external;
  function updateXP(uint minXP, uint maxXP) external;
  function tokenByIndex(uint index) external returns (uint);
  function moveDeposit(uint from, uint to, uint amount) external;
  function sync() external returns (uint);
  function sync(uint id) external returns (uint);
  function liquidate(uint id, address to) external payable returns (uint);
}

