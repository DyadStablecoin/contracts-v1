// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ICheatCodes {
   // Gets address for a given private key, (privateKey) => (address)
   function addr(uint256) external returns (address);
}
