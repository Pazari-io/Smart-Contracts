Patch Notes: PaymentRouter Version 0.2.0

ADDED: Version number as first comment, I would appreciate it if this could be incremented during every
pull request so I can make sure I'm using the correct version for my pull requests. I'm calling this
version 0.2.0 since changes were already made to 0.1.1, and I am making changes on top of those changes
as well as adding some new functionality that should probably constitute a version change.

TO CHANGE: General organization needs some sprucing up, but let's do that in 0.2.1+

BUG: Fixed bug in _pushTokens() that threw a VM error. This had something to do with the way transferFrom()
was being used. I simplified this by first transferring the full amount of the tokens to the contract via
transferFrom(), and then using transfer() for the micro-transfers afterward. This also fixes a hidden bug
that only occurs if a token transfer fails. The tokens would not have transferred from buyer to contract
for holding until collection (is there any situation in which a token transfer would fail anyways?), so
this feature never would have worked.

BUG: Fixed bug in _holdTokens() that used minTax rather than routeTax to calculate platform's tax fee.
This means _holdTokens() would only ever be able to transfer the minTax, and never a custom tax or the
maxTax. Now _holdTokens() calculates its tax the same way _pushTokens() does.

REMOVED: Removed routeTax mapping and added routeTax property to PaymentRoute. Made all necessary adjustments to 
implement this change across all functions that used it. This mapping was unnecessary and a waste of gas.

ADDED: checkRouteTax() modifier, which checks the routeTax against the minTax and maxTax and adjusts them
if they are incorrect. This way no items will get "stuck" on the market because the route creator hasn't
updated the routeTax yet and purchasing the item throws a revert error. Instead, the purchase will go through
anyways but the routeTax will be auto-adjusted. I haven't included an event for this since we already have
a ton of events, but if we can manage it then there should be an event that goes to the route creator so they
know their routeTax got auto-adjusted. This modifier was added to _pullTokens() and _holdTokens().

CHANGED: To improve consistency in variable names, in _holdTokens() treasuryCommission has been changed to
tax in order to match _pushTokens(). This has no effects and is purely cosmetic.

ADDED: recipIndex mapping. This takes in a routeID and a user's address, and returns their index value in
recipients[] and commissions[]. This is to replace the for loop in pullTokens(), which should reduce some
gas costs on the recipients who collect their pay. These gas savings are paid for by the PaymentRoute 
creator at the time of route creation, since they do have to pay for a for-loop that iterates through
recipients[] and maps their addresses to recipIndex. Basically, this trades a repetitive gas expense for
a one-time-only gas expense.

CHANGED: All recipients[] and commissions[] will be capped at length of 256. No team of recipients should
ever get close to being this huge, so it doesn't make sense to use uint256 if it's going to cost more gas
for a feature we will never realistically use. If a team wishes to have more than 256 recipients then we
need to deploy them an ERC20 PaymentSplitter contract that can hold an arbitrary number of recipients,
and have them provide the address of this contract as a recipient in their PaymentRoute. We can do this
later, after MVP is finished and we are ready to expand our smart contract offerings to sellers.

IDEA: We can add an enum that will become a property of PaymentRoute. This enum determines how the routeTax
is factored in. The options would be Custom, Minimum, and Maximum. Custom means the route creator sets the
routeTax, but the routeTax will only auto-adjust if it falls out of bounds with the platform's minTax and
maxTax. Minimum means the routeTax will always be equal to minTax, and will auto-adjust as necessary.
Maximum means the routeTax will always be equal to maxTax, which will be necessary for sponsored items to
maintain their sponsor status if we adjust the maxTax. This addition would increase the flexibility of the
platform for content sellers, since it gives them the option of paying the minimum tax, a custom tax that
provides various rewards for paying more, and a sponsorship tax that takes the majority of earnings in
return for search priority and suggestive selling--which could be useful for helping new content
creators get exposure on Pazari, or for running ad campaigns on-platform.

TO THINK ABOUT: Should we leave our PaymentRoutes open to public visibility? Is there any risk to people's
payment routes being visible to those who know the routeID? I think the platform should have access to a
full list of all routeIDs and their contents so we can comply with investigations into fraud or piracy, but
I also think this list should be kept private and only visible to us. To that end, if we want to increase
privacy for PaymentRoutes then let's also remove the RouteCreated event from openPaymentRoute(), which would
remove the ability for anyone listening to Pazari events to know when new PaymentRoutes are created (at least
through listening to events). The privacy of the content sellers should be respected as much as possible,
while maintaining our ability to assist with investigations into illegal content. However, if everything is
made public then it may discourage illegal activity on Pazari anyways, but it might also make sellers less
willing to sell on Pazari as well. This level of transparency is unprecedented in Web2, and it's something
we need to consider carefully before going to full production.

