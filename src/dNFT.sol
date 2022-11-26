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

  // maximum number of nfts that can be minted
  uint public MAX_SUPPLY = 300;

  // to mint a dnft $ 5k in eth are required
  uint public DEPOSIT_MINIMUM = 5000000000000000000000;

  // here we store the maximum value over every dNFT,
  // which allows us to do a normalization, without iterating over
  // all of them to find the max value.
  // Why init to 100? Because otherwise they are set to 0 and the 
  // normalization function in the `PoolLibrary` breaks. We always
  // need to make sure that these values are not smaller than 100.
  uint public MIN_XP      = 100;
  uint public MAX_XP      = 100;

  // the only ability the deployer has is to set the pool once.
  // once it is set it is impossible to change it.
  address public deployer;
  bool private isPoolSet = false;

  DYAD public dyad;
  Pool public pool;

  // mapping from nft id to nft data
  mapping(uint => IdNFT.Nft) public idToNft;

  event NftMinted(address indexed to, uint indexed id);
  event MintDyad (address indexed to, uint indexed id, uint amount);
  event Withdraw (address indexed to, uint indexed id, uint amount);
  event Deposit  (address indexed to, uint indexed id, uint amount);

  /// @dev Check if owner of NFT is msg.sender
  /// @param id The id of the NFT
  modifier onlyNFTOwner(uint id) {
    require(this.ownerOf(id) == msg.sender, "dNFT: Only NFT owner can call this function");
    _;
  }

  /// @dev Check if caller is the pool
  modifier onlyPool() {
    require(address(pool) == msg.sender, "dNFT: Only Pool can call this function");
    _;
  }

  /// @dev Check if caller is the owner
  modifier onlyDeployer() {
    require(deployer == msg.sender, "dNFT: Only deployer can call this function");
    _;
  }

  constructor(address _dyad, bool withInsiderAllocation) ERC721("DYAD NFT", "dNFT") {
    deployer = msg.sender;
    dyad     = DYAD(_dyad);

    if (withInsiderAllocation) {
      // spcecial mint for core-team/contributors/early-adopters/investors
      _mintNft(0x659264De58A00Ca9304aFCA079D8bEf6132BA16f);
      _mintNft(0x659264De58A00Ca9304aFCA079D8bEf6132BA16f);
      _mintNft(0x659264De58A00Ca9304aFCA079D8bEf6132BA16f);
    }
  }

  function setPool(address newPool) external onlyDeployer {
    require(!isPoolSet,             "dNFT: Pool is already set");
    pool = Pool(newPool);
    isPoolSet = true;
  }

  // we need to update the max xp value from the pool, that is why we need this
  function updateXP(uint minXP, uint maxXP) external onlyPool {
    if (minXP < MAX_XP) { MIN_XP = minXP; }
    if (maxXP > MAX_XP) { MAX_XP = maxXP; }
  }

  // the pool needs a function to update nft info
  function updateNft(uint id, IdNFT.Nft memory nft) external onlyPool {
    idToNft[id] = nft;
  }

  // IMPORTANT: we extend this to by the ability of the pool contract to transfer any nft
  // this is needed to make the liquidation mechanism possible
  function _isApprovedOrOwner(address spender, uint256 tokenId) internal override view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
        return (spender == address(pool) || // <- this is the only change
                spender == owner ||
                isApprovedForAll(owner, spender) ||
                getApproved(tokenId) == spender);
    }

  // mint a new nft to the `receiver`
  // to mint a new nft a minimum of $`DEPOSIT_MINIMUM` in eth is required
  function mintNft(address receiver) external payable returns (uint) {
    uint id = _mintNft(receiver);
    _mintDyad(id, DEPOSIT_MINIMUM);
    return id;
  }

  // the main reason for this method is that we need to be able to mint
  // nfts for the core team and investors without the deposit minimum,
  // this happens in the constructor where we call this method directly.
  function _mintNft(address receiver) private returns (uint) {
    uint id = totalSupply();
    require(id < MAX_SUPPLY, "Max supply reached");
    _mint(receiver, id); // nft mint

    IdNFT.Nft storage nft = idToNft[id];

    // add 900k xp to the nft to start with
    nft.xp = nft.xp.add(900000);

    if (nft.xp > MAX_XP) { MAX_XP = nft.xp; }

    emit NftMinted(receiver, id);
    return id;
  }

  // mint new dyad to the respective nft
  function mintDyad(uint id) payable public onlyNFTOwner(id) {
    _mintDyad(id, 0);
  }

  // this method is needed, because of the required deposit minimum
  // when minting new nfts.
  // this deposit minimum is not required though when calling `mintDyad`
  // through the respective nft.
  // therfore `minAmount` is set to 0 in the `mintDyad` method and to 
  // `DEPOSIT_MINIMUM` in the `mintNft` method.
  function _mintDyad(uint id, uint minAmount) private {
    require(msg.value > 0, "You need to send some ETH to mint dyad");

    // mint new dyad and deposit it in the pool 
    uint amount = pool.mintDyad{value: msg.value}(minAmount);
    dyad.approve(address(pool), amount);
    pool.deposit(amount);

    IdNFT.Nft storage nft = idToNft[id];
    // give msg.sender ownership of the dyad
    nft.deposit = nft.deposit.add(amount);

    emit MintDyad(msg.sender, id, amount);
  }

  /// @notice Withdraw dyad from the NFT to the msg.sender
  /// @param id The NFT id
  /// @param amount The amount of dyad to withdraw
  function withdraw(uint id, uint amount) external onlyNFTOwner(id) {
    IdNFT.Nft storage nft = idToNft[id];
    require(amount <= nft.deposit, "Not enough dyad in pool to withdraw");

    pool.withdraw(msg.sender, amount);

    // update nft
    nft.deposit   = nft.deposit.sub(amount);
    nft.withdrawn = nft.withdrawn.add(amount);

    emit Withdraw(msg.sender, id, amount);
  }

  /// @notice Deposit dyad back in the pool
  /// @param id The NFT id
  /// @param amount The amount of dyad to deposit
  function deposit(uint id, uint amount) external onlyNFTOwner(id) {
    IdNFT.Nft storage nft = idToNft[id];

    // transfer dyad to the nft
    // approve the pool to spend the dyad of this contract
    // deposit dyad in the pool
    dyad.transferFrom(msg.sender, address(this), amount);
    dyad.approve(address(pool), amount);
    pool.deposit(amount);

    // update nft
    nft.deposit   = nft.deposit.add(amount);
    nft.withdrawn = nft.withdrawn.sub(amount);

    emit Deposit(msg.sender, id, amount);
  }
}
