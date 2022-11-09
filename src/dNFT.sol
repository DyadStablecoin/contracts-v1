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

  // here we store the maximum value over every dNFT,
  // which allows us to do a normalization, without iterating over
  // all of them to find the max value.
  // Why init to 100? Because otherwise the normalization function in 
  // the `PoolLibrary` breaks. We always need to make sure that these 
  // values are not smaller than 100.
  uint public MAX_XP      = 100;
  uint public MAX_BALANCE = 100;
  uint public MAX_DEPOSIT = 100;

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

  // we need to update the max xp value from the pool, that is why we need this
  function setMaxXP(uint newXP) public {
    require(msg.sender == address(pool), "Only the pool can call this function");
    if (newXP > MAX_XP) {
      MAX_XP = newXP;
    }
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
    metadata.deposit = metadata.deposit.add(amount);
  }

  /// @notice Withdraw dyad from the NFT to the msg.sender
  /// @param id The NFT id
  /// @param amount The amount of dyad to withdraw
  function withdraw(uint id, uint amount) external onlyNFTOwner(id) {
    IdNFT.Metadata storage metadata = idToMetadata[id];
    require(amount <= metadata.deposit, "Not enough dyad in pool to withdraw");

    pool.withdraw(msg.sender, amount);

    // update struct
    metadata.deposit = metadata.deposit     .sub(amount);
    metadata.balance = metadata.balance.add(amount);

    // update max value
    if (metadata.balance > MAX_BALANCE) {
      MAX_BALANCE = metadata.balance;
    }
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

    metadata.deposit = metadata.deposit.add(amount);
    metadata.balance = metadata.balance.sub(amount);

    // update max value
    if (metadata.deposit > MAX_DEPOSIT) {
      MAX_DEPOSIT = metadata.deposit;
    }
  }
}
