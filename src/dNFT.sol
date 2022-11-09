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

  // mapping from nft id to nft metadata
  mapping(uint => IdNFT.Nft) public idToNft;
  // mapping from nft id to owner
  mapping (uint => address) public idToOwner;

  event Mint(address indexed to, uint indexed id);

  /// @dev Check if owner of NFT is msg.sender
  /// @param id The id of the NFT
  modifier onlyNFTOwner(uint id) {
    require(idToOwner[id] == msg.sender, "Only NFT owner can call this function");
    _;
  }

  /// @dev Check if caller is the pool
  modifier onlyPool() {
    require(address(pool) == msg.sender, "Only Pool can call this function");
    _;
  }

  /// @dev Check if caller is the owner
  modifier onlyOwner() {
    require(owner == msg.sender, "Only owner can call this function");
    _;
  }

  constructor(address _dyad) ERC721("dyad NFT", "dNFT") {
    owner = msg.sender;
    dyad = DYAD(_dyad);
  }

  function setPool(address newPool) external onlyOwner {
    require(msg.sender == owner, "Only owner can set pool");
    pool = Pool(newPool);
  }

  // we need to update the max xp value from the pool, that is why we need this
  function updateMaxXP(uint newXP) external onlyPool {
    if (newXP > MAX_XP) {
      MAX_XP = newXP;
    }
  }

  function updateNft(uint id, IdNFT.Nft memory metadata) external onlyPool {
    idToNft[id] = metadata;
  }

  /// @notice Mints a new dNFT
  /// @param receiver The address to mint the dNFT to
  function mint(address receiver) external returns (uint id) {
    id = totalSupply();
    require(id < MAX_SUPPLY, "Max supply reached");
    idToOwner[id] = receiver;

    // add 100 xp to the nft to start with
    IdNFT.Nft storage nft = idToNft[id];
    nft.xp = nft.xp.add(100);

    _mint(receiver, id);
    emit Mint(receiver, id);
  }

  /// @notice Mint new dyad to the NFT
  /// @param id The NFT id
  function mintDyad(uint id) payable external onlyNFTOwner(id) {
    IdNFT.Nft storage nft = idToNft[id];
    require(msg.value > 0, "You need to send some ETH to mint dyad");

    // mint dyad to the nft contract
    // approve the pool to spend the dyad
    // deposit minted dyad to the pool
    uint amount = pool.mintDyad{value: msg.value}();
    dyad.approve(address(pool), amount);
    pool.deposit(amount);

    // update nft
    nft.deposit = nft.deposit.add(amount);
  }

  /// @notice Withdraw dyad from the NFT to the msg.sender
  /// @param id The NFT id
  /// @param amount The amount of dyad to withdraw
  function withdraw(uint id, uint amount) external onlyNFTOwner(id) {
    IdNFT.Nft storage nft = idToNft[id];
    require(amount <= nft.deposit, "Not enough dyad in pool to withdraw");

    pool.withdraw(msg.sender, amount);

    // update nft
    nft.deposit = nft.deposit.sub(amount);
    nft.balance = nft.balance.add(amount);

    // update max value
    if (nft.balance > MAX_BALANCE) {
      MAX_BALANCE = nft.balance;
    }
  }

  /// @notice Deposit dyad in the pool
  /// @param id The NFT id
  /// @param amount The amount of dyad to deposit
  function deposit(uint id, uint amount) external onlyNFTOwner(id) {
    IdNFT.Nft storage nft = idToNft[id];
    require(amount <= nft.balance, "Not enough dyad in balance to deposit");

    // transfer dyad to the nft
    // approve the pool to spend the dyad of this contract
    // deposit dyad in the pool
    dyad.transferFrom(msg.sender, address(this), amount);
    dyad.approve(address(pool), amount);
    pool.deposit(amount);

    // update nft
    nft.deposit = nft.deposit.add(amount);
    nft.balance = nft.balance.sub(amount);

    // update max value
    if (nft.deposit > MAX_DEPOSIT) {
      MAX_DEPOSIT = nft.deposit;
    }
  }
}
