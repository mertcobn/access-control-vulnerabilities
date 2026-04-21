// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract InitVaultFixed is AccessControl, Initializable {
    function initialize() public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function deposit() public payable {}

    function withdraw() public onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool ok,) = msg.sender.call{value: address(this).balance}("");
        require(ok, "Transfer failed");
    }
}
