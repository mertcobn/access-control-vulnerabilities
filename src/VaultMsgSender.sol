// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract VaultMsgSender {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function deposit() public payable {}

    function withdraw() public {
        require(msg.sender == owner, "Access denied");
        (bool ok,) = msg.sender.call{value: address(this).balance}("");
        require(ok, "transfer failed");
    }
}
