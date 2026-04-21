// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract VaultFixed {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function deposit() public payable {}

    function withdraw() public {
        require(owner == msg.sender, "Access denied");
        (bool ok,) = owner.call{value: address(this).balance}("");
        require(ok, "Transfer failed");
    }
}
