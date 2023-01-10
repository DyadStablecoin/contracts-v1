// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";

import {IAggregatorV3} from "../interfaces/AggregatorV3Interface.sol";
import {DYAD} from "./Dyad.sol";

contract dNFT is ERC721Enumerable, ReentrancyGuard {
  using SafeCast   for int256;
  using SafeCast   for uint256;
  using SignedMath for int256;

  uint public immutable DEPOSIT_MINIMUM;           // Min DYAD required to mint a new dNFT
  uint public immutable MAX_SUPPLY;                // Max number of dNFTs that can exist simultaneously
  uint public immutable BLOCKS_BETWEEN_SYNCS;      // Min number of blocks required between sync calls
  uint public immutable MIN_COLLATERIZATION_RATIO; // Min CR required to withdraw DYAD
  uint public immutable MAX_MINTED_BY_TVL;         // Max % of DYAD that can be minted by TVL 

  uint public lastEthPrice;                        // ETH price from the last sync call
  uint public lastSyncedBlock;                     // Last block sync was called on
  uint public minXp;                               // Min XP over all dNFTs
  uint public maxXp;                               // Max XP over all dNFTs

  mapping(uint => Nft)  public idToNft;                  // dNFT id => dNFT
  mapping(uint => uint) private _idToBlockOfLastDeposit; // dNFT id => Block deposit was called on

  struct Nft {
    uint withdrawn;      // dyad withdrawn from the pool 
    int  deposit;        // dyad balance in pool
    uint xp;             // always positive, always inflationary
    bool isLiquidatable; // if true, anyone can liquidate the dNFT
  }

  // Convenient way to store output of internal `calcMulti` functions
  struct Multi  { uint   product ; uint xp; }
  struct Multis { uint[] products; uint productsSum; uint[] xps; }

  bytes private constant XP_TO_MULTI = hex"333333333435353637393a3c3f42454a4f555c636c76808b96a0abb5bfc8cfd6dce1e6e9eceff1f2";

  DYAD public dyad;
  IAggregatorV3 internal oracle;

  enum Mode { 
    BURNING, // Price of ETH went down
    MINTING  // Price of ETH went up
  }

  event NftMinted    (address indexed to, uint indexed id);
  event DyadMinted   (address indexed to, uint indexed id, uint amount);
  event DyadWithdrawn(address indexed to, uint indexed id, uint amount);
  event DyadDeposited(address indexed to, uint indexed id, uint amount);
  event DyadRedeemed (address indexed to, uint indexed id, uint amount);
  event DyadMoved    (uint    indexed from, uint    indexed to, uint amount);
  event NftLiquidated(address indexed from, address indexed to, uint indexed id);
  event Synced       (uint id);

  error ReachedMaxSupply       ();
  error NoEthSupplied          ();
  error SyncedTooRecently      ();
  error ExceedsAverageTVL      ();
  error NotNFTOwner            (uint id);
  error NotLiquidatable        (uint id);
  error CrTooLow               (uint cr);
  error AmountZero             (uint amount);
  error NotReachedMinAmount    (uint amount);
  error ExceedsWithdrawalLimit (uint amount);
  error ExceedsDepositLimit    (uint amount);
  error AddressZero            (address addr);
  error FailedDyadTransfer     (address to, uint amount);
  error FailedEthTransfer      (address to, uint amount);
  error CannotMoveDepositToSelf(uint from, uint to, uint amount);
  error MinXpHigherThanMaxXp   (uint minXp, uint maxXp);
  error CannotDepositAndWithdrawInSameBlock();

  modifier onlyNFTOwner(uint id) {
    if (ownerOf(id) != msg.sender) revert NotNFTOwner(id); _;
  }
  modifier amountNotZero(uint amount) {
    if (amount == 0) revert AmountZero(amount); _;
  }
  modifier addressNotZero(address addr) {
    if (addr == address(0)) revert AddressZero(addr); _;
  }

  constructor(
    address          _dyad,
    uint             _depositMinimum,
    uint             _maxSupply, 
    uint             _blocksBetweenSyncs,
    uint             _minCollaterizationRatio,
    uint             _maxMintedByTVL,
    address          _oracle, 
    address[] memory _insiders
  ) ERC721("DYAD NFT", "dNFT") {
    dyad                      = DYAD(_dyad);
    oracle                    = IAggregatorV3(_oracle);
    lastEthPrice              = _getLatestEthPrice();
    DEPOSIT_MINIMUM           = _depositMinimum;
    MAX_SUPPLY                = _maxSupply;
    BLOCKS_BETWEEN_SYNCS      = _blocksBetweenSyncs;
    MIN_COLLATERIZATION_RATIO = _minCollaterizationRatio;
    MAX_MINTED_BY_TVL         = _maxMintedByTVL;
    minXp                     = _maxSupply;
    maxXp                     = _maxSupply << 1; // *2

    for (uint id = 0; id < _insiders.length; ) { 
      _mintNft(_insiders[id], id, true);         // add starter xp
      unchecked { ++id; }
    }
  }

  // ETH price in USD
  function _getLatestEthPrice() internal view returns (uint) {
    ( , int newEthPrice, , , ) = oracle.latestRoundData();
    return newEthPrice.toUint256();
  }

  // Mint new dNFT to `to` with a deposit of atleast `DEPOSIT_MINIMUM`
  function mintNft(address to) external addressNotZero(to) payable returns (uint) {
    uint id = _mintNft(to, totalSupply(), true); // add starter xp
    _mintDyad(id, DEPOSIT_MINIMUM);
    return id;
  }

  // Mint new dNFT to `to` with `id` id and add Xp if `addXp` is true
  function _mintNft(
    address to,
    uint id,
    bool addXp
  ) private returns (uint) {
    if (id >= MAX_SUPPLY) { revert ReachedMaxSupply(); }
    if (addXp) {
      unchecked {                     
      uint xp = (MAX_SUPPLY<<1) - id; // id is always between 0 and MAX_SUPPLY-1
      idToNft[id].xp = xp;            // break xp symmetry 
      if (xp < minXp) { minXp = xp; } // sync could have increased `minXp`
      }
    }
    _mint(to, id); 
    emit NftMinted(to, id);
    return id;
  }

  // Mint and deposit DYAD into dNFT
  function mintDyad(
      uint id
  ) payable public onlyNFTOwner(id) returns (uint amount) {
      amount = _mintDyad(id, 0);
  }

  // Mint at least `minAmount` of DYAD to dNFT 
  function _mintDyad(
      uint id,
      uint minAmount
  ) private returns (uint) {
      if (msg.value == 0) { revert NoEthSupplied(); }
      uint newDyad = msg.value/100000000 * _getLatestEthPrice();
      if (newDyad == 0)        { revert AmountZero(newDyad); }
      if (newDyad < minAmount) { revert NotReachedMinAmount(newDyad); }
      dyad.mint(address(this), newDyad);
      idToNft[id].deposit += newDyad.toInt256();
      emit DyadMinted(msg.sender, id, newDyad);
      return newDyad;
  }

  // Deposit `amount` of DYAD into dNFT
  function deposit(
      uint id, 
      uint amount
  ) external amountNotZero(amount) returns (uint) {
      _idToBlockOfLastDeposit[id] = block.number;
      Nft storage nft = idToNft[id];
      if (amount > nft.withdrawn) { revert ExceedsWithdrawalLimit(amount); }
      nft.deposit    += amount.toInt256();
      nft.withdrawn  -= amount;
      bool success    = dyad.transferFrom(msg.sender, address(this), amount);
      if (!success) { revert FailedDyadTransfer(address(this), amount); }
      emit DyadDeposited(msg.sender, id, amount);
      return amount;
  }

  // Withdraw `amount` of DYAD from dNFT
  function withdraw(
      uint id,
      uint amount
  ) external onlyNFTOwner(id) amountNotZero(amount) returns (uint) {
      if (_idToBlockOfLastDeposit[id] == block.number) { 
        revert CannotDepositAndWithdrawInSameBlock(); } // stops flash loan attacks
      Nft storage nft = idToNft[id];
      if (amount.toInt256() > nft.deposit) { revert ExceedsDepositLimit(amount); }
      uint collatVault    = address(this).balance/100000000 * _getLatestEthPrice();      // in USD
      uint totalWithdrawn = dyad.totalSupply() - dyad.balanceOf(address(this)) + amount;
      uint collatRatio    = collatVault*10000 / totalWithdrawn;                          // in bps
      if (collatRatio < MIN_COLLATERIZATION_RATIO) { revert CrTooLow(collatRatio); }
      uint newWithdrawn   = nft.withdrawn + amount;
      uint averageTVL     = dyad.balanceOf(address(this)) / totalSupply();
      if (newWithdrawn > averageTVL) { revert ExceedsAverageTVL(); }
      nft.withdrawn       = newWithdrawn;
      nft.deposit        -= amount.toInt256();
      bool success        = dyad.transfer(msg.sender, amount);
      if (!success) { revert FailedDyadTransfer(msg.sender, amount); }
      emit DyadWithdrawn(msg.sender, id, amount);
      return amount;
  }

  // Redeem `amount` of DYAD for ETH from dNFT
  function redeem(
      uint id,
      uint amount
  ) external nonReentrant() onlyNFTOwner(id) amountNotZero(amount) returns (uint) {
      Nft storage nft = idToNft[id];
      if (amount > nft.withdrawn) { revert ExceedsWithdrawalLimit(amount); }
      nft.withdrawn -= amount;
      dyad.burn(msg.sender, amount);
      uint eth = amount*100000000 / lastEthPrice;
      (bool success, ) = payable(msg.sender).call{value: eth}("");
      if (!success) { revert FailedEthTransfer(msg.sender, eth); }
      emit DyadRedeemed(msg.sender, id, amount);
      return eth;
  }

  // Move `amount` `from` one dNFT deposit `to` another dNFT deposit
  function moveDeposit(
      uint _from,
      uint _to,
      uint amount
  ) external onlyNFTOwner(_from) amountNotZero(amount) returns (uint) {
      if (_from == _to) { revert CannotMoveDepositToSelf(_from, _to, amount); }
      Nft storage from = idToNft[_from];
      if (amount.toInt256() > from.deposit) { revert ExceedsDepositLimit(amount); }
      Nft storage to   = idToNft[_to];
      from.deposit    -= amount.toInt256();
      to.deposit      += amount.toInt256();
      emit DyadMoved(_from, _to, amount);
      return amount;
  }

  // Liquidate dNFT by burning it and minting a new copy to `to`
  function liquidate(
      uint id,
      address to
  ) external addressNotZero(to) payable returns (uint) {
      Nft memory nft = idToNft[id];
      if (!nft.isLiquidatable) { revert NotLiquidatable(id); }
      address owner  = ownerOf(id);
      _burn(id); 
      delete idToNft[id];
      _mintCopy(to, nft, id);
      emit NftLiquidated(owner, to,  id); 
      return id;
  }

  // Mint nft with `id` to `to` with the same xp and withdrawn amount as `nft`
  function _mintCopy(
      address to,
      Nft memory nft, 
      uint id
  ) private returns (uint) { 
      _mintNft(to, id, false);          // do not add starter xp
      Nft storage newNft = idToNft[id];
      uint minDeposit;
      if (nft.deposit < 0) { minDeposit = nft.deposit.abs(); }
      int newDeposit   = _mintDyad(id, minDeposit).toInt256();
      newNft.deposit   = newDeposit + nft.deposit;
      newNft.xp        = nft.xp;
      newNft.withdrawn = nft.withdrawn;
      return id;
  }

  // Sync by minting/burning DYAD to keep the peg and update each dNFT.
  // dNFT with `id` gets a boost.
  function sync(uint id) public {
    if (block.number < lastSyncedBlock + BLOCKS_BETWEEN_SYNCS) { 
      revert SyncedTooRecently(); 
    }
    lastSyncedBlock    = block.number;
    uint newEthPrice   = _getLatestEthPrice();
    Mode mode          = newEthPrice > lastEthPrice ? Mode.MINTING : Mode.BURNING;
    uint ethPriceDelta = newEthPrice*10000 / lastEthPrice; 
    mode == Mode.MINTING ? ethPriceDelta -= 10000                  // in bps
                         : ethPriceDelta  = 10000 - ethPriceDelta; // in bps
    uint dyadDelta     = _updateNFTs(ethPriceDelta, mode, id);     // can be 0
    mode == Mode.MINTING ? dyad.mint(address(this), dyadDelta) 
                         : dyad.burn(address(this), dyadDelta); 
    lastEthPrice       = newEthPrice;
    emit Synced(id);
  }

  function _updateNFTs(
      uint ethPriceDelta,
      Mode mode,
      uint id
  ) private returns (uint dyadDelta) {
      uint nftTotalSupply  = totalSupply();
      uint dyadTotalSupply = dyad.totalSupply();
      Multis memory multis = _calcMultis(mode, id, nftTotalSupply, dyadTotalSupply);
      dyadDelta            = dyadTotalSupply*ethPriceDelta / 10000; // percentagOf in bps
      uint _minXp          = type(uint256).max;  // local min
      uint _maxXp          = maxXp;              // local max
      uint productsSum     = multis.productsSum; // saves gas
      if (productsSum == 0) { productsSum = 1; } // to avoid dividing by 0 

      for (uint i = 0; i < nftTotalSupply; ) {
        uint relativeDyadDelta = dyadDelta *                // percentagOf in bps
          (multis.products[i]*10000 / productsSum) / 10000; // relativeMulti
        Nft storage nft = idToNft[i];
        int  _deposit   = nft.deposit;                      // save gas
        uint _xp        = nft.xp;                           // save gas

        if (mode == Mode.BURNING) {
          if (_deposit >= 1) {                              // if deposit > 0
            uint xpAccrual     = relativeDyadDelta*100 / (multis.xps[i]);
            if (id == i) { xpAccrual = xpAccrual << 1; } // boost by *2
            _xp            += xpAccrual / (10**18);         // norm by 18 decimals
          }
          _deposit         -= relativeDyadDelta.toInt256();
        } else {
          _deposit         += relativeDyadDelta.toInt256();
        }

        _deposit >= 0 ? nft.isLiquidatable = false : nft.isLiquidatable = true;

        if (_xp < _minXp) { _minXp = _xp; } // new local min
        if (_xp > _maxXp) { _maxXp = _xp; } // new local max

        nft.deposit = _deposit;
        nft.xp      = _xp;
        unchecked { ++i; }
      }

      if (_minXp > _maxXp) { revert MinXpHigherThanMaxXp(_minXp, _maxXp); }
      minXp = _minXp; // save new min
      maxXp = _maxXp; // save new max
  }

  function _calcMultis(
      Mode mode,
      uint id, 
      uint nftTotalSupply, 
      uint dyadTotalSupply
  ) private view returns (Multis memory) {
      uint productsSum;
      uint[] memory products = new uint[](nftTotalSupply);
      uint[] memory xps      = new uint[](nftTotalSupply);
      uint xpDelta           = maxXp - minXp;
      if (xpDelta == 0)      { xpDelta = 1; } // xpDelta min is 1

      for (uint i = 0; i < nftTotalSupply; ) {
        Nft   memory nft   = idToNft[i];
        Multi memory multi;                   // defaults to 0, 0
        if (nft.deposit > 0) {                // multis are 0 if deposit <= 0
          multi = _calcMulti(mode, nft, nftTotalSupply, dyadTotalSupply, xpDelta);
        } 
        if (id == i && mode == Mode.MINTING) { 
          multi.product += multi.product*1500 / 10000; // boost by 15%
        }
        products[i]  = multi.product;
        productsSum += multi.product;
        xps[i]       = multi.xp;
        unchecked { ++i; }
      }

      return Multis(products, productsSum, xps);
  }

  function _calcMulti(
      Mode mode,
      Nft memory nft,
      uint nftTotalSupply,
      uint dyadTotalSupply, 
      uint xpDelta 
  ) private view returns (Multi memory) {
      uint _deposit      = nft.deposit.toUint256();
      uint mintedByNft   = nft.withdrawn + _deposit;
      uint mintedByTvl   = mintedByNft*10000 / (dyadTotalSupply / nftTotalSupply); // mintedByNft/avgTVL
      if (mintedByTvl > MAX_MINTED_BY_TVL && mode == Mode.BURNING) { 
        mintedByTvl = MAX_MINTED_BY_TVL;
      }
      uint xpScaled = ((nft.xp-minXp)*10000 / xpDelta) / 100; 
      uint xpMulti = 50; // if 0 <= x <= 60, xp multi is 50
      unchecked {        
      if (xpScaled >= 61) { xpMulti = uint(uint8(XP_TO_MULTI[xpScaled - 61])); } // xpScaled is >= 61
      if (mode == Mode.BURNING) { xpMulti = 300-xpMulti; }                       // xpMulti  is <= 242
      }
      uint multiProduct = xpMulti * (mode == Mode.BURNING 
                                        ? mintedByTvl 
                                        : (_deposit*10000) / (mintedByNft+1)); // depositMulti
      return Multi(multiProduct, xpMulti);
  }
}
