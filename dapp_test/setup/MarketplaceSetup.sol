// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* Import lib */
import "../utils/Hevm.sol";
import "../utils/MockContract.sol";
import "../utils/DSTestExtended.sol";

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

/* Import contracts */
import {Marketplace} from "contracts/Marketplace/Marketplace.sol";
import {ERC1155PresetMinterPauser} from "contracts/Dependencies/ERC1155PresetMinterPauser.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract NFTHolder is ERC721Holder, ERC1155Holder {}

contract Treasury is NFTHolder {}

contract Dev is NFTHolder {}

contract User is NFTHolder {}

//solhint-disable state-visibility
contract MarketplaceSetup is DSTestExtended, NFTHolder {
    //Hevm setup
    Hevm internal constant HEVM = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    //Users
    Dev[] devs;
    User[] users;
    address[] devsAddr;
    address[] usersAddr;

    //Treasury
    Treasury treasury;

    //Contracts
    Marketplace marketplace;
    ERC1155PresetMinterPauser[] erc1155s;
    ERC20PresetMinterPauser[] erc20s;

    //Need this to receive ETH
    receive() external payable {}

    function setUp(uint8 numDevs, uint16 numUsers) public virtual {
        //Set timestamp to 0
        HEVM.warp(0);

        //Setup treasury
        treasury = new Treasury();

        //Setup accounts
        for (uint256 i = 0; i < numDevs; i++) {
            devs.push(new Dev());
            devsAddr.push(address(devs[i]));
        }
        for (uint256 i = 0; i < numUsers; i++) {
            users.push(new User());
            usersAddr.push(address(users[i]));
        }
    }

    function marketplaceDeploy(uint16 minTax, uint16 maxTax) public virtual {
        marketplace = new Marketplace(address(treasury), devsAddr, minTax, maxTax);
    }

    function erc1155Deploy(uint8 amount) public virtual {
        for (uint256 i = 0; i < amount; i++) {
            erc1155s.push(new ERC1155PresetMinterPauser());
        }
    }

    function erc20Deploy(uint8 amount) public virtual {
        for (uint256 i = 0; i < amount; i++) {
            erc20s.push(new ERC20PresetMinterPauser("abc", "ABC"));
        }
    }

    function erc1155Mint(
        uint8 index,
        address to,
        uint256 id,
        uint256 amount
    ) public virtual {
        string memory uri = "https://api.pazari.io/metadata/";
        bytes memory data = "0x";
        if (index < erc1155s.length) {
            erc1155s[index].mint(to, id, amount, uri, data);
        }
    }

    function erc20Mint(
        uint8 index,
        address to,
        uint256 amount
    ) public virtual {
        if (index < erc20s.length) {
            erc20s[index].mint(to, amount);
        }
    }
}
