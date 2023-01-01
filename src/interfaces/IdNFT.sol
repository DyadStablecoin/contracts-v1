// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IdNFT {
  struct Nft {
    // dyad withdrawn from the pool deposit
    uint withdrawn;   
    // dyad balance in pool
    int deposit;      
    // always positive, always inflationary
    uint xp;          
    // if true the dNFT is open to be liquidatable
    bool isLiquidatable;
  }
  
  /**
   * @notice Get dNFT by id
   * @param id dNFT id
   * @return dNFT 
   */
  function idToNft(
    uint id
  ) external view returns (Nft memory);

  /**
   * @notice Mint a new dNFT
   * @dev Will revert:
   *      - If `msg.value` worth of DYAD < `DEPOSIT_MINIMUM`
   *      - If total supply of dNFTs is >= `MAX_SUPPLY`
   * @dev Emits:
   *      - NftMinted
   *      - DyadMinted
   * @param to The address to mint the dNFT to
   * @return id Id of the new dNFT
   */
  function mintNft(
    address to
  ) external payable returns (uint id);

  /**
   * @notice Mint and deposit new DYAD into dNFT
   * @dev Will revert:
   *      - If dNFT is not owned by `msg.sender`
   *      - If `amount` minted is 0
   * @dev Emits:
   *      - DyadMinted
   * @param id Id of the dNFT
   * @return amount Amount minted
   */
  function mintDyad(
    uint id
  ) external payable returns (uint);

  /**
   * @notice Withdraw `amount` of DYAD from dNFT
   * @dev Will revert:
   *      - If dNFT is not owned by `msg.sender`
   *      - If `amount` is 0
   *      - If `amount` is > than dNFT deposit
   *      - If CR is < `MIN_COLLATERIZATION_RATIO` after withdrawl
   *      - If new withdrawl amount of dNFT > average tvl
   *      - If dyad transfer fails
   * @dev Emits:
   *      - DyadWithdrawn
   * @param id Id of the dNFT
   * @param amount Amount of DYAD to withdraw
   * @return amount Amount withdrawn
   */
  function withdraw(
    uint id,
    uint amount
  ) external returns (uint);

  /**
   * @notice Deposit `amount` of DYAD into dNFT
   * @dev Will revert:
   *      - If dNFT is not owned by `msg.sender`
   *      - If `amount` is 0
   *      - If `amount` is > than dNFT withdrawls
   *      - If dyad transfer fails
   * @dev Emits:
   *      - DyadDeposited
   * @param id Id of the dNFT
   * @param amount Amount of DYAD to withdraw
   * @return amount Amount deposited
   */
  function deposit(uint id, uint amount) external returns (uint);

  /**
   * @notice Redeem `amount` of DYAD for ETH from dNFT
   * @dev Will revert:
   *      - If dNFT is not owned by `msg.sender`
   *      - If `amount` is 0
   *      - If `amount` is > than dNFT withdrawls
   * @dev Emits:
   *      - DyadRedeemed
   * @param id Id of the dNFT
   * @param amount Amount of DYAD to redeem
   * @return amount Amount of ETH redeemed
   */
  function redeem(uint id, uint amount) external returns (uint);

  /**
   * @notice Move `amount` `from` one dNFT deposit `to` another dNFT deposit
   * @dev Will revert:
   *      - If `from` dNFT is not owned by `msg.sender`
   *      - If `amount` is 0
   *      - If `from` == `to`
   *      - If `amount` is > than `from` dNFT deposit
   * @dev Emits:
   *      - DyadMoved
   * @param from Id of the dNFT to move the deposit from
   * @param to Id of the dNFT to move the deposit to
   * @param amount Amount of DYAD to move
   * @return amount Amount of ETH redeemed
   */
  function moveDeposit(uint from, uint to, uint amount) external returns (uint);

  /**
   * @notice Liquidate dNFT by burning it and minting a new copy to `to`. Copies
   * over the burned dNFT xp and withdrawls. The new dNFT deposit will equivalent
   * to `msg.value` worth of DYAD.
   * @dev Deletes the state of the dNFT being liquidated
   * @dev Will revert:
   *      - If `to` address is 0
   *      - If dNFT is not liquidatable
   *      - If `msg.value` worth of DYAD does not cover deposit of the burned dNFT
   * @dev Emits:
   *      - NftLiquidated
   * @param id Id of the dNFT to move the deposit from
   * @param to Id of the dNFT to move the deposit to
   * @return id Id of the newly minted dNFT
   */
  function liquidate(uint id, address to) external payable returns (uint);

  /**
   * @notice Sync by minting/burning DYAD to keep the peg and update each dNFT.
   * @dev Will revert:
   *      - If sync was called too soon after the last sync call
   * @dev Emits:
   *      - Synced
   * @param id Id of the dNFT that gets a boost
   * @return id The amount of DYAD minted/burned
   */
  function sync(uint id) external returns (uint);

  // get min/max XP
  function maxXp() external view returns (uint);
  function minXp() external view returns (uint);

  // ERC721
  function ownerOf(uint tokenId) external view returns (address);
  function balanceOf(uint id) external view returns (int);
  function totalSupply() external view returns (uint);
  function transferFrom(address _from, address _to, uint256 _tokenId) external payable;

  // ERC721Enumerable
  function tokenByIndex(uint index) external returns (uint);

  // ERC721Burnable
  function burn(uint id) external;
}

