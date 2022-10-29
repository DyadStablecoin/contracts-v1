// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../src/dyad.sol";
import "../src/pool.sol";

contract dNFT is ERC721Enumerable{
  uint public constant MAX_SUPPLY = 1000;

  address public minter;
  DYAD public dyad;
  Pool public pool;

  mapping (uint => address) public idToOwner;
  mapping (uint => uint) public xp;

  event Mint(address indexed to, uint indexed id);

  constructor(address _dyad) ERC721("dyad NFT", "dNFT") {
    minter = msg.sender;
    dyad = DYAD(_dyad);
  }

  function setPool(address newPool) public {
    require(msg.sender == minter, "Only minter can set pool");
    pool = Pool(newPool);
  }

  function mint(address receiver) public {
    uint id = totalSupply();
    require(id < MAX_SUPPLY, "Max supply reached");
    idToOwner[id] = receiver;
    xp[id] += 100;
    _mint(receiver, id);
    emit Mint(receiver, id);
  }
}
