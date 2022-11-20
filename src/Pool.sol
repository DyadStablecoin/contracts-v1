// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {DYAD} from "../src/dyad.sol";
import {IAggregatorV3} from "../src/AggregatorV3Interface.sol";
import {IdNFT} from "../src/IdNFT.sol";
import {PoolLibrary} from "../src/PoolLibrary.sol";

contract Pool {
  using SafeMath for uint256;

  // IMPORTANT: do not change the ordering of these variables
  // because some tests depend on this specific slot arrangement.
  uint public lastEthPrice;
  uint public lastCheckpoint;

  IdNFT public dnft;
  DYAD public dyad;
  IAggregatorV3 internal priceFeed;

  uint256 constant private REDEEM_MINIMUM = 100000000;

  mapping(uint => int) public dyadDeltaAtCheckpoint;
  mapping(uint => int) public xpDeltaAtCheckpoint;
  mapping(uint => uint) public poolBalanceAtCheckpoint;

  event NewEthPrice(int newEthPrice);

  /// @dev Check if msg.sender is the nft contract
  modifier onlyNFT() {
    require(msg.sender == address(dnft), "Pool: Only NFT can call this function");
    _;
  }

  constructor(address _dnft, address _dyad) {
    dnft         = IdNFT(_dnft);
    dyad         = DYAD(_dyad);
    priceFeed    = IAggregatorV3(PoolLibrary.PRICE_ORACLE_ADDRESS);
    lastEthPrice = uint(getNewEthPrice());
  }

  /// @notice get the latest eth price from oracle
  function getNewEthPrice() internal view returns (int newEthPrice) {
    // TODO: testing
    // ( , newEthPrice, , , ) = priceFeed.latestRoundData();
    newEthPrice = 115000000000;
  }

  uint TOTAL_SUPPLY = 10; // of dnfts
  uint MAX_XP = 8000;
  uint MIN_XP = 1079;
  uint TOTAL_DYAD = 96003;

  uint AVG_MINTED = TOTAL_DYAD / TOTAL_SUPPLY;

  function sync() public returns (int newEthPrice) {
    int OLD_ETH_PRICE = 100000000;
    int NEW_ETH_PRICE = 95000000;  // 95000000  ->  -5%
    // int NEW_ETH_PRICE = 110000000; // 110000000 -> +10%

    bool isNegative;
    if (NEW_ETH_PRICE - OLD_ETH_PRICE < 0) {
      isNegative = true;
    }
 
    uint ethChange = uint(NEW_ETH_PRICE).mul(10000).div(uint(OLD_ETH_PRICE));
    if (isNegative) {
      ethChange = 10000 - ethChange;
    } else {
      ethChange -= 10000;
    }

    console.log("ethChange: %s", ethChange);

    uint wantedMint = updateNFTs(ethChange, isNegative);
    console.log("deltaAmount: ", wantedMint);

    if (uint(newEthPrice) > lastEthPrice) {
      dyad.mint(address(this), wantedMint);
    } else {
      // What happens if there is not enough to burn?
      // TODO
      // dyad.burn(wantedMint);
    }

    lastEthPrice    = uint(newEthPrice);
    lastCheckpoint += 1;
    emit NewEthPrice(newEthPrice);
  }

  /// @param ethChange  Eth price change in basis points
  /// @param isNegative Is the change negative or positive
  /// @return dyadDelta The amount of dyad to mint or burn
  function updateNFTs(uint ethChange, bool isNegative) internal returns (uint dyadDelta) {
    // we boost the nft of the user calling this function with additional
    // xp, but only once! If boosted was used already, it can not be used again.
    bool isBoosted = false;

    // the amount to mint/burn to keep the peg
    dyadDelta = PoolLibrary.percentageOf(TOTAL_DYAD, ethChange);

    Multis memory multis = calcMultis(isNegative);

    // we use these to keep track of the max/min xp values for this round, 
    // so we can save them in storage to be used in the next round.
    uint roundMinXp = type(uint256).max;
    uint roundMaxXp = MAX_XP;

    for (uint i = 0; i < TOTAL_SUPPLY; i++) {
      uint percentageChange  = multis.multis[i]*10000/multis.multisSum;
      uint mintingAllocation = PoolLibrary.percentageOf(dyadDelta, percentageChange);

      IdNFT.Nft memory nft = dnft.idToNft(i);

      // xp accrual happens only when there is a burn.
      uint xpAccrual;
      if (isNegative) {
        // normal accrual
        xpAccrual = mintingAllocation * 100 / (multis.xpMultis[i]);
        // boost for the address calling this function
        if (!isBoosted && msg.sender == dnft.idToOwner(i)) {
          isBoosted = true;
          xpAccrual += PoolLibrary.percentageOf(nft.xp, 10); // 0.10%
        }
      }

      //--------------- STATE UPDATE ----------------
      console.logUint(i);
      console.logUint(nft.deposit);

      if (isNegative) {
        nft.deposit -= mintingAllocation;
        nft.xp      += xpAccrual;
      } else {
        nft.deposit += mintingAllocation;
      }

      console.logUint(nft.deposit);
      console.log();

      dnft.updateNft(i, nft);

      // is this a new round xp minimum?
      if (nft.xp < roundMinXp) {
        roundMinXp = nft.xp;
      }
      // is this a new round xp maximum?
      if (nft.xp > roundMaxXp) {
        roundMaxXp = nft.xp;
      }
    }

    // save new min/max xp in storage
    MIN_XP = roundMinXp;
    MAX_XP = roundMaxXp;
  }

  struct Multis {
    uint[] multis;
    uint multisSum;
    uint[] xpMultis;
  }

  function calcMultis(bool isNegative) internal view returns (Multis memory) {
    uint multisSum;
    uint[] memory multis   = new uint[](TOTAL_SUPPLY);
    uint[] memory xpMultis = new uint[](TOTAL_SUPPLY);

    for (uint i = 0; i < TOTAL_SUPPLY; i++) {
      IdNFT.Nft memory nft = dnft.idToNft(i);
      uint xpScaled = (nft.xp-MIN_XP)*10000 / (MAX_XP-MIN_XP);
      uint mintAvgMinted = (nft.balance+nft.deposit)*10000 / (AVG_MINTED+1);
      uint xpMulti  = PoolLibrary.getXpMulti(xpScaled/100);
      if (isNegative) {
        xpMulti = 300 - xpMulti;
      }
      uint depositMulti  = nft.deposit*10000 / (nft.deposit+nft.balance+1);
      uint multiProduct;
      if (isNegative) {
        multiProduct = xpMulti * mintAvgMinted/100;
      } else {
        multiProduct = xpMulti * depositMulti/100;
      }

      multisSum  += multiProduct;
      multis[i]   = multiProduct;
      xpMultis[i] = xpMulti;
    }

    return Multis(multis, multisSum, xpMultis);
  }

  /// @notice Mint dyad to the NFT
  function mintDyad(uint minAmount) payable external onlyNFT returns (uint) {
    require(msg.value > 0,        "Pool: You need to send some ETH");
    uint newDyad = lastEthPrice.mul(msg.value).div(100000000);
    require(newDyad >= minAmount, "Pool: mintDyad: minAmount not reached");
    dyad.mint(msg.sender, newDyad);
    return newDyad;
  }

  /// @notice Deposit dyad into the pool
  /// @param amount The amount of dyad to deposit
  function deposit(uint amount) external onlyNFT {
    dyad.transferFrom(msg.sender, address(this), amount);
  }

  /// @notice Withdraw dyad from the pool to the recipient
  /// @param amount The amount of dyad to withdraw
  /// @param recipient The address to withdraw dyad to
  function withdraw(address recipient, uint amount) external onlyNFT {
    dyad.transfer(recipient, amount);
  }

  /// @notice Redeem dyad for eth
  function redeem(uint amount) public {
    require(amount > REDEEM_MINIMUM, "Pool: Amount must be greater than 100000000");
    // msg.sender has to approve pool to spend its tokens
    dyad.transferFrom(msg.sender, address(this), amount);
    dyad.burn(amount);

    uint usdInEth = amount.mul(100000000).div(lastEthPrice);
    payable(msg.sender).transfer(usdInEth);
  }
}

