/**
 * @dev Use this to greatly simplify everything.
 */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ContractFactories/FactoryPazariTokenMVP.sol";
import "../Marketplace/IMarketplace.sol";
import "../PaymentRouter/IPaymentRouter.sol";
import "../Tokens/IPazariTokenMVP.sol";
import "../Dependencies/IERC20.sol";
import "../Dependencies/ERC1155Holder.sol";

contract PazariMVP is ERC1155Holder {
  IERC20 public immutable stablecoin;
  address public immutable stablecoinAddress;
  IPaymentRouter public immutable iPaymentRouter;
  address public immutable paymentRouterAddress;
  IMarketplace public immutable iMarketplace;
  address public immutable marketAddress;
  FactoryPazariTokenMVP public immutable iFactoryPazariTokenMVP;
  address public immutable factoryAddress;
  IPazariTokenMVP private iPazariTokenMVP;

  address[] private contractOwners; // All "owners" who can access restricted PazariToken functions
  address[] public deployedContracts; // Array of all token contract addresses deployed by this contract
  uint256[] public itemIDs; // List of all itemIDs created through the NewUser contract

  // Maps user's address to their Pazari MVP profile
  // This is private because mappings can't return arrays, which prevents returning itemIDs[],
  // which requires a getter function to access anyways
  mapping(address => UserProfile) private userProfile;

  struct UserProfile {
    address userAddress;
    address tokenContract;
    bytes32 routeID;
    uint256[] itemIDs;
  }

  constructor(
    address _factory,
    address _market,
    address _paymentRouter,
    address _stablecoin
  ) {
    super;
    // Initialize all constants
    marketAddress = _market;
    paymentRouterAddress = _paymentRouter;
    stablecoinAddress = _stablecoin;
    factoryAddress = _factory;

    // Instantiate all contracts
    iMarketplace = IMarketplace(_market);
    iPaymentRouter = IPaymentRouter(_paymentRouter);
    stablecoin = IERC20(_stablecoin);
    iFactoryPazariTokenMVP = FactoryPazariTokenMVP(_factory);
  }

  // Fires when a new user joins and lists an item
  event NewUserProfile(address indexed userAddress, address indexed tokenContract, bytes32 indexed routeID);

  // Fires when a new token is listed for sale
  event NewTokenListed(
    uint256 indexed itemID,
    address indexed tokenContract,
    uint256 indexed price,
    uint256 tokenID,
    uint256 amount
  );

  function getUserProfile(address _userAddress) public view returns (UserProfile memory) {
    UserProfile memory tempProfile = userProfile[_userAddress];
    return tempProfile;
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
  ) external returns (bool) {
    require(userProfile[msg.sender].userAddress == address(0), "User already registered!");
    uint16[] memory _uint = new uint16[](1);
    _uint[0] = 10000;
    address[] memory _addr = new address[](1);
    _addr[0] = msg.sender;

    //SET UP NEW PAYMENT ROUTE, STORE RETURNED ROUTE ID
    bytes32 routeID = iPaymentRouter.openPaymentRoute(_addr, _uint, 0);

    //CLONE NEW CONTRACT, STORE RETURNED TOKEN CONTRACT ADDRESS
    contractOwners = [msg.sender, address(this), paymentRouterAddress, marketAddress];
    address tokenContractAddress = iFactoryPazariTokenMVP.newPazariTokenMVP(contractOwners);
    // Push tokenContractAddress to array of all deployed contracts
    deployedContracts.push(tokenContractAddress);

    //MINT NEW TOKEN AT TOKEN CONTRACT ADDRESS
    uint256 tokenID = IPazariTokenMVP(tokenContractAddress).createNewToken(_URI, _amount, 0, true);

    //LIST TOKEN ON MARKETPLACE
    uint256 itemID = iMarketplace.createMarketItem(
      tokenContractAddress,
      msg.sender,
      tokenID,
      _amount,
      _price,
      stablecoinAddress,
      true,
      true,
      routeID,
      0,
      false
    );

    // CREATE USER PROFILE
    userProfile[msg.sender].userAddress = msg.sender;
    userProfile[msg.sender].routeID = routeID;
    userProfile[msg.sender].tokenContract = tokenContractAddress;
    userProfile[msg.sender].itemIDs.push(itemID);

    return true;
  }

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
  ) external returns (uint256, uint256) {
    //MINT NEW TOKEN AT TOKEN CONTRACT ADDRESS
    address tokenContract = userProfile[msg.sender].tokenContract;
    uint256 tokenID;
    uint256 itemID;

    require(_amount > 0, "Amount must be greater than 0");
    require(tokenContract != address(0), "User does not have token contract!");

    tokenID = IPazariTokenMVP(tokenContract).createNewToken(_URI, _amount, 0, true);

    //LIST TOKEN ON MARKETPLACE
    itemID = iMarketplace.createMarketItem(
      tokenContract,
      msg.sender,
      tokenID,
      _amount,
      _price,
      stablecoinAddress,
      true,
      true,
      userProfile[msg.sender].routeID,
      0,
      false
    );
    itemIDs.push(itemID);
    userProfile[msg.sender].itemIDs.push(itemID);

    emit NewTokenListed(itemID, tokenContract, _price, tokenID, _amount);
    return (tokenID, itemID);
  }

  // Returns one MarketItem struct used by Marketplace for itemID
  function getMarketItem(uint256 _itemID) public view returns (IMarketplace.MarketItem memory) {
    // Creates a singleton array so _itemID can be used in getMarketItems()
    uint256[] memory singletonArray = new uint256[](1);
    singletonArray[0] = _itemID;

    // Call getMarketItems(singletonArray), store returned MarketItem[] as marketItems
    IMarketplace.MarketItem[] memory marketItems = iMarketplace.getMarketItems(singletonArray);

    // Return first element marketItems--this is the MarketItem we are looking for
    return marketItems[0];
    /*
     */
  }

  /**
   * @notice Mints more of an existing tokenID and lists for sale
   */

  /* I WANT TO INCLUDE THESE FUNCTIONS, BUT THE OWNERSHIP DESIGN IS NOT WORKING, AND BURNING PULLED
   * TOKENS ISN'T WORKING EITHER. SO, JUST USE THE BASIC FUNCTIONS THAT DO WORK HERE, AND IF WE NEED
   * TO TEST PULLING/RESTOCKING THEN USE MARKETPLACE'S FUNCTIONS TO DO SO
  function restockItems(uint256 _itemID, uint256 _amount, uint256 _price) external returns (bool) {
    address tokenContract = userProfile[msg.sender].tokenContract;
    uint256 tokenID = getMarketItem(_itemID).tokenID;

    // Make sure caller owns the tokenContract of the itemID they are restocking
    require(getMarketItem(_itemID).tokenContract == userProfile[msg.sender].tokenContract, 
        "You don't own that item");
    require(tokenContract != address(0), "User does not have token contract!");
    require(_amount > 0, "Amount must be greater than 0");
    // Sellers can put items up for free, no need for _price check
    
    // Mint more tokens
     // mint() does not use a URI or data input at all
    IPazariTokenMVP(tokenContract).mint(
      msg.sender, 
      tokenID, 
      _amount, 
      "", 
      ""
    );

    // Restock tokens on Marketplace
    iMarketplace.restockItem(_itemID, _amount);

    emit NewTokenListed(_itemID, tokenContract, _price, tokenID, _amount);
    return true;
  }
*/
  /**
   * @notice Removes all stock from the Marketplace and burns everything
   *
   * @dev We have to use delegatecall() to run pullStock, since only the
   * itemID owner can call pullStock but NewUser is not the owner.
   */
  /*
  function pullStock(uint256 _itemID) external returns (bool) {
    IMarketplace.MarketItem memory item = getMarketItem(_itemID);
    address tokenContract = item.tokenContract;
    iPazariTokenMVP = IPazariTokenMVP(tokenContract);

    // Check caller owns tokenContract of itemID they are pulling
    require(item.tokenContract == userProfile[msg.sender].tokenContract, 
        "You don't own that item");

    iMarketplace.pullStock(_itemID, item.amount);
    iPazariTokenMVP.burn(item.tokenID, item.amount);
    return true;
  }
*/

  /**
   * @notice This is in case someone mistakenly sends their ERC1155 NFT to this contract address
   */
  function recoverNFT(
    address _nftContract,
    uint256 _tokenID,
    uint256 _amount
  ) external returns (bool) {
    require(IERC1155(_nftContract).balanceOf(address(this), _tokenID) != 0, "NFT not here!");

    IERC1155(_nftContract).safeTransferFrom(address(this), msg.sender, _tokenID, _amount, "");
    return true;
  }
}
