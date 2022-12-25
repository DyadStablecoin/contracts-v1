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
    bool isLiquidatable;
  }

  /**
   * @notice Mint a new dNFT
   * @dev Will revert:
   *      - If `msg.value` worth of DYAD < `DEPOSIT_MINIMUM`
   *      - If total supply of dNFTs is >= `MAX_SUPPLY`
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
   *      - If `amount` is > than dNFT's deposit
   *      - If CR is < `MIN_COLLATERIZATION_RATIO` after withdrawl
   *      - If new withdrawl amount of dNFT > average tvl
   *      - If dyad transfer fails
   * @param id Id of the dNFT
   * @param amount Amount of DYAD to withdraw
   * @return amount Amount withdrawn
   */
  function withdraw(
    uint id,
    uint amount
  ) external returns (uint);

  function deposit(uint id, uint amount) external;

  function ownerOf(uint tokenId) external view returns (address);
  function redeem(uint id, uint amount) external returns (uint);
  function mintCopy(address receiver, IdNFT.Nft memory nft) external payable returns (uint id);
  function burn(uint id) external;
  function balanceOf(uint id) external view returns (int);
  function totalSupply() external view returns (uint);
  function idToNft(uint) external view returns (Nft memory);
  function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
  function tokenByIndex(uint index) external returns (uint);
  function moveDeposit(uint from, uint to, uint amount) external;
  function sync(uint id) external returns (uint);
  function liquidate(uint id, address to) external payable returns (uint);
}

