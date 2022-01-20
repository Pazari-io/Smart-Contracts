// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ContractFactories/FactoryPazariTokenMVP.sol";
import {IAccessControlMP, IMarketplace} from "../Marketplace/IMarketplace.sol";
import {IPaymentRouter, IAccessControlPR} from "../PaymentRouter/IPaymentRouter.sol";
import "../Tokens/IPazariTokenMVP.sol";
import "../Dependencies/IERC20.sol";
import "../Dependencies/ERC1155Holder.sol";

contract AccessControlPMVP {
  // All "owners" who can access restricted PazariToken functions
  // Includes addresses for market, router, and factory
  address[] internal admins;

  // Maps admin addresses to bool
  mapping(address => bool) public isAdmin;

  // Fires when Pazari admins are added/removed
  event AdminAdded(
    address indexed newAdmin, 
    address indexed adminAuthorized, 
    string memo, 
    uint256 timestamp
  );
  event AdminRemoved(
    address indexed oldAdmin,
    address indexed adminAuthorized,
    string memo,
    uint256 timestamp
  );

  constructor(address[] memory _adminAddresses) {
    for (uint256 i = 0; i < _adminAddresses.length; i++) {
      isAdmin[_adminAddresses[i]] = true;
    }
  }

  /**
   * @notice Requires that both msg.sender and tx.origin be admins. This restricts all
   * calls to only Pazari-owned admin addresses, including wallets and contracts, and
   * eliminates phishing attacks.
   */
  modifier onlyAdmin() {
    require(isAdmin[msg.sender] && isAdmin[tx.origin], "Only Pazari-owned addresses");
    _;
  }

  /**
   * @notice Returns tx.origin for any Pazari-owned admin contracts, returns msg.sender
   * for everything else. See PaymentRouter for more details.
   */
  function _msgSender() public view returns (address) {
    if (tx.origin != msg.sender && isAdmin[msg.sender]) {
      return tx.origin;
    } else return msg.sender;
  }

  // Adds an address to isAdmin mapping
  // Requires both tx.origin and msg.sender be admins
  function addAdmin(address _newAddress, string calldata _memo) external onlyAdmin returns (bool) {
    require(!isAdmin[_newAddress], "Address is already an admin");

    isAdmin[_newAddress] = true;

    emit AdminAdded(_newAddress, _msgSender(), _memo, block.timestamp);
    return true;
  }

  // Removes an address from isAdmin mapping
  // Requires both tx.origin and msg.sender be admins
  function removeAdmin(address _oldAddress, string calldata _memo) external onlyAdmin returns (bool) {
    require(isAdmin[_oldAddress], "Address is not an admin");

    isAdmin[_oldAddress] = false;

    emit AdminRemoved(_oldAddress, _msgSender(), _memo, block.timestamp);
    return true;
  }
}

contract PazariMVP is ERC1155Holder, AccessControlPMVP {
  // Declare all external contracts
  IERC20 public immutable iERC20;
  IPaymentRouter public immutable iPaymentRouter;
  IMarketplace public immutable iMarketplace;
  FactoryPazariTokenMVP public immutable iFactoryPazariTokenMVP;

  // Fires when a new token is listed for sale
  event NewTokenListed(
    uint256 itemID,
    address indexed tokenContract,
    uint256 indexed price,
    uint256 tokenID,
    uint256 amount,
    string uri,
    address indexed sender
  );

  // Fires when a new user joins Pazari
  event NewUserCreated(
    address indexed userAddress, 
    bytes32 routeID, 
    address tokenContractAddress, 
    uint256 timestamp
  );

  /**
   * @notice Fires when a new PazariTokenMVP contract is cloned
   *
   * @param contractID Unique identifier for the contract created
   * @param contractType Number representing type of contract created (see below)
   * @param creatorAddress Address of contract's creator
   * @param factoryAddress Address of factory that created the contract
   * @param cloneAddress Address of cloned token contract
   * @param timestamp Block timestamp when contract was created
   *
   * @dev All ContractCloned events from PazariMVP will have contractType = 0,
   * so it is not indexed. Instead, we can filter by contractID, creator's
   * address, and the factory's address.
   */
  event ContractCloned(
    uint256 indexed contractID,
    uint16 contractType,
    address creatorAddress,
    address indexed factoryAddress,
    address cloneAddress,
    uint256 timestamp
  );

  // Fires when admin recovers lost NFT(s)
  event NFTRecovered(
    address indexed tokenContract, 
    uint256 indexed tokenID, 
    address recipient, 
    address indexed admin, 
    string memo, 
    uint256 timestamp
  );

  address[] public deployedContracts; // Array of all token contract addresses deployed by this contract
  uint256[] public itemIDs; // List of all itemIDs created through the PazariMVP contract

  // Maps user's address to their Pazari MVP profile
  // This is private because mappings of structs can't return arrays, use getUserProfile() instead
  mapping(address => UserProfile) private userProfile;

  /**
   * @notice General information about a user's profile
   * @param userAddress User's address, determined by _msgSender()
   * @param tokenContract Address of PazariTokenMVP contract associated with user profile
   * @param routeID Bytes32 ID of user's PaymentRoute
   * @param itemIDs Array of all itemIDs created by this user
   */
  struct UserProfile {
    address userAddress;
    address tokenContract;
    bytes32 routeID;
    uint256[] itemIDs;
  }

  /**
   * @param _factory Contract address for FactoryPazariTokenMVP
   * @param _market Contract address for Marketplace
   * @param _paymentRouter Contract address for PaymentRouter
   * @param _stablecoin Contract address for ERC20-style stablecoin used for MVP
   * @param _admins Array of addresses who can call AccessControlPMVP functions
   */
  constructor(
    address _factory,
    address _market,
    address _paymentRouter,
    address _stablecoin,
    address[] memory _admins
  ) AccessControlPMVP(_admins) {
    super;
    // Instantiate Pazari core contracts, stablecoin address, and factory address
    iMarketplace = IMarketplace(_market);
    iPaymentRouter = IPaymentRouter(_paymentRouter);
    iERC20 = IERC20(_stablecoin);
    iFactoryPazariTokenMVP = FactoryPazariTokenMVP(_factory);
    // Push Pazari core addresses to admins
    admins.push(address(_market));
    admins.push(address(_paymentRouter));
    admins.push(address(_factory));
    admins.push(address(this));
  }

  /**
   * @notice Returns an address's UserProfile struct
   */
  function getUserProfile(address _userAddress) public view returns (UserProfile memory) {
    UserProfile memory tempProfile = userProfile[_userAddress];
    require(tempProfile.userAddress == _userAddress, "User profile does not exist");
    return tempProfile;
  }

  /**
   * @notice Creates a new UserProfile struct and clones a new token contract
   * @return address Contract address of user's token contract
   */
  function createUserProfile() private returns (address) {
    // Require that admins completed initialization
    require(
      IAccessControlMP(address(iMarketplace)).isAdmin(address(this)),
      "Admins must add PazariMVP as admin for Marketplace"
    ); 
    require(
      IAccessControlPR(address(iPaymentRouter)).isAdmin(address(this)),
      "Admins must add PazariMVP as admin for PaymentRouter"
    );

    // Store return value of _msgSender()
    address msgSender = _msgSender();

    // Find out if msgSender is blacklisted from the Marketplace
    require(!IAccessControlMP(address(iMarketplace)).isBlacklisted(msgSender), "Caller is blacklisted");
    // Check that user doesn't already have a UserProfile
    require(userProfile[msgSender].userAddress == address(0), "User already registered!");

    // PaymentRouter \\
    // Create singleton arrays for PaymentRouter inputs
    uint16[] memory _uint = new uint16[](1);
    _uint[0] = 10000;
    address[] memory _addr = new address[](1);
    _addr[0] = msgSender;

    // Open new PaymentRoute, store returned routeID
    bytes32 routeID = iPaymentRouter.openPaymentRoute(_addr, _uint, 0);

    // FactoryPazariTokenMVP \\
    // Clone new PazariTokenMVP contract, store data, fire event
    admins.push(msgSender); // Push msgSender in as an admin for new contract
    address tokenContractAddress = iFactoryPazariTokenMVP.newPazariTokenMVP(admins);
    deployedContracts.push(tokenContractAddress);
    admins.pop(); // Pop msgSender back out
    // Emits basic information about deployed contract
    emit ContractCloned(
      deployedContracts.length,
      0,
      msgSender,
      address(iFactoryPazariTokenMVP),
      tokenContractAddress,
      block.timestamp
    );

    // Create UserProfile struct
    userProfile[msgSender].userAddress = msgSender;
    userProfile[msgSender].routeID = routeID;
    userProfile[msgSender].tokenContract = tokenContractAddress;

    // Emits all UserProfile struct properties
    emit NewUserCreated(msgSender, routeID, tokenContractAddress, block.timestamp);

    return tokenContractAddress;
  }

  /**
   * @notice Creates a new token and lists it on the Pazari Marketplace.
   * @dev If user does not have a profile yet, then one is created and
   * a new token contract is cloned and deployed.
   *
   * @param _URI URL to token's public metadata
   * @param _amount Amount of tokens to mint and list
   * @param _price Listing price per token
   * @return tokenID The tokenID and itemID of the new token listed
   *
   * @dev Emits NewTokenListed event
   */
  function newTokenListing(
    string memory _URI,
    uint256 _amount,
    uint256 _price
  ) external returns (uint256, uint256) {
    // Require that admins completed initialization
    require(
      IAccessControlMP(address(iMarketplace)).isAdmin(address(this)) &&
        IAccessControlPR(address(iPaymentRouter)).isAdmin(address(this)),
      "Admins must finish initialization"
    );
    address msgSender = _msgSender();
    address tokenContract = userProfile[msgSender].tokenContract;
    uint256 tokenID;
    uint256 itemID;

    // Find out if msgSender is blacklisted from the Marketplace
    require(!IAccessControlMP(address(iMarketplace)).isBlacklisted(msgSender), "Caller is blacklisted");
    // User cannot create 0 tokens
    require(_amount > 0, "Amount must be greater than 0");
    // Require that user already has their own token contract
    if (tokenContract == address(0)) {
      tokenContract = createUserProfile();
    }

    // Create new Pazari token
    tokenID = IPazariTokenMVP(tokenContract).createNewToken(_URI, _amount, 0, true);

    // Marketplace \\
    // List Pazari token on Marketplace
    itemID = iMarketplace.createMarketItem(
      tokenContract,
      tokenID,
      _amount,
      _price,
      address(iERC20),
      userProfile[msgSender].routeID
    );

    itemIDs.push(itemID);
    userProfile[msgSender].itemIDs.push(itemID);

    emit NewTokenListed(itemID, tokenContract, _price, tokenID, _amount, _URI, msgSender);
    return (tokenID, itemID);
  }

  /**
   * @notice Returns the MarketItem struct for a given _itemID
   * @dev If we need to return multiple MarketItems, then use iMarketplace.getMarketItems()
   */
  function getMarketItem(uint256 _itemID) public view returns (IMarketplace.MarketItem memory) {
    // Creates a singleton array so _itemID can be used in getMarketItems()
    uint256[] memory singletonArray = new uint256[](1);
    singletonArray[0] = _itemID;

    // Call getMarketItems(singletonArray), store returned MarketItem[] as marketItems
    IMarketplace.MarketItem[] memory marketItems = iMarketplace.getMarketItems(singletonArray);

    // Return first element marketItems--this is the MarketItem we are looking for
    return marketItems[0];
  }

  /**
   * @notice This is in case someone mistakenly sends their ERC1155 NFT to this contract address
   * @dev Only PazariMVP admins can call this function, and is the only function they can call.
   */
  function recoverNFT(
    address _nftContract,
    uint256 _tokenID,
    uint256 _amount,
    address _to,
    string calldata _memo
  ) external onlyAdmin returns (bool) {
    require(IERC1155(_nftContract).balanceOf(address(this), _tokenID) != 0, "NFT not here!");

    IERC1155(_nftContract).safeTransferFrom(address(this), _to, _tokenID, _amount, "");

    emit NFTRecovered(_nftContract, _tokenID, _to, _msgSender(), _memo, block.timestamp);
    return true;
  }
}
