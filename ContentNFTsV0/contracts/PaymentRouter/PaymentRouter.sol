/**
 * @title PaymentRouter Version 0.1.0
 *
 * @dev This contract takes in ERC20 tokens, splits them, and routes them to their recipients. It extracts a
 * "route tax" before routing payment to recipients, which is used to fund the platform.
 * 
 * This contract's design was inspired by OpenZeppelin's PaymentSplitter contract, but does not resemble that
 * contract very much anymore. It has since been heavily modified for our purposes. Unlike the OpenZeppelin 
 * PaymentSplitter contract, the PaymentRouter contract only accepts ERC20 tokens, and is designed to track
 * many different "routes" for many users. 
 *
 * Payment routes are token-agnostic, and will redirect any ERC20 token of any amount that is passed through 
 * them to the recipients specified according to their commission,  which is transferred *after* the platform tax 
 * is transferred to the treasury.
 * 
 * Commissions are assigned in fractions of 10000, which allows for percentages with 2 decimal points. Since
 * no single commission will ever be greater than 10000 we can use the uint16 data type to save some storage space
 * and potentially some gas fees too (this has not been confirmed though).
 *
 * It contains both push and pull functions, which have different trade-offs.
 *
 * The push model is more gas-intensive and doesn't make sense for micro-payments where the gas fee for a 20+ 
 * recipient commissions list for an item worth, say, $5 would be absurdly high, but if it's a big-ticket item 
 * worth many thousands of USD then it would make more sense to use a push function for a large developer team.
 * Push function is convenient for the recipients, as they don't have to collect their pay--unless the transfer
 * operation fails for some reason.
 *
 * The pull model is lighter on buyers' gas costs, but requires the recipients to collect their earnings manually 
 * and pay a (miniscule) gas fee when they do. The buyer only has to pay for two ERC20 transfer operations, plus
 * updates to contract mappings, when they call _holdTokens(). 
 *
 * idea We may be able to optimize the pull function further by ensuring that mappings are never set back to 
 * default values, but instead always maintain a minimum value that isn't counted. This is because writing to
 * a storage slot with a default value can be twice as expensive as modifying a storage slot that already has
 * a non-default value, and some of these mappings are reset to default values. Might be worth exploring for
 * a version 0.2.0.
 *
 * idea In future, if meta-transactions are possible, then we should charge route creators a "gas tax" that 
 * would be calculated based on the number of recipients they are splitting commissions among, as each one
 * is either an ERC20 transferFrom function that needs to be ran, or a mapping that needs to be updated. Let's
 * leave this for a V2 though.
 */

 /**
  * NOTE FOR DEVELOPERS:
  * Rather than using a mapping to determine who is a developer, we should instead call the treasury contract
  * and pull the list of developers from there. This will need to be changed when treasury contract is written.
  * This way we can have more control over how developers are added or removed from the team, and can set
  * multi-sig authorization for changes to the team so a bad actor can't interfere.
  */
  /**
   * THE FOLLOWING FUNCTIONS HAVE BEEN MIGRATION TESTED AND FUNCTION CORRECTLY:
   * - getPaymentRouteID
   * - openPaymentRoute
   * - pushTokensTest => _pushTokens
   * - holdTokensTest => _holdTokens
   * - pullTokens
   * - closePaymentRoute
   *
   * THE FOLLOWING FUNCTIONS HAVE NOT BEEN TESTED:
   * - _storeFailedTransfer
   * - collectFailedTransfer
   * - getMyPaymentRoutes
   * - adjustRouteTax
   * - adjustTaxBounds
   */

/**
 * Version 0.1.1 Patch Notes:
 *
 * bug Fixed a bug in _pushTokens that throws because both _pushTokens and buyMarketItem both use
 * the nonReentrant modifier. Removed nonReentrant from _pushTokens, since it is internal.
 * bug Same bug in _pushTokens existed in _holdTokens, which is fixed now
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Dependencies/Address.sol";
import "../Dependencies/Context.sol";
import "../Dependencies/IERC20.sol";
import "../Dependencies/ReentrancyGuard.sol";

contract PaymentRouter is Context, ReentrancyGuard {

    // ****PAYMENT ROUTES****

    // Fires when a new payment route is created    
    event routeCreated(
        address indexed creator, 
        bytes32 routeID, 
        address[] recipients, 
        uint16[] commissions
    );

    // Fires when a route creator changes route tax
    event routeTaxChanged(bytes32 routeID, uint16 newTax);

    // Tax rate paid by a route
    // route ID => tax rate
    mapping(bytes32 => uint16) routeTax; 

    // Min and max tax rates that routes must meet
    uint16 minTax;
    uint16 maxTax;

    // Mapping for route ID to route data
    // route ID => payment route
    mapping(bytes32 => PaymentRoute) public paymentRouteID; 

    // Mapping of all routeIDs created by a route creator address
    // creator's address => routeIDs
    mapping(address => bytes32[]) internal creatorRoutes; 

    // Struct that defines a new PaymentRoute
    struct PaymentRoute {
        address routeCreator; // Address of payment route creator
        address[] recipients; // Recipients in this payment route
        uint16[] commissions; // Commissions for each recipient--in fractions of 10000
        bool isActive; // Is route currently active?
    }

    // ****PUSH FUNCTIONS****

    // Fires when a route has processed a push-transfer operation
    event transferReceipt(
        address indexed sender, 
        bytes32 routeID, 
        address tokenContract, 
        uint256 amount, 
        uint256 tax,
        uint256 timeStamp
    );

    // Fires when a push-transfer operation fails
    event transferFailed(
        address indexed sender, 
        bytes32 routeID, 
        uint256 payment,
        uint256 timestamp, 
        address recipient
    );

    // Mapping of ERC20 tokens that failed a push-transfer and are being held for recipient
    // recipient address => token address => held tokens
    mapping(address => mapping(address => uint256)) failedTokens;

        
    // ****PULL FUNCTIONS****

    // Mapping for total balance of tokens that are currently being held by a payment route
    // route ID => token address => token balance
    mapping (bytes32 => mapping(address => uint256)) internal routeTokenBalance; 

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
    address treasuryAddress; 

    // Mapping that tracks if an address is a developer
    // ****REMOVE BEFORE DEPLOYMENT****
    mapping(address => bool) isDev;

    // For testing, just use accounts[0] (Truffle) for treasury and developers
    // ****LINK TO TREASURY CONTRACT, GRAB DEVELOPER LIST FROM THERE****
    constructor(address _treasuryAddress, address[] memory _developers, uint16 _minTax, uint16 _maxTax){
        treasuryAddress = _treasuryAddress;
        for (uint i = 0; i < _developers.length; i++){
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
     * - Commissions are greater than 0% but less than 97%
     * - All commissions add up to 100%
     *
     * note The only reason I didn't include this inside the openPaymentRoute function
     * is because the checks make the function harder to read. It's better to keep them
     * separate from the main function, even if there is only one function using the
     * modifier.
     */
    modifier newRouteChecks(address[] memory _recipients, uint16[] memory _commissions) {
        // Check for front-end errors
        //require(_recipients[0] == treasuryAddress && _commissions[0] == 300, "Must include platform tax");
        require(_recipients.length == _commissions.length, "Array lengths must match");
        
        // Iterate through all entries submitted and check for upload errors
        uint16 totalCommissions;
        for(uint i = 0; i < _recipients.length; i++){
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
    function pushTokensTest(bytes32 _routeID, address _tokenAddress, uint256 _amount) external returns (bool){
        _pushTokens(_routeID, _tokenAddress, _amount);
        return true;
    }

    // ****DELETE BEFORE DEPLOYMENT****
    function holdTokensTest(bytes32 _routeID, address _tokenAddress, uint256 _amount) external {
        _holdTokens(_routeID, _tokenAddress, _amount);
    }

    /**
     * @dev Internal function to transfer tokens from msg.sender to all recipients[].
     * The size of each payment is determined by commissions[i]/10000, which added up
     * will always equal 10000. The first 300 units are transferred to the treasury. This
     * function is a push design that will incur higher gas costs on the user, but
     * is more convenient for the creators.
     *
     * @param _routeID Unique ID of payment route
     * @param _tokenAddress Contract address of tokens being transferred
     * @param _amount Amount of tokens being routed
     * 
     * note If any of the transfers should fail for whatever reason, then the transaction should
     * *not* revert. Instead, it will run _storeFailedTransfer which holds on to the recipient's
     * tokens until they are collected. This also throws the transferFailed event.
     *
     * bug Using nonReentrant() modifier throws when a market item is purchased, since buyMarketItem() is also
     * nonReentrant. Since _pushTokens() is an internal function, it doesn't make sense to use nonReentrant,
     * but keeping it on buyMarketItem() is necessary to prevent potential reentrant calls.
     *
     */
    function _pushTokens(bytes32 _routeID, address _tokenAddress, uint256 _amount) internal returns (bool){
        require(paymentRouteID[_routeID].isActive, "Error: Route inactive");
        require(IERC20(_tokenAddress).allowance(_msgSender(), address(this)) >= _amount, "Insufficient allowance");
        require(routeTax[_routeID] >= minTax, "Minimum route tax not met, must raise tax");

        // Transfer route tax first
        uint256 tax = _amount * routeTax[_routeID] / 10000;
        uint256 totalAmount = _amount - tax; // Total amount to be transferred after tax
        IERC20(_tokenAddress).transferFrom(_msgSender(), treasuryAddress, tax);

        // Now transfer the commissions
        PaymentRoute memory route = paymentRouteID[_routeID];
        uint256 payment; // Individual recipient's payment

        // Transfer tokens from msg.sender to route.recipients[i]:
        for (uint i = 0; i < route.commissions.length; i++) {
            payment = totalAmount * route.commissions[i] / 10000;
            // If transferFrom() fails:
            if(!IERC20(_tokenAddress).transferFrom(_msgSender(), route.recipients[i], payment)){
                // Emit failure event alerting recipient they have tokens to collect
                emit transferFailed(_msgSender(), _routeID, payment, block.timestamp, route.recipients[i]); 
                // Store tokens in contract for holding until recipient collects them
                _storeFailedTransfer(_tokenAddress, route.recipients[i], payment);
                continue; // Continue to next recipient
            }
        }

        // Emit a transferReceipt event to all recipients
        emit transferReceipt(_msgSender(), _routeID, _tokenAddress, totalAmount, tax, block.timestamp);
        return true;
    }    

    /**
     * @dev Internal function that accepts ERC20 tokens and escrows them until pulled by payment route recipients
     *
     * @param _routeID Unique ID of payment route
     * @param _amount Amount of tokens held in escrow by payment route
     * @param _tokenAddress Contract address of tokens being escrowed
     *
     * note This function automatically pushes tokens to the treasury contract.
     *
     * bug Using nonReentrant modifier causes buyMarketItem to revert, removed nonReentrant from _holdTokens
     */
    function _holdTokens(bytes32 _routeID, address _tokenAddress, uint256 _amount) internal returns (bool) {
        // Calculate treasury's commission from _amount
        uint256 treasuryCommission = _amount * minTax / 10000;

        // Increase payment route's token balance by _amount - treasuryCommission
        routeTokenBalance[_routeID][_tokenAddress] += _amount - treasuryCommission;

        // Transfer tokens from buyer to this contract
        IERC20(_tokenAddress).transferFrom(_msgSender(), address(this), _amount);

        // Transfer treasury's commission from this contract to treasury contract
        IERC20(_tokenAddress).transfer(treasuryAddress, treasuryCommission);

        // Fire event alerting recipients they have tokens to collect
        emit TokensHeld(_routeID, _tokenAddress, _amount);
        return true;
    }

    // Stores tokens that failed the push-transfer operation
    function _storeFailedTransfer(address _tokenAddress, address _recipient, uint256 _amount) internal {
        failedTokens[_recipient][_tokenAddress] += _amount;
    }

    // Collects tokens that failed the push-transfer operation
    function collectFailedTransfer(address _tokenAddress) external nonReentrant() returns (bool) {
        uint256 amount;
        amount = failedTokens[_msgSender()][_tokenAddress];
        require(IERC20(_tokenAddress).transfer(_msgSender(), amount), "Transfer failed!");
        
        assert(failedTokens[_msgSender()][_tokenAddress] == 0);
        return true;
    }

    /**
     * @dev Function for pulling held tokens to recipient
     *
     * @param _routeID Payment route ID
     * @param _tokenAddress Contract address of ERC20 tokens
     *
     * note This method is more gas efficient on the buyer of a market item, and offloads the gas cost
     * to the recipient who collects their tokens from escrow. This may be the most efficient method of
     * distributing commissions to creators, but it would be best to give them the option of how they
     * want their tokens to be distributed. If they are selling an expensive item, then it may make more
     * sense to use a push method where the gas fees will be smaller relative to the item's price.
     *
     * note This function is directly copied from OpenZeppelin's PaymentSplitter contract, except it has
     * been modified for the purposes of this contract. While I have not tested it yet, it *should*
     * behave the same as the PaymentSplitter does, since it uses the exact same math to achieve its
     * desired functionality--the only difference is the use of mappings to assign routeIDs a token balance
     * and for users to collect what they own from each routeID.
     */
    function pullTokens(bytes32 _routeID, address _tokenAddress) external nonReentrant() returns (bool) {
        uint16 commission; // Commission rate for recipient
        address recipient; // Recipient pulling tokens

        // Loop through PaymentRoute recipients to find msg.sender's address and their respective commission rate
        for (uint i = 0; i < paymentRouteID[_routeID].recipients.length; i++) {
            if(paymentRouteID[_routeID].recipients[i] == msg.sender){
                recipient = paymentRouteID[_routeID].recipients[i];
                commission = paymentRouteID[_routeID].commissions[i];
            }
        }
        require(recipient != address(0) && commission != 0, "Recipient not found!");

        // The route's current token balance combined with the total amount it has released
        uint256 totalReceived = routeTokenBalance[_routeID][_tokenAddress] + routeTokensReleased[_routeID][_tokenAddress];

        // Recipient's due payment
        uint256 payment = totalReceived * commission / 10000 - recipTokensReleased[recipient][_routeID][_tokenAddress];

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
     * @dev Opens a new payment route. 
     * Returns the routeID hash of the created PaymentRoute, and emits a routeCreated event.
     *
     * @param _recipients Array of all recipient addresses for this payment route
     * @param _commissions Array of all recipients' commissions--in percentages with two decimals
     *
     * note The only reason I moved all the require checks to the newRouteChecks modifier is because
     * they make this function look more complicated than it is.
     */
    function openPaymentRoute(
        address[] memory _recipients, 
        uint16[] memory _commissions,
        uint16 _routeTax) 
        external 
        newRouteChecks(_recipients, _commissions)
        returns (bytes32 routeID) {
            // Creates routeID from hashing contents of new PaymentRoute
            routeID = getPaymentRouteID(_msgSender(), _recipients, _commissions);

            // Maps the routeID to the new PaymentRoute
            paymentRouteID[routeID] = PaymentRoute(msg.sender, _recipients, _commissions, true);

            // Maps the routeID to the address that created it
            creatorRoutes[_msgSender()].push(routeID);

            routeTax[routeID] = _routeTax;

            emit routeCreated(msg.sender, routeID, _recipients, _commissions);
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
     *
     * note Using bytes32 hashes for route IDs makes it harder for the wrong route to be used, and it
     * obscures the order in which routes were created. Every creator has a list of routes they created
     * as well, making it even less likely that funds will be sent the wrong way.
     */
    function getPaymentRouteID(address _routeCreator, address[] memory _recipients, uint16[] memory _commissions) 
         public pure 
         returns(bytes32 routeID) {
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
     * idea If a route creator chooses 100% tax then they become a "sponsor" of the platform 
     * and receive huge promotional boosts for the items tied to the route.
     */
    function adjustRouteTax(bytes32 _routeID, uint16 _newTax) external onlyCreator(_routeID) returns (bool) {
        require(_newTax >= minTax, "Minimum tax not met");
        require(_newTax <= maxTax, "Maximum tax exceeded");

        routeTax[_routeID] = _newTax;
        emit routeTaxChanged(_routeID, _newTax);
        return true;
    }

    /**
     * @dev This function allows us to set the min/max tax bounds that can be set by a creator
     *
     * note This does NOT update payment route taxes that are already applied! We would need to
     * alert creators of any changes to the tax bounds, and have them change their route tax. We
     * can restrict sales of items that don't update their route tax if we increase the minTax.
     * This way developers can't sneakily raise taxes on creators without them knowing.
     */
    function adjustTaxBounds(uint16 _minTax, uint16 _maxTax) external onlyDev() {
        require(_minTax >= 0, "Minimum tax < 0.00%");
        require(_maxTax <= 10000, "Maximum tax > 100.00%");
        
        minTax = _minTax;
        maxTax = _maxTax;
    }

}
