// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {DYAD} from "../src/dyad.sol";
import {Pool} from "../src/pool.sol";

contract dNFT is ERC721Enumerable{
  using SafeMath for uint256;

  // maximum number of nfts that can exist at any moment
  uint public constant MAX_SUPPLY = 1000;

  address public owner;
  DYAD public dyad;
  Pool public pool;

  mapping (uint => address) public idToOwner;
  mapping (uint => uint) public xp;
  mapping (uint => uint) public dyadMinted;
  mapping (uint => int) public virtualDyadBalance;
  mapping (uint => uint) public dyadInPool;
  mapping (uint => uint) public lastCheckpointForId;

  event Mint(address indexed to, uint indexed id);

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
    xp[id] = xp[id].add(100);
    _mint(receiver, id);
    emit Mint(receiver, id);
  }

  /// @dev Check if owner of NFT is msg.sender
  /// @param id The id of the NFT
  modifier onlyNFTOwner(uint id) {
    require(idToOwner[id] == msg.sender, "Only NFT owner can call this function");
    _;
  }

  function sync(uint id) external onlyNFTOwner(id) {
    uint lastCheckpoint   = lastCheckpointForId[id];  // last checkpoint for this nft
    uint latestCheckpoint = pool.lastCheckpoint(); // latest checkpoint in pool

    // iterate over all checkpoints that were missed
    for (uint i = lastCheckpoint; i < latestCheckpoint; i++) {
      int dyadDelta   = pool.dyadDeltaAtCheckpoint(i);
      int poolBalance = int(pool.poolBalanceAtCheckpoint(i));

      int virtualDelta = virtualDyadBalance[id] * dyadDelta / poolBalance;

      xp[id]                 += 0;
      virtualDyadBalance[id] += virtualDelta; // TODO: weighted by xp
    }

    // TODO: send some reward to msg.sender
  }

  /// @notice Mint new dyad to the NFT
  /// @param id The NFT id
  function mintDyad(uint id) payable external onlyNFTOwner(id) {
    uint amount = pool.mintDyad{value: msg.value}();
    dyadInPool[id] = dyadInPool[id].add(amount);
    dyadMinted[id] += dyadMinted[id].add(amount);
    dyad.approve(address(pool), amount);
    pool.deposit(amount);
  }

  /// @notice Deposit dyad in the NFT
  /// @param id The NFT id
  /// @param amount The amount of dyad to deposit
  function deposit(uint id, uint amount) external onlyNFTOwner(id) {
    dyad.transferFrom(msg.sender, address(this), amount);
    dyadInPool[id] = dyadInPool[id].add(amount);
    dyad.approve(address(pool), amount);
    pool.deposit(amount);
  }

  /// @notice Withdraw dyad from the NFT to the msg.sender
  /// @param id The NFT id
  /// @param amount The amount of dyad to withdraw
  function withdraw(uint id, uint amount) external onlyNFTOwner(id) {
    dyadInPool[id] = dyadInPool[id].sub(amount);
    pool.withdraw(msg.sender, amount);
  }
}
