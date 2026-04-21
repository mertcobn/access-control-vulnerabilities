// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

import {VaultFixed} from "src/VaultFixed.sol";
import {VaultVulnerable} from "src/VaultVulnerable.sol";

import {PhishingAttacker} from "src/PhishingAttacker.sol";
import {VaultMsgSender} from "src/VaultMsgSender.sol";
import {VaultTxOrigin} from "src/VaultTxOrigin.sol";

import {RoleVault} from "src/RoleVault.sol";
import {RoleVaultVulnerable} from "src/RoleVaultVulnerable.sol";

import {InitVaultVulnerable} from "src/InitVaultVulnerable.sol";
import {InitVaultFixed} from "src/InitVaultFixed.sol";

contract AccessControlTest is Test {
    VaultFixed public vaultFixed;
    VaultVulnerable public vaultVulnerable;

    VaultTxOrigin public vaultTxOrigin;
    PhishingAttacker public phishingAttacker;
    PhishingAttacker public phishingAttackerFailed;
    VaultMsgSender public vaultMsgSender;

    RoleVault public roleVault;
    RoleVaultVulnerable public roleVaultVulnerable;

    InitVaultVulnerable public initVaultVulnerable;
    InitVaultFixed public initVaultFixed;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address dave = makeAddr("dave");
    address eve = makeAddr("eve");
    address attacker = makeAddr("attacker");

    function setUp() public {
        vaultFixed = new VaultFixed();
        vaultVulnerable = new VaultVulnerable();

        vm.prank(dave);
        vaultTxOrigin = new VaultTxOrigin();

        vm.prank(dave);
        vaultMsgSender = new VaultMsgSender();

        phishingAttacker = new PhishingAttacker(address(vaultTxOrigin));
        phishingAttackerFailed = new PhishingAttacker(address(vaultMsgSender));

        vm.prank(eve);
        roleVault = new RoleVault(eve, alice);

        vm.prank(eve);
        roleVaultVulnerable = new RoleVaultVulnerable(eve, alice);

        initVaultVulnerable = new InitVaultVulnerable();
        initVaultFixed = new InitVaultFixed();

        vm.deal(alice, 5 ether);
        vm.deal(bob, 2 ether);
        vm.deal(charlie, 2 ether);
        vm.deal(dave, 1 ether);
        vm.deal(eve, 5 ether);

        vm.prank(alice);
        vaultFixed.deposit{value: 1 ether}();
        vm.prank(bob);
        vaultFixed.deposit{value: 1 ether}();
        vm.prank(charlie);
        vaultFixed.deposit{value: 1 ether}();

        vm.prank(alice);
        vaultVulnerable.deposit{value: 1 ether}();
        vm.prank(bob);
        vaultVulnerable.deposit{value: 1 ether}();
        vm.prank(charlie);
        vaultVulnerable.deposit{value: 1 ether}();
    }

    function test_VulnerableVault_AnyoneCanDrain() public {
        vm.prank(attacker);
        vaultVulnerable.withdraw();
        assertEq(attacker.balance, 3 ether);
        assertEq(address(vaultVulnerable).balance, 0);
    }

    function test_FixedVault_OnlyOwnerCanWithdraw() public {
        vm.prank(attacker);
        vm.expectRevert("Access denied");
        vaultFixed.withdraw();
        uint256 before = address(this).balance;
        vaultFixed.withdraw();
        assertEq(address(this).balance - before, 3 ether);
    }

    function test_TxOrigin_PhishingDrainsVault() public {
        vm.prank(dave);
        vaultTxOrigin.deposit{value: 1 ether}();

        vm.prank(dave, dave);
        phishingAttacker.claimAirDrop();

        assertEq(dave.balance, 1 ether);
        assertEq(address(vaultTxOrigin).balance, 0);
    }

    function test_MsgSender_PhishingReverts() public {
        vm.prank(dave);
        vm.expectRevert();
        phishingAttackerFailed.claimAirDrop();
    }

    function test_RoleVaultVulnerable_AnyoneCanDrain() public {
        vm.prank(eve);
        roleVaultVulnerable.deposit{value: 5 ether}();

        vm.prank(attacker);
        roleVaultVulnerable.withdraw();

        assertEq(attacker.balance, 5 ether);
    }

    function test_RoleVault_OnlyWithdrawerCanWithdraw() public {
        vm.prank(eve);
        roleVault.deposit{value: 5 ether}();

        vm.prank(alice);
        vm.expectRevert();
        roleVault.withdraw();

        vm.prank(eve);
        roleVault.withdraw();

        assertEq(eve.balance, 5 ether);
    }

    function test_InitVaultVulnerable_AnyoneCanTakeOwnership() public {
        vm.prank(eve);
        initVaultVulnerable.initialize();

        vm.prank(eve);
        initVaultVulnerable.deposit{value: 5 ether}();

        vm.prank(attacker);
        initVaultVulnerable.initialize();

        vm.prank(attacker);
        initVaultVulnerable.withdraw();

        assertEq(attacker.balance, 5 ether);
        assertEq(address(initVaultVulnerable).balance, 0);
    }

    function test_InitVaultFixed_CannotReinitialize() public {
        vm.prank(eve);
        initVaultFixed.initialize();

        vm.prank(attacker);
        vm.expectRevert();
        initVaultFixed.initialize();
    }

    receive() external payable {}
    fallback() external payable {}
}
