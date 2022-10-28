// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract dNFT is ERC721Enumerable{
  address public minter;

  mapping (uint => address) public idToOwner;
  mapping (uint => uint) public xp;

  event Mint(address indexed to, uint indexed id);

  constructor() ERC721("dyad NFT", "dNFT") {
    minter = msg.sender;
  }

  function mint(address receiver) public {
    uint id = totalSupply();
    idToOwner[id] = receiver;
    xp[id] += 100;
    _mint(receiver, id);

    emit Mint(receiver, id);
  }
}
