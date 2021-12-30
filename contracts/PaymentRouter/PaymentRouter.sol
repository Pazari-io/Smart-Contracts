// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "../Dependencies/Address.sol";
import "../Dependencies/Context.sol";
import "../Dependencies/IERC20.sol";

contract PaymentRouter is Context {
  // ****PAYMENT ROUTES****

  // Fires when a new payment route is created
  event RouteCreated(address indexed creator, bytes32 routeID, address[] recipients, uint16[] commissions);

  // Fires when a route creator changes route tax
  event RouteTaxChanged(bytes32 routeID, uint16 newTax);

  // Tax rate paid by a route
  // route ID => tax rate
  //mapping(bytes32 => uint16) public routeTax;

  // Min and max tax rates that routes must meet
  uint16 public minTax;
  uint16 public maxTax;

  // Mapping for route ID to route data
  // route ID => payment route
  mapping(bytes32 => PaymentRoute) public paymentRouteID;

  // Mapping of all routeIDs created by a route creator address
  // creator's address => routeIDs
  mapping(address => bytes32[]) public creatorRoutes;

  // Struct that defines a new PaymentRoute
  struct PaymentRoute {
    address routeCreator; // Address of payment route creator
    address[] recipients; // Recipients in this payment route
    uint16[] commissions; // Commissions for each recipient--in fractions of 10000
    uint16 routeTax; // Tax paid by this route
    bool isActive; // Is route currently active?
  }

  // ****PUSH FUNCTIONS****

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

  // Mapping of ERC20 tokens that failed a push-transfer and are being held for recipient
  // recipient address => token address => held tokens
  mapping(address => mapping(address => uint256)) internal failedTokens;

  // ****PULL FUNCTIONS****

  // Mapping for total balance of tokens that are currently being held by a payment route
  // route ID => token address => token balance
  mapping(bytes32 => mapping(address => uint256)) internal routeTokenBalance;

  // Mapping for amount of tokens that have been released from holding by a payment route
  // route ID => token address => amount released
  mapping(bytes32 => mapping(address => uint256)) internal routeTokensReleased;

  // Mapping of tokens released from holding by recipient
  // recipient address => routeID => token address => amount released
  mapping(address => mapping(bytes32 => mapping(address => uint256))) internal recipTokensReleased;

  // Fires when tokens are deposited into a payment route for holding
  event TokensHeld(bytes32 routeID, address tokenAddress, uint256 amount);

  // Fires when tokens are collected from holding by a recipient
  event PaymentReleased(address indexed recipient, bytes32 routeID, address tokenAddress, uint256 amount);

  // ****DEVELOPERS****

  // Address of treasury contract where route taxes will be sent
  address public treasuryAddress;

  // Mapping that tracks if an address is a developer
  // ****REMOVE BEFORE DEPLOYMENT****
  mapping(address => bool) public isDev;

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
   * Requirements to pass this modifier:
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

  // ****DELETE BEFORE DEPLOYMENT****
  function pushTokensTest(
    bytes32 _routeID,
    address _tokenAddress,
    uint256 _amount
  ) external returns (bool) {
    pushTokens(_routeID, _tokenAddress, _amount);
    return true;
  }

  // ****DELETE BEFORE DEPLOYMENT****
  function holdTokensTest(
    bytes32 _routeID,
    address _tokenAddress,
    uint256 _amount
  ) external {
    holdTokens(_routeID, _tokenAddress, _amount);
  }

  /**
   * @dev Checks that the routeTax conforms to required bounds. If routeTax is less
   * than minTax or greater than maxTax then routeTax is updated to minTax or maxTax,
   * depending on which one is triggered by the modifier. This modifier is used by
   * _pushTokens() and _holdTokens() when a payment is made to auto-adjust the
   * routeTax if the developers change it.
   *
   * The only situation this does not cover is when maxTax is raised or minTax is
   * reduced.
   */
  modifier checkRouteTax(bytes32 _routeID) {
    PaymentRoute memory route = paymentRouteID[_routeID];

    // If routeTax doesn't meet minTax/maxTax requirements, then it is updated
    if (route.routeTax < minTax) {
      route.routeTax = minTax;
    }
    // Only sponsored items pay maxTax
    if (route.routeTax > maxTax) {
      route.routeTax = maxTax;
    }
    _;
  }

  /**
   * @dev Internal function to transfer tokens from msg.sender to all recipients[].
   * The size of each payment is determined by commissions[i]/10000, which added up
   * will always equal 10000. The first minTax units are transferred to the treasury. This
   * function is a push design that will incur higher gas costs on the user, but
   * is more convenient for the creators.
   *
   * @param _routeID Unique ID of payment route
   * @param _tokenAddress Contract address of tokens being transferred
   * @param _amount Amount of tokens being routed
   *
   * note If any of the transfers should fail for whatever reason, then the transaction should
   * *not* revert. Instead, it will run _storeFailedTransfer which holds on to the recipient's
   * tokens until they are collected. This also throws the TransferReceipt event.
   */
  function pushTokens(
    bytes32 _routeID,
    address _tokenAddress,
    uint256 _amount
  ) public checkRouteTax(_routeID) returns (bool) {
    require(paymentRouteID[_routeID].isActive, "Error: Route inactive");

    //May not be necessary because this check is already in the ERC20 contract
    require(
      IERC20(_tokenAddress).allowance(_msgSender(), address(this)) >= _amount,
      "Insufficient allowance"
    );

    // Let's make this simpler to access
    PaymentRoute memory route = paymentRouteID[_routeID];

    // Transfer full _amount from buyer to contract
    IERC20(_tokenAddress).transferFrom(_msgSender(), address(this), _amount);

    // Transfer route tax first
    uint256 tax = (_amount * route.routeTax) / 10000;
    uint256 totalAmount = _amount - tax; // Total amount to be transferred after tax
    IERC20(_tokenAddress).transfer(treasuryAddress, tax);

    // Now transfer the commissions
    uint256 payment; // Individual recipient's payment

    // Transfer tokens from contract to route.recipients[i]:
    for (uint256 i = 0; i < route.commissions.length; i++) {
      payment = (totalAmount * route.commissions[i]) / 10000;
      // If transferFrom() fails:
      if (!IERC20(_tokenAddress).transfer(route.recipients[i], payment)) {
        // Emit failure event alerting recipient they have tokens to collect
        // If we want to slim down on events, then use tokensHeld event instead
        emit TransferFailed(_msgSender(), _routeID, payment, block.timestamp, route.recipients[i]);
        // Store tokens in contract for holding until recipient collects them
        _storeFailedTransfer(_tokenAddress, route.recipients[i], payment);
        continue; // Continue to next recipient
      }
    }

    // Emit a TransferReceipt event to all recipients
    emit TransferReceipt(_msgSender(), _routeID, _tokenAddress, totalAmount, tax, block.timestamp);
    return true;
  }

  /**
   * @dev Internal function that accepts ERC20 tokens and escrows them until pulled by payment route recipients
   *
   * @param _routeID Unique ID of payment route
   * @param _amount Amount of tokens held in escrow by payment route
   * @param _tokenAddress Contract address of tokens being escrowed
   * @return success Success boolean
   *
   * note This function automatically pushes tokens to the treasury contract.
   */
  function holdTokens(
    bytes32 _routeID,
    address _tokenAddress,
    uint256 _amount
  ) public checkRouteTax(_routeID) returns (bool) {
    // Calculate treasury's commission from _amount
    uint256 tax = (_amount * paymentRouteID[_routeID].routeTax) / 10000;

    // Increase payment route's token balance by _amount - tax
    routeTokenBalance[_routeID][_tokenAddress] += _amount - tax;

    // Transfer tokens from buyer to this contract
    IERC20(_tokenAddress).transferFrom(_msgSender(), address(this), _amount);

    // Transfer treasury's commission from this contract to treasury contract
    IERC20(_tokenAddress).transfer(treasuryAddress, tax);

    // Fire event alerting recipients they have tokens to collect
    emit TokensHeld(_routeID, _tokenAddress, _amount);
    return true;
  }

  // Stores tokens that failed the push-transfer operation
  function _storeFailedTransfer(
    address _tokenAddress,
    address _recipient,
    uint256 _amount
  ) internal {
    failedTokens[_recipient][_tokenAddress] += _amount;
  }

  // Collects tokens that failed the push-transfer operation
  function collectFailedTransfer(address _tokenAddress) external returns (bool) {
    uint256 amount;
    amount = failedTokens[_msgSender()][_tokenAddress];
    require(IERC20(_tokenAddress).transfer(_msgSender(), amount), "Transfer failed!");

    assert(failedTokens[_msgSender()][_tokenAddress] == 0);
    return true;
  }

  // Maps a recipient's array index value to the routeID and their address
  // routeID => recipient address => array index
  mapping(bytes32 => mapping(address => uint8)) public recipIndex;

  /**
   * @dev Function for pulling held tokens to recipient
   *
   * @param _routeID Payment route ID
   * @param _tokenAddress Contract address of ERC20 tokens
   *
   */
  function pullTokens(bytes32 _routeID, address _tokenAddress) external returns (bool) {
    uint16 commission; // Commission rate for recipient
    address recipient; // Recipient pulling tokens
    uint8 recipIndex_ = recipIndex[_routeID][_msgSender()]; // PaymentRoute array index for recipient

    recipient = paymentRouteID[_routeID].recipients[recipIndex_];
    commission = paymentRouteID[_routeID].commissions[recipIndex_];

    require(recipient != address(0) && commission != 0, "Recipient not found!");

    // The route's current token balance combined with the total amount it has released
    uint256 totalReceived = routeTokenBalance[_routeID][_tokenAddress] +
      routeTokensReleased[_routeID][_tokenAddress];

    // Recipient's due payment
    uint256 payment = ((totalReceived * commission) / 10000) -
      recipTokensReleased[recipient][_routeID][_tokenAddress];

    require(payment != 0, "Recipient is not due payment");

    // Update holding balance mappings
    recipTokensReleased[recipient][_routeID][_tokenAddress] += payment;
    routeTokensReleased[_routeID][_tokenAddress] += payment;
    routeTokenBalance[_routeID][_tokenAddress] -= payment;

    // Call token contract and transfer balance from this contract to recipient
    require(IERC20(_tokenAddress).transfer(msg.sender, payment), "Transfer failed");

    // Emit a PaymentReleased event as a recipient's receipt
    emit PaymentReleased(msg.sender, _routeID, _tokenAddress, payment);
    return true;
  }

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
  ) external newRouteChecks(_recipients, _commissions) returns (bytes32 routeID) {
    // Creates routeID from hashing contents of new PaymentRoute
    routeID = getPaymentRouteID(_msgSender(), _recipients, _commissions);

    // Maps the routeID to the new PaymentRoute
    paymentRouteID[routeID] = PaymentRoute(msg.sender, _recipients, _commissions, _routeTax, true);

    // Maps the routeID to the address that created it, and pushes to creator's routes array
    creatorRoutes[_msgSender()].push(routeID);

    // Assign recipIndex mapping values
    for (uint8 i = 0; i < _recipients.length; i++) {
      recipIndex[routeID][_recipients[i]] = i;
    }

    emit RouteCreated(msg.sender, routeID, _recipients, _commissions);
  }

  /**
   * @dev Closes a payment route with ID _routeID
   */
  function closePaymentRoute(bytes32 _routeID) external onlyCreator(_routeID) {
    paymentRouteID[_routeID].isActive = false;
  }

  /**
   * @dev Function for calculating the routeID of a payment route.
   *
   * @param _routeCreator Address of payment route's creator
   * @param _recipients Array of all commission recipients
   * @param _commissions Array of all commissions relative to _recipients
   */
  function getPaymentRouteID(
    address _routeCreator,
    address[] memory _recipients,
    uint16[] memory _commissions
  ) public pure returns (bytes32 routeID) {
    routeID = keccak256(abi.encodePacked(_routeCreator, _recipients, _commissions));
  }

  /**
   * @dev Returns a list of the caller's created payment routes
   */
  function getMyPaymentRoutes() public view returns (bytes32[] memory) {
    return creatorRoutes[msg.sender];
  }

  /**
   * @dev Adjusts the tax applied to a payment route. Only a route creator should be allowed to
   * change this, and the platform should respond accordingly. In this way, route creators set
   * their own platform taxes, and we cater to those who pay us more.
   *
   * If a route creator chooses to pay a higher tax, then the platform's search algorithm will
   * place items tied to that route higher on the search results.
   *
   * idea If a route creator chooses maxTax then they become a "sponsor" of the platform
   * and receive promotional boosts for the items tied to the route.
   */
  function adjustRouteTax(bytes32 _routeID, uint16 _newTax) external onlyCreator(_routeID) returns (bool) {
    require(_newTax >= minTax, "Minimum tax not met");
    require(_newTax <= maxTax, "Maximum tax exceeded");

    paymentRouteID[_routeID].routeTax = _newTax;
    // Emit event so all recipients can be notified of the routeTax change
    emit RouteTaxChanged(_routeID, _newTax);
    return true;
  }

  /**
   * @dev This function allows us to set the min/max tax bounds that can be set by a creator
   *
   * note As of version 0.1.2 all route taxes will be automatically updated at the moment of
   * purchase if they do not meet the bounds.
   */
  function adjustTaxBounds(uint16 _minTax, uint16 _maxTax) external onlyDev {
    require(_minTax >= 0, "Minimum tax < 0.00%");
    require(_maxTax <= 10000, "Maximum tax > 100.00%");

    minTax = _minTax;
    maxTax = _maxTax;
  }
}
