//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract VaultVulnerable {
    function deposit() public payable {}

    function withdraw() public {
        (bool ok,) = msg.sender.call{value: address(this).balance}("");
        require(ok, "Transfer failed");
    }
}
