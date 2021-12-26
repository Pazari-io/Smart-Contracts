@title PaymentRouter Version 0.1.0

@dev This contract takes in ERC20 tokens, splits them, and routes them to their recipients. It extracts a
"route tax" before routing payment to recipients, which is used to fund the platform.

This contract's design was inspired by OpenZeppelin's PaymentSplitter contract, but does not resemble that
contract very much anymore. It has since been heavily modified for our purposes. Unlike the OpenZeppelin
PaymentSplitter contract, the PaymentRouter contract only accepts ERC20 tokens, and is designed to track
many different "routes" for many users.

Payment routes are token-agnostic, and will redirect any ERC20 token of any amount that is passed through
them to the recipients specified according to their commission,  which is transferred after the platform tax
is transferred to the treasury.

Commissions are assigned in fractions of 10000, which allows for percentages with 2 decimal points. Since
no single commission will ever be greater than 10000 we can use the uint16 data type to save some storage space
and potentially some gas fees too (this has not been confirmed though).

It contains both push and pull functions, which have different trade-offs.

The push model is more gas-intensive and doesn't make sense for micro-payments where the gas fee for a 20+
recipient commissions list for an item worth, say, $5 would be absurdly high, but if it's a big-ticket item
worth many thousands of USD then it would make more sense to use a push function for a large developer team.
Push function is convenient for the recipients, as they don't have to collect their pay--unless the transfer
operation fails for some reason.

The pull model is lighter on buyers' gas costs, but requires the recipients to collect their earnings manually
and pay a (miniscule) gas fee when they do. The buyer only has to pay for two ERC20 transfer operations, plus
updates to contract mappings, when they call _holdTokens().

idea We may be able to optimize the pull function further by ensuring that mappings are never set back to
default values, but instead always maintain a minimum value that isn't counted. This is because writing to
a storage slot with a default value can be twice as expensive as modifying a storage slot that already has
a non-default value, and some of these mappings are reset to default values. Might be worth exploring for
a version 0.2.0.

idea In future, if meta-transactions are possible, then we should charge route creators a "gas tax" that
would be calculated based on the number of recipients they are splitting commissions among, as each one
is either an ERC20 transferFrom function that needs to be ran, or a mapping that needs to be updated. Let's
leave this for a V2 though.


NOTE FOR DEVELOPERS:
Rather than using a mapping to determine who is a developer, we should instead call the treasury contract
and pull the list of developers from there. This will need to be changed when treasury contract is written.
This way we can have more control over how developers are added or removed from the team, and can set
multi-sig authorization for changes to the team so a bad actor can't interfere.


THE FOLLOWING FUNCTIONS HAVE BEEN MIGRATION TESTED AND FUNCTION CORRECTLY:
- getPaymentRouteID
- openPaymentRoute
- pushTokensTest => _pushTokens
- holdTokensTest => _holdTokens
- pullTokens
- closePaymentRoute

THE FOLLOWING FUNCTIONS HAVE NOT BEEN TESTED:
- _storeFailedTransfer
- collectFailedTransfer
- getMyPaymentRoutes
- adjustRouteTax
- adjustTaxBounds

Version 0.1.1 Patch Notes:

- bug Fixed a bug in _pushTokens that throws because both _pushTokens and buyMarketItem both use
the nonReentrant modifier. Removed nonReentrant from _pushTokens, since it is internal.
- bug Same bug in _pushTokens existed in _holdTokens, which is fixed now
