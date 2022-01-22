// READY FOR PRODUCTION
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice Pazari developer functions are not included
 */
interface IPaymentRouter {
  //***EVENTS***\\
  // Fires when a new payment route is created
  event RouteCreated(address indexed creator, bytes32 routeID, address[] recipients, uint16[] commissions);

  // Fires when a route creator changes route tax
  event RouteTaxChanged(bytes32 routeID, uint16 newTax);

  // Fires when a route tax bounds is changed
  event RouteTaxBoundsChanged(uint16 minTax, uint16 maxTax);

  // Fires when a route has processed a push-transfer operation
  event TransferReceipt(
    address indexed sender,
    bytes32 routeID,
    address tokenContract,
    uint256 amount,
    uint256 tax,
    uint256 timeStamp
  );

  // Fires when a push-transfer operation fails
  event TransferFailed(
    address indexed sender,
    bytes32 routeID,
    uint256 payment,
    uint256 timestamp,
    address recipient
  );

  // Fires when tokens are deposited into a payment route for holding
  event TokensHeld(bytes32 routeID, address tokenAddress, uint256 amount);

  // Fires when tokens are collected from holding by a recipient
  event TokensCollected(address indexed recipient, address tokenAddress, uint256 amount);

  // Fires when a PaymentRoute's isActive property is toggled on or off
  // isActive == true => Route was reactivated
  // isActive == false => Route was deactivated
  event RouteToggled(bytes32 indexed routeID, bool isActive, uint256 timestamp);

  // Fires when an admin sets a new address for the Pazari treasury
  event TreasurySet(address oldAddress, address newAddress, address adminCaller, uint256 timestamp);

  // Fires when the pazariTreasury address is altered
  event TreasuryChanged(
    address oldAddress,
    address newAddress,
    address indexed adminAuthorized,
    string memo,
    uint256 timestamp
  );

  // Fires when recipient max values are altered
  event MaxRecipientsChanged(
    uint8 newMaxRecipients,
    address indexed adminAuthorized,
    string memo,
    uint256 timestamp
  );

  //***STRUCT AND ENUM***\\

  // Stores data for each payment route
  struct PaymentRoute {
    address routeCreator; // Address of payment route creator
    address[] recipients; // Recipients in this payment route
    uint16[] commissions; // Commissions for each recipient--in fractions of 10000
    uint16 routeTax; // Tax paid by this route
    TAXTYPE taxType; // Determines if PaymentRoute auto-adjusts to minTax or maxTax
    bool isActive; // Is route currently active?
  }

  // Enum that is used to auto-adjust routeTax if minTax/maxTax are adjusted
  enum TAXTYPE {
    CUSTOM,
    MINTAX,
    MAXTAX
  }

  //***FUNCTIONS: GETTERS***\\

  /**
   * @notice Directly accesses paymentRouteID mapping
   * @dev Returns PaymentRoute properties as a tuple rather than a struct, and may not return the
   * recipients and commissions arrays. Use getPaymentRoute() wherever possible.
   */
  function paymentRouteID(bytes32 _routeID)
    external
    view
    returns (
      address,
      uint16,
      TAXTYPE,
      bool
    );

  /**
   * @notice Calculates the routeID of a payment route.
   *
   * @param _routeCreator Address of payment route's creator
   * @param _recipients Array of all commission recipients
   * @param _commissions Array of all commissions relative to _recipients
   * @return routeID Calculated routeID
   *
   * @dev RouteIDs are calculated by keccak256(_routeCreator, _recipients, _commissions)
   * @dev If a non-Pazari helper contract was used, then _routeCreator will be contract's address
   */
  function getPaymentRouteID(
    address _routeCreator,
    address[] calldata _recipients,
    uint16[] calldata _commissions
  ) external pure returns (bytes32 routeID);

  /**
   * @notice Returns the entire PaymentRoute struct, including arrays
   */
  function getPaymentRoute(bytes32 _routeID) external view returns (PaymentRoute memory paymentRoute);

  /**
   * @notice Returns a balance of tokens/stablecoins ready for collection
   *
   * @param _recipientAddress Address of recipient who can collect tokens
   * @param _tokenContract Contract address of tokens/stablecoins to be collected
   */
  function getPaymentBalance(address _recipientAddress, address _tokenContract)
    external
    view
    returns (uint256 balance);

  /**
   * @notice Returns an array of all routeIDs created by an address
   */
  function getCreatorRoutes(address _creatorAddress) external view returns (bytes32[] memory routeIDs);

  /**
   * @notice Returns minimum and maximum allowable bounds for routeTax
   */
  function getTaxBounds() external view returns (uint256 minTax, uint256 maxTax);

  //***FUNCTIONS: SETTERS***\\

  /**
   * @dev Opens a new payment route
   * @notice Only a Pazari-owned contract or admin can call
   *
   * @param _recipients Array of all recipient addresses for this payment route
   * @param _commissions Array of all recipients' commissions--in fractions of 10000
   * @param _routeTax Platform tax paid by this route: minTax <= _routeTax <= maxTax
   * @return routeID Hash of the created PaymentRoute
   */
  function openPaymentRoute(
    address[] memory _recipients,
    uint16[] memory _commissions,
    uint16 _routeTax
  ) external returns (bytes32 routeID);

  /**
   * @notice Transfers tokens from _senderAddress to all recipients for the PaymentRoute
   * @notice Only a Pazari-owned contract or admin can call
   *
   * @param _routeID Unique ID of payment route
   * @param _tokenAddress Contract address of tokens being transferred
   * @param _senderAddress Wallet address of token sender
   * @param _amount Amount of tokens being routed
   * @return bool Success bool
   *
   * @dev Emits TransferReceipt event
   */
  function pushTokens(
    bytes32 _routeID,
    address _tokenAddress,
    address _senderAddress,
    uint256 _amount
  ) external returns (bool);

  /**
   * @dev Deposits and sorts tokens for collection, tokens are divided up by each
   * recipient's commission rate for that PaymentRoute
   * @notice Only a Pazari-owned contract or admin can call
   *
   * @param _routeID Unique ID of payment route
   * @param _tokenAddress Contract address of tokens being deposited for collection
   * @param _senderAddress Address of token sender
   * @param _amount Amount of tokens held in escrow by payment route
   * @return success Success boolean
   */
  function holdTokens(
    bytes32 _routeID,
    address _tokenAddress,
    address _senderAddress,
    uint256 _amount
  ) external returns (bool);

  /**
   * @dev Collects all earnings stored in PaymentRouter for msg.sender
   *
   * @param _tokenAddress Contract address of payment token to be collected
   * @return success Success bool
   */
  function pullTokens(address _tokenAddress) external returns (bool);

  /**
   * @notice Toggles a payment route with ID _routeID
   *
   * @dev Emits RouteToggled event
   */
  function togglePaymentRoute(bytes32 _routeID) external;

  /**
   * @notice Adjusts the tax applied to a payment route. Minimum is minTax, and
   * maximum is maxTax.
   *
   * @param _routeID PaymentRoute's routeID
   * @param _newTax New tax applied to route, calculated in fractions of 10000
   *
   * @dev Emits RouteTaxChanged event
   *
   * @dev Developers can alter minTax and maxTax, and the changes will be auto-applied
   * to an item the first time it is purchased.
   */
  function adjustRouteTax(bytes32 _routeID, uint16 _newTax) external returns (bool);

  /**
   * @notice This function allows devs to set the minTax and maxTax global variables
   * @notice Only a Pazari admin can call
   *
   * @dev Emits RouteTaxBoundsChanged
   */
  function adjustTaxBounds(uint16 _minTax, uint16 _maxTax) external view;

  /**
   * @notice Sets the treasury's address
   * @notice Only a Pazari admin can call
   *
   * @dev Emits TreasurySet event
   */
  function setTreasuryAddress(address _newTreasuryAddress)
    external
    returns (
      bool success,
      address oldAddress,
      address newAddress
    );

  /**
   * @notice Sets the maximum number of recipients allowed for a PaymentRoute
   * @dev Does not affect pre-existing routes, only new routes
   *
   * @param _newMax Maximum recipient size for new PaymentRoutes
   * @return (bool, uint8) Success bool, new value for maxRecipients
   */
  function setMaxRecipients(uint8 _newMax, string calldata _memo) external returns (bool, uint8);
}

/**
 * @dev Includes all access control functions for Pazari admins and
 * PaymentRoute management. Uses two types of admins: Pazari admins
 * who have isAdmin, and PaymentRoute admins who have isRouteAdmin.
 * All Pazari admins can access functions restricted to route admins,
 * but route admins cannot access functions restricted to Pazari admins.
 */
interface IAccessControlPR {
  /**
   * @notice Returns tx.origin for any Pazari-owned admin contracts, returns msg.sender
   * for everything else. This only permits Pazari helper contracts to return tx.origin,
   * and all external non-admin contracts and wallets will return msg.sender.
   * @dev This can be used to detect if user is being tricked into a phishing attack.
   * If _msgSender() is different from user's wallet address, then there exists an
   * unauthorized contract between the user and the _msgSender() function. However,
   * there is a context when this is intentional, see next dev entry.
   * @dev This can also be used to create multi-sig contracts that own MarketItems
   * on behalf of multiple owners without any one of them having ownership, and
   * without needing to specify who the owner is at item creation. In this context,
   * _msgSender() will return the address of the multi-sig contract instead of any
   * wallet addresses operating the contract. This feature will be essential for
   * collaboration projects.
   * @dev Returns tx.origin if caller is using a contract with isAdmin. PazariMVP
   * and FactoryPazariTokenMVP require isAdmin with other contracts to function.
   * Marketplace must have isAdmin with PaymentRouter to be able to use it, and
   * PazariMVP must have isAdmin with Marketplace to function and will revert if
   * it doesn't.
   */
  function _msgSender() external view returns (address callerAddress);

  //***PAZARI ADMINS***\\
  // Fires when Pazari admins are added/removed
  event AdminAdded(address indexed newAdmin, address indexed adminAuthorized, string memo, uint256 timestamp);
  event AdminRemoved(
    address indexed oldAdmin,
    address indexed adminAuthorized,
    string memo,
    uint256 timestamp
  );

  // Maps Pazari admin addresses to bools
  function isAdmin(address _adminAddress) external view returns (bool success);

  // Adds an address to isAdmin mapping
  function addAdmin(address _addedAddress, string calldata _memo) external returns (bool success);

  // Removes an address from isAdmin mapping
  function removeAdmin(address _removedAddress, string calldata _memo) external returns (bool success);

  //***PAYMENT ROUTE ADMINS (SELLERS)***\\
  // Fires when route admins are added/removed, returns _msgSender() for callerAdmin
  event RouteAdminAdded(
    bytes32 indexed routeID,
    address indexed newAdmin,
    address indexed adminAuthorized,
    string memo,
    uint256 timestamp
  );
  event RouteAdminRemoved(
    bytes32 indexed routeID,
    address indexed oldAdmin,
    address indexed adminAuthorized,
    string memo,
    uint256 timestamp
  );

  // Returns true if an address is an admin for a routeID
  function isRouteAdmin(bytes32 _routeID, address _adminAddress) external view returns (bool success);

  // Adds an address to isRouteAdmin mapping
  function addRouteAdmin(
    bytes32 _routeID,
    address _newAdmin,
    string memory memo
  ) external returns (bool success);

  // Removes an address from isRouteAdmin mapping
  function removeRouteAdmin(
    bytes32 _routeID,
    address _oldAddress,
    string memory memo
  ) external returns (bool success);
}
