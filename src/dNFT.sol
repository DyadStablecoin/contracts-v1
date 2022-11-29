// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {DYAD} from "../src/dyad.sol";
import {Pool} from "../src/pool.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";

contract dNFT is ERC721Enumerable, ERC721Burnable {
  // maximum number of nfts that can be minted
  uint public MAX_SUPPLY = 300;

  uint public NUMBER_OF_NFT_MINTS;

  // to mint a dnft $ 5k in eth are required
  uint public DEPOSIT_MINIMUM = 5000000000000000000000;

  // here we store the maximum value over every dNFT,
  // which allows us to do a normalization, without iterating over
  // all of them to find the max value.
  // Why init to 900k? Because otherwise they are set to 0 and the 
  // normalization function in the `PoolLibrary` breaks and 900k is a nice number.
  uint public MIN_XP = 900000;
  // after minting the first nft this will be the MAX_XP. After that it will
  // be updated by the `sync` in the pool contract.
  uint public MAX_XP = MIN_XP + MAX_SUPPLY;

  DYAD public dyad;
  Pool public pool;

  // mapping from nft id to nft data
  mapping(uint => IdNFT.Nft) public idToNft;

  event NftMinted    (address indexed to, uint indexed id);
  event DyadMinted   (address indexed to, uint indexed id, uint amount);
  event DyadWithdrawn(address indexed to, uint indexed id, uint amount);
  event DyadDeposited(address indexed to, uint indexed id, uint amount);

  /// @dev Check if owner of NFT is msg.sender
  /// @param id The id of the NFT
  modifier onlyNFTOwner(uint id) {
    require(this.ownerOf(id) == msg.sender, "dNFT: Only callable by NFT owner");
    _;
  }

  /// @dev Check if caller is the pool
  modifier onlyPool() {
    require(address(pool) == msg.sender, "dNFT: Only callable by Pool contract");
    _;
  }

  constructor(address _dyad, bool withInsiderAllocation) ERC721("DYAD NFT", "dNFT") {
    dyad = DYAD(_dyad);

    if (withInsiderAllocation) {
      // spcecial mint for core-team/contributors/early-adopters/investors
      _mintNft(0x7EEfFd5D089b1351ecCC388022d8b823676dF424); // cryptohermetica
      _mintNft(0xCAD2EaDA97Ad393584Fe84A5cCA1ef3093E45ae4); // joeyroth.eth
      _mintNft(0x414b60745072088d013721b4a28a0559b1A9d213); // shafu.eth
      _mintNft(0x3682827F48F8E023EE40707dEe82620D0B63579f); // Max Entropy
      _mintNft(0xe779Fb090AF9dfBB3b4C18Ed571ad6390Df52ae2); // dma.eth
      _mintNft(0x9F919a292e62594f2D8db13F6A4ADB1691D6c60d); // kores
      _mintNft(0xF37ec513AF2CD91a76D386680fD2Df6ba3Bb7520); // e_z.eth
    }
  }

  function setPool(address newPool) public {
    // can only be set once, when launching the protocol
    require(address(pool) == address(0),"dNFT: Pool is already set");
    pool = Pool(newPool);
  }

  // The following functions are overrides required by Solidity.
  function _beforeTokenTransfer(address from,
                                address to,
                                uint256 tokenId,
                                uint256 batchSize)
      internal override(ERC721, ERC721Enumerable)
  { super._beforeTokenTransfer(from, to, tokenId, batchSize); }

  // The following functions are overrides required by Solidity.
  function supportsInterface(bytes4 interfaceId)
      public
      view
      override(ERC721, ERC721Enumerable)
      returns (bool)
  { return super.supportsInterface(interfaceId); }

  // we need to update the max xp value from the pool, that is why we need this
  function updateXP(uint minXP, uint maxXP) public onlyPool {
    if (minXP < MIN_XP) { MIN_XP = minXP; }
    if (maxXP > MAX_XP) { MAX_XP = maxXP; }
  }

  // the pool needs a function to update nft info
  function updateNft(uint id, IdNFT.Nft memory nft) external onlyPool {
    idToNft[id] = nft;
  }

  // VERY IMPORTANT: we add the pool here so we can burn any dnft. This is needed
  // to make the liquidation mechanism possible.
  function _isApprovedOrOwner(address spender,
                              uint256 tokenId) 
                              internal override view virtual returns (bool) {
    address owner = ERC721.ownerOf(tokenId);
    return (spender == address(pool) || // <- we add the pool
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

  // special function for the liquidation mechanism, where we have to mint a new
  // nft with a diffrent deposit minimum and where we transfer xp from the old
  // burned nft to the new one.
  function mintNftWithXp(address receiver,
                         uint xp,
                         uint depositMinimum) external payable onlyPool returns (uint) {
    uint id = _mintNft(receiver);
    idToNft[id].xp = xp;

    // mint the required dyad to cover the negative deposit
    _mintDyad(id, depositMinimum); 
    return id;
  }

  // the main reason for this method is that we need to be able to mint
  // nfts for the core team and investors without the deposit minimum,
  // this happens in the constructor where we call this method directly.
  // NOTE: this can only be called `MAX_SUPPLY` times
  function _mintNft(address receiver) public returns (uint) {
    uint id = NUMBER_OF_NFT_MINTS;
    require(id < MAX_SUPPLY, "Max supply reached");
    _mint(receiver, id); // nft mint

    IdNFT.Nft storage nft = idToNft[id];

    // add 900k xp to the nft to start with
    // We do MAX_SUPPLY - totalSupply() not to incentivice anything
    // but to break the xp symmetry.
    // +1 to start with a clean 900300
    nft.xp = nft.xp + (MIN_XP + (MAX_SUPPLY-totalSupply()+1));

    // the new nft.xp could potentially be a new xp minimum!
    if (nft.xp < MIN_XP) { MIN_XP = nft.xp; }

    emit NftMinted(receiver, id);

    NUMBER_OF_NFT_MINTS += 1;
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
    nft.deposit += int(amount);

    emit DyadMinted(msg.sender, id, amount);
  }

  /// @notice Withdraw dyad from the NFT to the msg.sender
  /// @param id The NFT id
  /// @param amount The amount of dyad to withdraw
  function withdraw(uint id, uint amount) external onlyNFTOwner(id) {
    IdNFT.Nft storage nft = idToNft[id];
    // The amount you want to withdraw is higher than the amount you have
    // deposited
    require(int(amount) <= nft.deposit, "dNFT: Withdraw amount exceeds deposit");

    pool.withdraw(msg.sender, amount);

    // update nft
    nft.deposit   -= int(amount);
    nft.withdrawn += amount;

    emit DyadWithdrawn(msg.sender, id, amount);
  }

  /// @notice Deposit dyad back in the pool
  /// @param id The NFT id
  /// @param amount The amount of dyad to deposit
  function deposit(uint id, uint amount) external onlyNFTOwner(id) {
    IdNFT.Nft storage nft = idToNft[id];
    // The amount you want to deposit is higher than the amount you have 
    // withdrawn
    require(amount <= nft.withdrawn, "dNFT: Deposit exceeds withdrawn");

    // transfer dyad to the nft
    // approve the pool to spend the dyad of this contract
    // deposit dyad in the pool
    dyad.transferFrom(msg.sender, address(this), amount);
    dyad.approve(address(pool), amount);
    pool.deposit(amount);

    // update nft
    nft.deposit   += int(amount);
    nft.withdrawn -= amount;

    emit DyadDeposited(msg.sender, id, amount);
  }
}
