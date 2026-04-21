// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract VaultTxOrigin {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function deposit() public payable {}

    function withdraw() public {
        require(tx.origin == owner, "Acces denied");
        (bool ok,) = tx.origin.call{value: address(this).balance}("");
        require(ok, "Transfer failed");
    }
}
