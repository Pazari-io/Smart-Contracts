// WORKING VERSION
/**
 * @dev This version uses an enum to auto-adjust route taxes that want to be
 * always minTax or always maxTax, which is convenient for sellers who want
 * any perks that come with the maxTax or who always want the minTax. That
 * way, if we lower minTax for a promotional period then all routes will
 * have that tax reduced, and when it is raised again then all routes will
 * have the tax raised as well. This was implemented in anticipation that we
 * may raise or lower platform taxes, and when we do it'll cause a ton of
 * revert errors to throw, or it'll cause any sellers running at maxTax to
 * lose their benefits.
 *
 * @dev BIG DOWNSIDE: There is now an enum that is returned from paymentRouteID.
 * However, you don't need the new interface. The old interface will work fine,
 * you just won't be able to see if the route tax is set to Minimum, Maximum,
 * or Custom.
 */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Dependencies/Context.sol";
import "../Dependencies/IERC20.sol";
import "./IPaymentRouter.sol";

contract PaymentRouter is Context {
  // ****PAYMENT ROUTES****

  // Fires when a new payment route is created
  event RouteCreated(
    address indexed creator, 
    bytes32 routeID, 
    address[] recipients, 
    uint16[] commissions
  );

  // Fires when a route creator changes route tax
  event RouteTaxChanged(
    bytes32 routeID, 
    uint16 newTax
  );

  // Fires when a route tax bounds is changed
  event RouteTaxBoundsChanged(
    uint16 minTax, 
    uint16 maxTax
  );

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
  event TokensHeld(
    bytes32 routeID, 
    address tokenAddress, 
    uint256 amount
  );

  // Fires when tokens are collected from holding by a recipient
  event TokensCollected(
    address indexed recipient, 
    address tokenAddress, 
    uint256 amount
  );

  // Fires when a PaymentRoute's isActive property is toggled on or off
  // isActive == true => Route was reactivated
  // isActive == false => Route was deactivated
  event RouteToggled(
    bytes32 indexed routeID, 
    bool isActive, 
    uint256 timestamp
  );

  // Maps available payment token balance per recipient for pull function
  // recipient address => token address => balance available to collect
  mapping(address => mapping(address => uint256)) public tokenBalanceToCollect;

  // Mapping for route ID to route data
  // route ID => payment route
  mapping(bytes32 => PaymentRoute) public paymentRouteID;

  // Mapping of all routeIDs created by a route creator address
  // creator's address => routeIDs
  mapping(address => bytes32[]) public creatorRoutes;

  // Mapping that tracks if an address is a developer
  // ****REMOVE BEFORE DEPLOYMENT****
  mapping(address => bool) public isDev;

  // Struct that defines a new PaymentRoute
  struct PaymentRoute {
    address routeCreator; // Address of payment route creator
    address[] recipients; // Recipients in this payment route
    uint16[] commissions; // Commissions for each recipient--in fractions of 10000
    uint16 routeTax; // Tax paid by this route
    TAXTYPE taxType; // Determines if PaymentRoute auto-adjusts to minTax or maxTax
    bool isActive; // Is route currently active?
  }

  enum TAXTYPE { CUSTOM, MINTAX, MAXTAX }

  // Min and max tax rates that routes must meet
  uint16 public minTax;
  uint16 public maxTax;

  // Address of treasury contract where route taxes will be sent
  address public treasuryAddress;

  // For testing, just use accounts[0] (Truffle) for treasury and developers
  // ****LINK TO TREASURY CONTRACT, GRAB DEVELOPER LIST FROM THERE****
  constructor(
    address _treasuryAddress,
    address[] memory _developers,
    uint16 _minTax,
    uint16 _maxTax
  ) {
    treasuryAddress = _treasuryAddress;
    for (uint256 i = 0; i < _developers.length; i++) {
      isDev[_developers[i]] = true;
    }
    minTax = _minTax;
    maxTax = _maxTax;
    emit RouteTaxBoundsChanged(_minTax, _maxTax);
  }

  /**
   * @dev Modifier to restrict access to the creator of paymentRouteID[_routeID]
   */
  modifier onlyCreator(bytes32 _routeID) {
    require(paymentRouteID[_routeID].routeCreator == msg.sender, "Unauthorized, only creator");
    _;
  }

  // ****REMOVE WHEN TREASURY CONTRACT READY, CHANGE MODIFIER TO FUNCTION CALL TO CHECK DEV STATUS****
  modifier onlyDev() {
    require(isDev[msg.sender], "Only developers can access this function");
    _;
  }

  /**
   * @dev Checks that need to be run when a payment route is created..
   *
   * @dev Requirements to pass this modifier:
   * - _recipients and _commissions arrays must be same length
   * - No recipient is address(0)
   * - Commissions are greater than 0% but less than 100%
   * - All commissions add up to exactly 100%
   */
  modifier newRouteChecks(address[] memory _recipients, uint16[] memory _commissions) {
    // Check for front-end errors
    require(_recipients.length == _commissions.length, "Array lengths must match");
    require(_recipients.length <= 256, "Max recipients exceeded");

    // Iterate through all entries submitted and check for upload errors
    uint16 totalCommissions;
    for (uint8 i = 0; i < _recipients.length; i++) {
      totalCommissions += _commissions[i];
      require(totalCommissions <= 10000, "Commissions cannot add up to more than 100%");
      require(_recipients[i] != address(0), "Cannot burn tokens with payment router");
      require(_commissions[i] != 0, "Cannot assign 0% commission");
      require(_commissions[i] <= 10000, "Cannot assign more than 100% commission");
    }
    require(totalCommissions == 10000, "Commissions don't add up to 100%");
    _;
  }

  /**
   * @notice Checks that the routeTax conforms to required bounds, and updates it if
   * developers change the minTax or maxTax
   *
   * @dev Thanks to TAXTYPE, we can now specify if a PaymentRoute auto-adjusts to the
   * minTax or maxTax bounds when they are adjusted, or retains its custom setting.
   * - If taxType is Custom, then it only needs to be higher than the minTax
   * - If taxType is Minimum, then it is auto-set to minTax
   * - If taxType is Maximum, then it is auto-set to maxTax
   */
  modifier checkRouteTax(bytes32 _routeID) {
    PaymentRoute memory route = paymentRouteID[_routeID];

    // If route tax is set to Custom:
    if(route.taxType != TAXTYPE.MINTAX || route.taxType != TAXTYPE.MAXTAX){
      // If routeTax doesn't meet minTax, then it is set to minTax
      if (route.routeTax < minTax) {
        route.routeTax = minTax;
      }
      _;
    }

    route.taxType == TAXTYPE.MINTAX
      ? paymentRouteID[_routeID].routeTax = minTax
      : paymentRouteID[_routeID].routeTax = maxTax;
    _;
  }

  /**
   * @notice External function to transfer tokens from msg.sender to all payment route recipients.
   *
   * @param _routeID Unique ID of payment route
   * @param _tokenAddress Contract address of tokens being transferred
   * @param _senderAddress Wallet address of token sender
   * @param _amount Amount of tokens being routed
   *
   * @dev Emits TransferReceipt event for all purchases, and emits TransferFailed when ERC20
   * token transfer fails. TransferReceipt is the total amount sent through minus failed transfers.
   * 
   * @dev Whether this or the pull function is used for a PaymentRoute depends on the price of the item
   * versus the number of recipients. Experimentation will be needed to discover what the ratio is for
   * price to recipients.length in order for gas fees to be less than 7% of the item's price. We don't
   * want the platform and gas fees to exceed 10% of the item's listing price.
   */
  function pushTokens(
    bytes32 _routeID,
    address _tokenAddress,
    address _senderAddress,
    uint256 _amount
  ) external checkRouteTax(_routeID) returns (bool) {
    require(paymentRouteID[_routeID].isActive, "Error: Route inactive");

    // Store PaymentRoute struct into local variable
    PaymentRoute memory route = paymentRouteID[_routeID];
    // Transfer full _amount from sender to contract
    IERC20(_tokenAddress).transferFrom(_senderAddress, address(this), _amount);

    // Transfer route tax first
    uint256 tax = (_amount * route.routeTax) / 10000;
    uint256 totalAmount = _amount - tax; // Total amount to be transferred after tax
    IERC20(_tokenAddress).transfer(treasuryAddress, tax);

    // Now transfer the commissions
    uint256 payment; // Individual recipient's payment

    // Transfer tokens from contract to route.recipients[i]:
    for (uint256 i = 0; i < route.commissions.length; i++) {
      payment = (totalAmount * route.commissions[i]) / 10000;
      // If transfer() fails:
      if (!IERC20(_tokenAddress).transfer(route.recipients[i], payment)) {
        // Emit failure event alerting recipient they have tokens to collect
        emit TransferFailed(_msgSender(), _routeID, payment, block.timestamp, route.recipients[i]);
        // Store tokens in contract for holding until recipient collects them
        tokenBalanceToCollect[_senderAddress][_tokenAddress] += payment;
        continue; // Continue to next recipient
      }
    }

    // Emit a TransferReceipt event to all recipients
    emit TransferReceipt(_senderAddress, _routeID, _tokenAddress, totalAmount, tax, block.timestamp);
    return true;
/*
*/
  }

  /**
   * @notice External function that deposits and sorts tokens for collection, tokens are
   * divided up by each recipient's commission rate
   *
   * @param _routeID Unique ID of payment route
   * @param _tokenAddress Contract address of tokens being deposited for collection
   * @param _senderAddress Address of token sender
   * @param _amount Amount of tokens held in escrow by payment route
   * @return success boolean
   *
   * @dev Emits TokensHeld event
   *
   * @dev Although PaymentRouter can fit 256 recipients, I wouldn't advise more than 10 without
   * gas fee testing. Same as pushTokens(), we want to keep all fees and tax under 10% of the
   * item's listing price. Theoretically, holdTokens() should be cheaper to use. If we have 
   * sellers who want PaymentRoutes with more than 10 recipients, then I will create a special
   * smart contract for efficiently handling token distribution that could be used for hundreds 
   * of recipients without hitting the buyer with a huge gas fee (or potentially running out of gas).
   */
  function holdTokens(
    bytes32 _routeID,
    address _tokenAddress,
    address _senderAddress,
    uint256 _amount
  ) external checkRouteTax(_routeID) returns (bool) {
    PaymentRoute memory route = paymentRouteID[_routeID];
    uint256 payment; // Each recipient's payment

    // Calculate platform tax and taxedAmount
    uint256 tax = (_amount * route.routeTax) / 10000;
    uint256 taxedAmount = _amount - tax;

    // Calculate each recipient's payment, add to token balance mapping
    // We + 1 to tokenBalanceToCollect as part of a gas-saving design that saves
    // gas on never allowing the token balance mapping to reach 0, while also
    // not counting against the user's actual token balance.
    for (uint256 i = 0; i < route.commissions.length; i++) {
      if (tokenBalanceToCollect[route.recipients[i]][_tokenAddress] == 0) {
        tokenBalanceToCollect[route.recipients[i]][_tokenAddress] = 1;
      }
      payment = ((taxedAmount * route.commissions[i]) / 10000);
      tokenBalanceToCollect[route.recipients[i]][_tokenAddress] += payment;
    }

    // Transfer tokens from senderAddress to this contract
    IERC20(_tokenAddress).transferFrom(_senderAddress, address(this), _amount);

    // Transfer treasury's commission from this contract to treasuryAddress
    IERC20(_tokenAddress).transfer(treasuryAddress, tax);

    // Fire event alerting recipients they have tokens to collect
    emit TokensHeld(_routeID, _tokenAddress, _amount);
    return true;
  }

  /**
   * @notice Collects all earnings stored in PaymentRouter
   *
   * @param _tokenAddress Contract address of payment token to be collected
   * @return success boolean
   *
   * @dev Emits TokensCollected event
   */
  function pullTokens(address _tokenAddress) external returns (bool) {
    // Store recipient's balance as their payment
    uint256 payment = tokenBalanceToCollect[_msgSender()][_tokenAddress] - 1;
    require(payment > 0, "No payment to collect");

    // Erase recipient's balance
    tokenBalanceToCollect[_msgSender()][_tokenAddress] = 1; // Use 1 for 0 to save on gas

    // Call token contract and transfer balance from this contract to recipient
    require(IERC20(_tokenAddress).transfer(msg.sender, payment), "Transfer failed");

    // Emit a TokensCollected event as a recipient's receipt
    emit TokensCollected(msg.sender, _tokenAddress, payment);
    return true;
  }

  /**
   * @notice Opens a new payment route
   *
   * @param _recipients Array of all recipient addresses for this payment route
   * @param _commissions Array of all recipients' commissions--in percentages with two decimals
   * @param _routeTax Percentage paid to Pazari Treasury (MVP: 0, sets to minTax)
   * @return routeID Hash of the created PaymentRoute
   *
   * @dev Emits RouteCreated event
   */
  function openPaymentRoute(
    address[] memory _recipients,
    uint16[] memory _commissions,
    uint16 _routeTax
  ) external newRouteChecks(_recipients, _commissions) returns (bytes32 routeID) {
    // Creates routeID from hashing contents of new PaymentRoute
    routeID = getPaymentRouteID(_msgSender(), _recipients, _commissions);

    TAXTYPE taxType = TAXTYPE.CUSTOM;

    // Logic for fixing _routeTax to minTax or maxTax values
    // _routeTax = 0 sets to minTax
    // _routeTax = 10000 sets to maxTax
    if (_routeTax == 0) {
      _routeTax = minTax;
      taxType = TAXTYPE.MINTAX;
    }
    if (_routeTax == 10000) {
      _routeTax = maxTax;
      taxType = TAXTYPE.MAXTAX;
    }

    // Maps the routeID to the new PaymentRoute
    paymentRouteID[routeID] = PaymentRoute(msg.sender, _recipients, _commissions, _routeTax, taxType, true);

    // Maps the routeID to the address that created it, and pushes to creator's routes array
    creatorRoutes[_msgSender()].push(routeID);

    emit RouteCreated(msg.sender, routeID, _recipients, _commissions);
  }

  /**
   * @notice Toggles a payment route with ID _routeID
   *
   * @dev Emits RouteToggled event
   */
  function togglePaymentRoute(bytes32 _routeID) external onlyCreator(_routeID) {
    paymentRouteID[_routeID].isActive
      ? paymentRouteID[_routeID].isActive = false
      : paymentRouteID[_routeID].isActive = true;

    // If isActive == true, then route was re-opened, if isActive == false, then route was closed
    emit RouteToggled(_routeID, paymentRouteID[_routeID].isActive, block.timestamp);
  }

  /**
   * @notice Calculates the routeID of a payment route.
   *
   * @param _routeCreator Address of payment route's creator
   * @param _recipients Array of all commission recipients
   * @param _commissions Array of all commissions relative to _recipients
   * @return routeID Calculated routeID
   *
   * @dev RouteIDs are calculated by keccak256(_routeCreator, _recipients, _commissions)
   */
  function getPaymentRouteID(
    address _routeCreator,
    address[] memory _recipients,
    uint16[] memory _commissions
  ) public pure returns (bytes32 routeID) {
    routeID = keccak256(abi.encodePacked(_routeCreator, _recipients, _commissions));
  }

  /**
   * @notice Returns a list of the caller's created payment routes
   *
   * @dev NOT NEEDED FOR MVP
   *
   * @dev Use this when displaying payment routes for a seller to choose from, when
   * they have created more than one route.
   */
  function getMyPaymentRoutes() public view returns (bytes32[] memory) {
    return creatorRoutes[msg.sender];
  }

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

   * @dev The idea here is that post-MVP we will offer perks for sellers who choose to
   * pay higher platform taxes, like free advertising, search engine priority, etc.. The
   * easiest way to reward sellers is by setting "milestones" that are reached when they
   * have paid $X in platform taxes, at which point their item gets a blog/social media
   * post and/or YouTube coverage/interview on Pazari Official. Sellers can choose to
   * pay higher platform taxes to reach these milestones faster, even if there are no
   * extra benefits for doing so.
   */
  function adjustRouteTax(bytes32 _routeID, uint16 _newTax) external onlyCreator(_routeID) returns (bool) {
    // Assume the taxType is custom for now
    TAXTYPE taxType = TAXTYPE.CUSTOM;

    // Logic for fixing _routeTax to minTax or maxTax values
    // _routeTax <= minTax auto-sets to minTax
    // _routeTax == 10001 sets to maxTax
    if (_newTax <= minTax) {
      _newTax = minTax;
      taxType = TAXTYPE.MINTAX;
    }
    if (_newTax > 10000) {
      _newTax = maxTax;
      taxType = TAXTYPE.MAXTAX;
    }
    paymentRouteID[_routeID].routeTax = _newTax;

    // Emit event so all recipients can be notified of the routeTax change
    emit RouteTaxChanged(_routeID, _newTax);
    return true;
  }

  /**
   * @notice This function allows devs to set the minTax and maxTax global variables
   *
   * @dev Emits RouteTaxBoundsChanged
   */
  function adjustTaxBounds(uint16 _minTax, uint16 _maxTax) external onlyDev {
    require(_minTax >= 0, "Minimum tax < 0.00%");
    require(_maxTax <= 10000, "Maximum tax > 100.00%");

    minTax = _minTax;
    maxTax = _maxTax;

    emit RouteTaxBoundsChanged(_minTax, _maxTax);
  }
}
