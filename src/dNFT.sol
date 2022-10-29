// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../src/dyad.sol";
import "../src/pool.sol";
import "forge-std/console.sol";

contract dNFT is ERC721Enumerable{
  // maximum number of nfts that can exist at any moment
  uint public constant MAX_SUPPLY = 1000;

  address public owner;
  DYAD public dyad;
  Pool public pool;

  mapping (uint => address) public idToOwner;
  mapping (uint => uint) public xp;
  mapping (uint => uint) public dyadMinted;
  mapping (uint => uint) public dyadInPool;

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
  function mint(address receiver) external {
    uint id = totalSupply();
    require(id < MAX_SUPPLY, "Max supply reached");
    idToOwner[id] = receiver;
    xp[id] += 100;
    _mint(receiver, id);
    emit Mint(receiver, id);
  }

  /// @dev Check if owner of NFT is msg.sender
  /// @param id The id of the NFT
  modifier onlyNFTOwner(uint id) {
    require(idToOwner[id] == msg.sender, "Only NFT owner can call this function");
    _;
  }

  /// @notice Mint new dyad to the NFT
  /// @param id The NFT id
  function mintDyad(uint id) payable external onlyNFTOwner(id) {
    uint amount = pool.mintDyad{value: msg.value}();
    dyadInPool[id] += amount;
    dyadMinted[id] += amount;
    dyad.approve(address(pool), amount);
    pool.deposit(amount);
  }

  /// @notice Deposit dyad in the NFT
  /// @param id The NFT id
  /// @param amount The amount of dyad to deposit
  function deposit(uint id, uint amount) external onlyNFTOwner(id) {
    dyadInPool[id] += amount;
    dyad.approve(address(pool), amount);
    pool.deposit(amount);
  }

  /// @notice Withdraw dyad from the NFT
  /// @param id The NFT id
  /// @param amount The amount of dyad to withdraw
  function withdraw(uint id, uint amount) external onlyNFTOwner(id) {
    dyadInPool[id] -= amount;
    dyad.withdraw(amount, msg.sender)
  }
}
