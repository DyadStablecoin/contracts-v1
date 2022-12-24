// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {IAggregatorV3} from "../interfaces/AggregatorV3Interface.sol";
import {DYAD} from "./Dyad.sol";
import {Pool} from "./Pool.sol";
import {PoolLibrary} from "../libraries/PoolLibrary.sol";

struct Nft {
  uint withdrawn; // dyad withdrawn from the pool deposit
  int deposit;    // dyad balance in pool
  uint xp;        // always positive, always inflationary
  bool isLiquidatable;
}

// Convenient way to store the ouptput of the `calcMulti` function
struct Multi {
  uint product;
  uint xp;
}

// Convenient way to store the ouptput of the `calcMultis` function
struct Multis {
  uint[] products;
  uint   productsSum; // sum of the elements in `productsSum`
  uint[] xps;         
}

contract dNFT is ERC721Enumerable, ERC721Burnable {
  // 150% in basis points
  uint public MIN_COLLATERATION_RATIO = 15000; 

  // Minimum required to mint a new dNFT
  uint public DEPOSIT_MINIMUM;

  // Maximum number of dNFTs that can exist simultaneously
  uint public MAX_SUPPLY;

  // ETH price from the last sync call
  uint public lastEthPrice;

  // Number of dNFTs minted so far
  uint public numberOfMints;

  // Min/Max XP over all dNFTs
  uint public minXp; uint public maxXp;

  // dNFT id => dNFT
  mapping(uint => Nft) public idToNft;

  DYAD public dyad;
  Pool public pool;
  IAggregatorV3 internal oracle;

  // Protocol can be in two modes:
  // - BURNING: Price of ETH went down
  // - MINTING: Price of ETH went up
  enum Mode{ BURNING, MINTING }

  event NftMinted    (address indexed to, uint indexed id);
  event DyadMinted   (address indexed to, uint indexed id, uint amount);
  event DyadWithdrawn(address indexed to, uint indexed id, uint amount);
  event DyadDeposited(address indexed to, uint indexed id, uint amount);
  event DyadRedeemed (address indexed to, uint indexed id, uint amount);
  event Synced       (uint newEthPrice);
  event NftClaimed   (uint indexed id, address indexed from, address indexed to);

  modifier onlyNFTOwner(uint id) {
    require(this.ownerOf(id) == msg.sender, "dNFT: Only callable by NFT owner");
    _;
  }

  constructor(
    address          _dyad,
    uint             _depositMinimum,
    uint             _maxSupply, 
    address          _oracle, 
    address[] memory _insiders
  ) ERC721("DYAD NFT", "dNFT") {
    dyad            = DYAD(_dyad);
    oracle          = IAggregatorV3(_oracle);
    lastEthPrice    = uint(getNewEthPrice());
    DEPOSIT_MINIMUM = _depositMinimum;
    MAX_SUPPLY      = _maxSupply;
    minXp           = _maxSupply;
    maxXp           = _maxSupply * 2;

    for (uint i = 0; i < _insiders.length; i++) { _mintNft(_insiders[i]); }
  }

  function getNewEthPrice() internal view returns (int newEthPrice) {
    ( , newEthPrice, , , ) = oracle.latestRoundData();
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

  // Mint new dNFT to `to` with a deposit of atleast `DEPOSIT_MINIMUM`
  function mintNft(address to) external payable returns (uint) {
    uint id = _mintNft(to);
    _mintDyad(id, DEPOSIT_MINIMUM);
    uint xp = idToNft[id].xp;
    if (xp < minXp) { minXp = xp; } // could be new global xp min
    return id;
  }

  // Mint new nft to `to` with the same xp and withdrawn amount as `nft`
  function _mintCopy(
      address to,
      Nft memory nft
  ) internal returns (uint) { 
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

  // Mint and deposit DYAD into dNFT
  function mintDyad(uint id) payable public onlyNFTOwner(id) returns (uint amount) {
      amount = _mintDyad(id, 0);
  }

  // Mint at least `minAmount` of DYAD to dNFT 
  function _mintDyad(
      uint id,
      uint minAmount
  ) private returns (uint) {
      require(msg.value > 0, "dNFT: msg.value == 0");
      uint newDyad = uint(getNewEthPrice()) * msg.value/100000000;
      require(newDyad >= minAmount, "Pool: newDyad < minAmount");
      dyad.mint(address(this), newDyad);
      idToNft[id].deposit += int(newDyad);
      emit DyadMinted(msg.sender, id, newDyad);
      return newDyad;
  }

  // Withdraw `amount` of DYAD from dNFT
  function withdraw(
      uint id,
      uint amount
  ) external onlyNFTOwner(id) returns (uint) {
      require(amount > 0,                    "dNFT: Withdrawl == 0");
      Nft storage nft = idToNft[id];
      require(int(amount)  <= nft.deposit,   "dNFT: Withdrawl > deposit");
      uint updatedBalance  = dyad.balanceOf(address(this)) - amount;
      uint totalWithdrawn  = dyad.totalSupply() - updatedBalance;
      uint cr =  updatedBalance*10000 / totalWithdrawn;      
      require(cr >= MIN_COLLATERATION_RATIO, "dNFT: CR is under 150%"); 
      uint newWithdrawn = nft.withdrawn + amount;
      uint averageTVL   = dyad.balanceOf(address(this)) / totalSupply();
      require(newWithdrawn <= averageTVL,    "dNFT: New Withdrawl > average TVL");
      nft.withdrawn  = newWithdrawn;
      nft.deposit   -= int(amount);
      dyad.transfer(msg.sender, amount);
      emit DyadWithdrawn(msg.sender, id, amount);
      return amount;
  }

  // Deposit `amount` of DYAD into dNFT
  function deposit(
      uint id, 
      uint amount
  ) external returns (uint) {
      require(amount > 0, "dNFT: Deposit == 0");
      Nft storage nft = idToNft[id];
      require(amount <= nft.withdrawn, "dNFT: Deposit > withdrawn");
      nft.deposit   += int(amount);
      nft.withdrawn -= amount;
      dyad.transferFrom(msg.sender, address(this), amount);
      emit DyadDeposited(msg.sender, id, amount);
      return amount;
  }

  // Redeem `amount` of DYAD for ETH from dNFT
  function redeem(
      uint id,
      uint amount
  ) external onlyNFTOwner(id) returns (uint usdInEth) {
      require(amount > 0, "dNFT: Amount to redeem == 0");
      Nft storage nft = idToNft[id];
      require(amount <= nft.withdrawn, "dNFT: Amount to redeem > withdrawn");
      nft.withdrawn -= amount;
      dyad.burn(amount);
      uint eth = amount*100000000 / lastEthPrice;
      payable(msg.sender).transfer(eth);
      emit DyadRedeemed(msg.sender, id, amount);
      return usdInEth;
  }

  // Move `amount` `from` one dNFT deposit `to` another dNFT deposit
  function moveDeposit(
      uint _from,
      uint _to,
      uint amount
  ) external onlyNFTOwner(_from) returns (uint) {
      require(amount > 0, "dNFT: Deposit == 0");
      Nft storage from = idToNft[_from];
      require(int(amount) <= from.deposit, "dNFT: Amount to move > deposit");
      Nft storage to   = idToNft[_to];
      from.deposit    -= int(amount);
      to.deposit      += int(amount);
      return amount;
  }

  // Liquidate dNFT by burning it and minting a new copy to `to`
  function liquidate(
      uint id,
      address to
  ) external payable returns (uint) {
      Nft memory nft = idToNft[id];
      require(nft.isLiquidatable, "dNFT: NFT is not liquidatable");
      emit NftClaimed(id, ownerOf(id), to); 
      _burn(id); 
      return _mintCopy(to, nft);
  }

  // Sync DYAD by minting/burning it and updating the metadata of each dNFT
  function sync() public returns (uint) { return sync(type(uint256).max); }

  // Sync DYAD. dNFT with `id` gets a boost
  function sync(uint id) public returns (uint) {
    uint newEthPrice = uint(getNewEthPrice());
    // determine the mode we are in
    Mode mode = newEthPrice > lastEthPrice ? Mode.MINTING 
                                           : Mode.BURNING;
 
    // stores the eth price change in basis points
    uint ethChange = newEthPrice*10000/lastEthPrice;
    // we have to do this to get the percentage in basis points
    mode == Mode.BURNING ? ethChange  = 10000 - ethChange 
                         : ethChange -= 10000;

    // the amount of dyad to burn/mint
    uint dyadDelta = updateNFTs(ethChange, mode, id);

    mode == Mode.MINTING ? dyad.mint(address(this), dyadDelta) 
                         : dyad.burn(dyadDelta);

    lastEthPrice = newEthPrice;
    emit Synced(newEthPrice);
    return dyadDelta;
  }

  function updateNFTs(
      uint ethChange,
      Mode mode,
      uint id
  ) private returns (uint) {
      // the amount to mint/burn to keep the peg
      uint dyadDelta = PoolLibrary.percentageOf(dyad.totalSupply(), ethChange);

      Multis memory multis = calcMultis(mode, id);

      // we use these to keep track of the max/min xp values for this sync, 
      // so we can save them in storage to be used in the next sync.
      uint _minXp = type(uint256).max;
      uint _maxXp = maxXp;

      uint totalSupply = totalSupply();
      for (uint i = 0; i < totalSupply; i++) {
        uint tokenId = tokenByIndex(i);
        // multi normalized by the multi sum
        uint relativeMulti = multis.products[i]*10000 / multis.productsSum;
        // relative dyad delta for each nft
        uint relativeDyadDelta = PoolLibrary.percentageOf(dyadDelta, relativeMulti);

        Nft memory nft = idToNft[tokenId];

        // xp accrual happens only when there is a burn.
        uint xpAccrual;
        // there can only be xp accrual if deposit is not 0 
        if (mode == Mode.BURNING && nft.deposit > 0) {
          // normal accrual
          xpAccrual = relativeDyadDelta*100 / (multis.xps[i]);
          // boost for the address calling this function
          if (id == tokenId) { xpAccrual *= 2; }
        }

        // update memory nft data
        if (mode == Mode.BURNING) {
          nft.deposit -= int(relativeDyadDelta);
          nft.xp      += xpAccrual/(10**18); // normalize by the dyad decimals
        } else {
          // NOTE: there is no xp accrual in Mode.MINTING
          nft.deposit += int(relativeDyadDelta);
        }

        nft.deposit < 0 ? nft.isLiquidatable = true 
                        : nft.isLiquidatable = false;

        idToNft[tokenId] = nft;

        // check if this is a new xp minimum/maximum for this sync
        if (nft.xp < _minXp) { _minXp = nft.xp; }
        if (nft.xp > _maxXp) { _maxXp = nft.xp; }
      }

      // save new min/max xp in storage
      minXp = _minXp;
      maxXp = _maxXp;

      return dyadDelta;
  }

  function calcMultis(
      Mode mode,
      uint id
  ) private view returns (Multis memory) {
      uint nftTotalSupply = totalSupply();
      uint productsSum;
      uint[] memory products = new uint[](nftTotalSupply);
      uint[] memory xps      = new uint[](nftTotalSupply);

      for (uint i = 0; i < nftTotalSupply; i++) {
        Nft memory nft     = idToNft[tokenByIndex(i)];
        Multi memory multi = calcMulti(mode, nft);

        if (mode == Mode.MINTING && id == tokenByIndex(i)) { 
          multi.product += PoolLibrary.percentageOf(multi.product, 115); 
        }

        products[i]  = multi.product;
        productsSum += multi.product;
        xps[i]       = multi.xp;
      }

      // so we avoid dividing by 0 in `sync`
      if (productsSum == 0) { productsSum = 1; }

      return Multis(products, productsSum, xps);
  }

  function calcMulti(Mode mode, Nft memory nft) private view returns (Multi memory) {
    uint multiProduct; uint xpMulti;     

    if (nft.deposit > 0) {
      uint xpDelta =  maxXp - minXp;
      if (xpDelta == 0) { xpDelta = 1; } // avoid division by 0
      uint xpScaled = ((nft.xp-minXp)*10000) / xpDelta;
      uint mintAvgMinted = ((nft.withdrawn+uint(nft.deposit))*10000) / (dyad.totalSupply()/(totalSupply()+1));
      if (mode == Mode.BURNING && mintAvgMinted > 20000) { mintAvgMinted = 20000; } // limit to 200%
      xpMulti = PoolLibrary.getXpMulti(xpScaled/100);
      if (mode == Mode.BURNING) { xpMulti = 300-xpMulti; } // should be 292: 242+50
      uint depositMulti = (uint(nft.deposit)*10000) / (uint(nft.deposit)+(nft.withdrawn+1));
      multiProduct = xpMulti * (mode == Mode.BURNING ? mintAvgMinted : depositMulti) / 100;
    }

    return Multi(multiProduct, xpMulti);
  }
}
