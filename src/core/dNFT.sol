// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {DYAD} from "./Dyad.sol";
import {Pool} from "./Pool.sol";

struct Nft {
  uint withdrawn; // dyad withdrawn from the pool deposit
  int deposit;    // dyad balance in pool
  uint xp;        // always positive, always inflationary
  bool isLiquidatable;
}

contract dNFT is ERC721Enumerable, ERC721Burnable {
  // maximum number of nfts that can exist at one point in time
  uint public MAX_SUPPLY;

  // 150% in basis points
  uint constant public MIN_COLLATERATION_RATIO = 15000; 

  // stores the number of nfts that have been minted. we need this in order to
  // generate a new id for the next minted nft.
  uint public numberOfMints;

  // deposit minimum required to mint a new dnft
  // should be a constant, but then some of the tests do not work because they 
  // depend on manipulating this value.
  // as this is only set in the constructor, it should not be a problem.
  uint public DEPOSIT_MINIMUM;

  DYAD public dyad;
  Pool public pool;

  // mapping from nft id to nft 
  mapping(uint => Nft) public idToNft;

  event NftMinted    (address indexed to, uint indexed id);
  event DyadMinted   (address indexed to, uint indexed id, uint amount);
  event DyadWithdrawn(address indexed to, uint indexed id, uint amount);
  event DyadDeposited(address indexed to, uint indexed id, uint amount);
  event DyadRedeemed (address indexed to, uint indexed id, uint amount);

  modifier onlyNFTOwner(uint id) {
    require(this.ownerOf(id) == msg.sender, "dNFT: Only callable by NFT owner");
    _;
  }
  modifier onlyPool() {
    require(address(pool) == msg.sender, "dNFT: Only callable by Pool contract");
    _;
  }
  // Require CR >= `MIN_COLLATERATION_RATIO`, after removing `amount`
  modifier overCR(uint amount) {
    uint cr              = MIN_COLLATERATION_RATIO;
    uint updatedBalance  = dyad.balanceOf(address(pool)) - amount;
    uint totalWithdrawn  = dyad.totalSupply() - updatedBalance;
    if (totalWithdrawn != 0) { cr =  updatedBalance*10000 / totalWithdrawn; }     
    require(cr >= MIN_COLLATERATION_RATIO, "CR is under 150%"); 
    _;
  }

  constructor(address _dyad,
              uint    _depositMinimum,
              uint    _maxSupply, 
              address[] memory insiders) ERC721("DYAD NFT", "dNFT") {
    dyad            = DYAD(_dyad);
    DEPOSIT_MINIMUM = _depositMinimum;
    MAX_SUPPLY      = _maxSupply;
    for (uint i = 0; i < insiders.length; i++) { _mintNft(insiders[i]); }
  }

  // Set pool once
  function setPool(address newPool) public {
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

  function updateNft(uint id, Nft memory nft) external onlyPool {
    idToNft[id] = nft;
  }

  // VERY IMPORTANT: we add the pool here so we can burn any dnft. 
  // This is needed to make the liquidation mechanism work.
  function _isApprovedOrOwner(address spender,
                              uint256 tokenId) 
                              internal override view virtual returns (bool) {
    address owner = ERC721.ownerOf(tokenId);
    return (spender == address(pool) || // <- only change
            spender == owner ||
            isApprovedForAll(owner, spender) ||
            getApproved(tokenId) == spender);
  }

  // Mint new dNFT to `to` with a deposit of atleast `DEPOSIT_MINIMUM`
  function mintNft(address to) external payable returns (uint) {
    uint id = _mintNft(to);
    _mintDyad(id, DEPOSIT_MINIMUM);
    uint xp = idToNft[id].xp;
    if (xp < pool.MIN_XP()) { pool.setMinXp(xp); } // could be new global xp min
    return id;
  }

  // Mint new nft to `to` with the same xp and withdrawn amount as `nft`
  function mintCopy(
      address to,
      Nft memory nft
  ) external payable onlyPool returns (uint) {
      uint id = _mintNft(to);
      Nft storage newNft = idToNft[id];
      uint minDeposit = 0;
      if (nft.deposit < 0) { minDeposit = uint(-nft.deposit); }
      uint amount = _mintDyad(id, minDeposit);
      newNft.deposit   = int(amount) + nft.deposit;
      newNft.xp        = nft.xp;
      newNft.withdrawn = nft.withdrawn;
      return id;
  }

  // Mint new dNFT to `to`
  function _mintNft(address to) private returns (uint id) {
    require(totalSupply() < MAX_SUPPLY, "Max supply reached");
    id = numberOfMints;
    numberOfMints += 1;
    _mint(to, id); 
    Nft storage nft = idToNft[id];
    nft.xp = (MAX_SUPPLY*2) - (totalSupply()-1); // break xp symmetry
    emit NftMinted(to, id);
  }

  // Mint new DYAD 
  function mintDyad(uint id) payable public onlyNFTOwner(id) returns (uint amount) {
      amount = _mintDyad(id, 0);
  }

  // Mint at least `minAmount` of DYAD to dNFT 
  function _mintDyad(
      uint id,
      uint minAmount
  ) private returns (uint amount) {
      require(msg.value > 0, "dNFT: ETH required to mint DYAD");
      amount = pool.mintDyad{value: msg.value}(minAmount);
      dyad.approve(address(pool), amount);
      pool.deposit(amount);
      idToNft[id].deposit += int(amount);
      emit DyadMinted(msg.sender, id, amount);
  }

  // Withdraw `amount` of DYAD from the dNFT
  function withdraw(
      uint id,
      uint amount
  ) external onlyNFTOwner(id) overCR(amount) returns (uint) {
      require(amount > 0, "dNFT: Withdrawl must be greater than 0");
      Nft storage nft = idToNft[id];
      require(int(amount) <= nft.deposit, "dNFT: Withdraw amount exceeds deposit");
      uint tvl          = dyad.balanceOf(address(pool));
      uint newWithdrawn = nft.withdrawn + amount;
      require(newWithdrawn <= tvl / totalSupply());
      nft.withdrawn  = newWithdrawn;
      nft.deposit   -= int(amount);
      pool.withdraw(msg.sender, amount);
      emit DyadWithdrawn(msg.sender, id, amount);
      return amount;
  }

  // Deposit `amount` of DYAD into the dNFT
  function deposit(
      uint id, 
      uint amount
  ) external returns (uint) {
      require(amount > 0, "dNFT: Deposit must be greater than 0");
      Nft storage nft = idToNft[id];
      require(amount <= nft.withdrawn, "dNFT: Deposit amount exceeds withdrawls");
      nft.deposit   += int(amount);
      nft.withdrawn -= amount;
      dyad.transferFrom(msg.sender, address(this), amount);
      dyad.approve(address(pool), amount);
      pool.deposit(amount);
      emit DyadDeposited(msg.sender, id, amount);
      return amount;
  }

  // Redeem `amount` of DYAD for ETH from the dNFT
  function redeem(
      uint id,
      uint amount
  ) external onlyNFTOwner(id) returns (uint usdInEth) {
      require(amount > 0, "dNFT: Amount to redeem must be greater than 0");
      Nft storage nft = idToNft[id];
      require(amount <= nft.withdrawn, "dNFT: Amount to redeem exceeds withdrawn");
      nft.withdrawn -= amount;
      dyad.transferFrom(msg.sender, address(pool), amount);
      usdInEth = pool.redeem(msg.sender, amount);
      emit DyadRedeemed(msg.sender, id, amount);
      return usdInEth;
  }

  // Move `amount` `from` one dNFT deposit `to` another dNFT deposit
  function moveDeposit(
      uint _from,
      uint _to,
      uint amount
  ) external onlyNFTOwner(_from) returns (uint) {
      require(amount > 0, "dNFT: Amount to move must be greater than 0");
      Nft storage from = idToNft[_from];
      require(int(amount) <= from.deposit, "dNFT: Amount to move exceeds deposit");
      Nft storage to   = idToNft[_to];
      from.deposit    -= int(amount);
      to.deposit      += int(amount);
      return amount;
  }
}
