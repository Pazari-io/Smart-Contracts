// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* Import lib */
import "./Users.sol";
import "../utils/Hevm.sol";
import "../utils/MockContract.sol";
import "../utils/DSTestExtended.sol";

/* Import contracts */
import {Marketplace} from "contracts/Marketplace/Marketplace.sol";

//solhint-disable state-visibility
contract PazariSetup is DSTestExtended {
    //Hevm setup
    Hevm internal constant HEVM = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    Alice alice;
    Bob bob;
    Dev dev;

    function setUp() public virtual {
        //Set timestamp to 0
        HEVM.warp(0);

        //Setup users
        alice = new Alice();
        bob = new Bob();
        dev = new Dev();
    }
}
