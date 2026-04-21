// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RoleVaultVulnerable is AccessControl {
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(address withdrawer, address minter) {
        _grantRole(WITHDRAWER_ROLE, withdrawer);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function deposit() public payable {}

    function withdraw() public {
        (bool ok,) = msg.sender.call{value: address(this).balance}("");
        require(ok, "Transfer failed");
    }

    function mint() public onlyRole(MINTER_ROLE) {}
}
