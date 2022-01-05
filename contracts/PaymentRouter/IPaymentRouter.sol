// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPaymentRouter {

  // Fires when a new payment route is created
  event RouteCreated(address indexed creator, bytes32 routeID, address[] recipients, uint16[] commissions);

  // Fires when a route creator changes route tax
  event RouteTaxChanged(bytes32 routeID, uint16 newTax);

  // Fires when tokens are deposited into a payment route for holding
  event TokensHeld(bytes32 routeID, address tokenAddress, uint256 amount);

  // Fires when tokens are collected from holding by a recipient
  event TokensCollected(address indexed recipient, address tokenAddress, uint256 amount);

  // Fires when route is actived or deactivated
  event RouteToggled(bytes32 indexed routeID, bool isActive, uint256 timestamp);

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


  /**
   * Returns the properties of a PaymentRoute struct for _routeID
   */
  function paymentRouteID(bytes32 _routeID)
    external
    view
    returns (
      address,
      uint16,
      bool
    );

  /**
   * @dev Returns a balance of tokens/stablecoins ready for collection
   *
   * @param _recipientAddress Address of recipient who can collect tokens
   * @param _tokenContract Contract address of tokens/stablecoins to be collected
   */
  function tokenBalanceToCollect(
    address _recipientAddress,
    address _tokenContract
    ) external view returns (uint256);

  /**
   * @dev Returns an array of all routeIDs created by an address
   */
  function creatorRoutes(
    address _creatorAddress
    ) external view returns (bytes32[] memory);

  /**
   *
   */
  function pushTokens(
    bytes32 _routeID,
    address _tokenAddress,
    address _senderAddress,
    uint256 _amount
  ) external returns (bool);

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
   */
  function pullTokens(
    address _tokenAddress
  ) external returns (bool);

  /**
   * @dev Opens a new payment route
   *
   * @param _recipients Array of all recipient addresses for this payment route
   * @param _commissions Array of all recipients' commissions--in percentages with two decimals
   * @return routeID Hash of the created PaymentRoute
   */
  function openPaymentRoute(
    address[] memory _recipients,
    uint16[] memory _commissions,
    uint16 _routeTax
  ) external returns (bytes32 routeID);
}
