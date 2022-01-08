// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPazariMVP {
  struct UserProfile {
    address userAddress;
    address tokenContract;
    bytes32 routeID;
    uint256[] itemIDs;
  }

  /**
   * @notice Auto-generates a new payment route, clones a token contract, mints a token, and lists
   * it on the Pazari marketplace in one turn. This function only needs three inputs.
   *
   * @param _URI URL of the JSON public metadata file, usually an IPFS URI
   * @param _amount Amount of tokens to be minted and listed
   * @param _price Price in USD for each token.
   */
  function newUser(
    string memory _URI,
    uint256 _amount,
    uint256 _price
  ) external returns (bool);

  /**
   * @notice Creates a new token and lists it on the Pazari Marketplace
   *
   * @dev Assumes the seller is using the same PaymentRoute and token contract
   * created in newUser().
   *
   * @dev Emits NewTokenListed event
   */
  function newTokenListing(
    string memory _URI,
    uint256 _amount,
    uint256 _price
  ) external returns (uint256, uint256);

  /**
   * @notice This is in case someone mistakenly sends their ERC1155 NFT to this contract address
   */
  function recoverNFT(
    address _nftContract,
    uint256 _tokenID,
    uint256 _amount
  ) external returns (bool);

  function getUserProfile(address _userAddress) external view returns (UserProfile memory);
}
