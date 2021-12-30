// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPaymentRouter {
  function paymentRouteID(bytes32 _routeID)
    external
    view
    returns (
      address,
      uint16,
      bool
    );

  function pushTokens(
    bytes32 _routeID,
    address _tokenAddress,
    uint256 _amount
  ) external returns (bool);

  function holdTokens(
    bytes32 _routeID,
    address _tokenAddress,
    uint256 _amount
  ) external returns (bool);
}
