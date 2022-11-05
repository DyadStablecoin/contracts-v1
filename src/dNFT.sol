// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {DYAD} from "../src/dyad.sol";
import {Pool} from "../src/pool.sol";
import {IdNFT} from "../src/IdNFT.sol";

contract dNFT is ERC721Enumerable{
  using SafeMath for uint256;

  // maximum number of nfts that can exist at any moment
  // TODO: it is more dynamic than this!
  uint public constant MAX_SUPPLY = 1000;

  address public owner;
  DYAD public dyad;
  Pool public pool;

  // mapping from nft id to metadata
  mapping(uint => IdNFT.Metadata) public idToMetadata;
  // mapping from nft id to owner
  mapping (uint => address) public idToOwner;

  event Mint(address indexed to, uint indexed id);

  /// @dev Check if owner of NFT is msg.sender
  /// @param id The id of the NFT
  modifier onlyNFTOwner(uint id) {
    require(idToOwner[id] == msg.sender, "Only NFT owner can call this function");
    _;
  }

  constructor(address _dyad) ERC721("dyad NFT", "dNFT") {
    owner = msg.sender;
    dyad = DYAD(_dyad);
  }

  function setPool(address newPool) external {
    require(msg.sender == owner, "Only owner can set pool");
    pool = Pool(newPool);
  }

  /// @notice Mints a new dNFT
  /// @param receiver The address to mint the dNFT to
  function mint(address receiver) external returns (uint id) {
    id = totalSupply();
    require(id < MAX_SUPPLY, "Max supply reached");
    idToOwner[id] = receiver;

    // add 100 xp to the nft to start with
    IdNFT.Metadata storage metadata = idToMetadata[id];
    metadata.xp = metadata.xp.add(100);

    _mint(receiver, id);
    emit Mint(receiver, id);
  }

  /// @notice Mint new dyad to the NFT
  /// @param id The NFT id
  function mintDyad(uint id) payable external onlyNFTOwner(id) {
    // mint dyad to the nft contract
    // approve the pool to spend the dyad
    // deposit minted dyad to the pool
    uint amount = pool.mintDyad{value: msg.value}();
    dyad.approve(address(pool), amount);
    pool.deposit(amount);

    // update struct
    IdNFT.Metadata storage metadata = idToMetadata[id];
    metadata.dyadInPool = metadata.dyadInPool.add(amount);
  }

  /// @notice Withdraw dyad from the NFT to the msg.sender
  /// @param id The NFT id
  /// @param amount The amount of dyad to withdraw
  function withdraw(uint id, uint amount) external onlyNFTOwner(id) {
    IdNFT.Metadata storage metadata = idToMetadata[id];
    require(amount <= metadata.dyadInPool, "Not enough dyad in pool to withdraw");

    pool.withdraw(msg.sender, amount);

    // update struct
    metadata.dyadInPool = metadata.dyadInPool.sub(amount);
  }

  /// @notice Deposit dyad in the pool
  /// @param id The NFT id
  /// @param amount The amount of dyad to deposit
  function deposit(uint id, uint amount) external onlyNFTOwner(id) {
    // transfer dyad to the nft
    // approve the pool to spend the dyad of this contract
    // deposit dyad in the pool
    dyad.transferFrom(msg.sender, address(this), amount);
    dyad.approve(address(pool), amount);
    pool.deposit(amount);

    // update struct
    IdNFT.Metadata storage metadata = idToMetadata[id];
    metadata.dyadInPool = metadata.dyadInPool.add(amount);
  }
}
