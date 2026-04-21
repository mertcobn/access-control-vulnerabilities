# Access Control Vulnerabilities: Proof of Concept & Mitigation Analysis

A Foundry-based demonstration of four common access control vulnerabilities in Solidity smart contracts, each paired with its corresponding mitigation and tested in isolation.

Access control determines who is authorized to call a given function. When these checks are missing or misconfigured, any external account can execute privileged operations — draining funds, reassigning ownership, or hijacking contract upgrades. This repository contains four independent PoCs covering the most critical access control failure modes: missing owner checks, `tx.origin` phishing, missing role modifiers, and unprotected initializer functions.

## PoC #1 — Missing Owner Check

### Vulnerability

The `withdraw()` function in `VaultVulnerable.sol` has no access control. It sends the contract's entire ETH balance to `msg.sender` without verifying who is calling. Any external account can call `withdraw()` and drain all deposited funds in a single transaction.

```solidity
function withdraw() public {
    (bool ok,) = msg.sender.call{value: address(this).balance}("");
    require(ok, "Transfer failed");
}
```

### Mitigation

`VaultFixed.sol` introduces an `owner` state variable set in the constructor. The `withdraw()` function checks `require(owner == msg.sender, "Access denied")` before executing the transfer, restricting access to the deployer.

```solidity
constructor() {
    owner = msg.sender;
}

function withdraw() public {
    require(owner == msg.sender, "Access denied");
    (bool ok,) = owner.call{value: address(this).balance}("");
    require(ok, "Transfer failed");
}
```

## PoC #2 — `tx.origin` Phishing

### Vulnerability

`VaultTxOrigin.sol` uses `tx.origin` instead of `msg.sender` for its owner check. While `msg.sender` reflects the immediate caller, `tx.origin` always returns the EOA (Externally Owned Account) that initiated the entire transaction chain. This distinction opens a phishing vector.

```solidity
require(tx.origin == owner, "Access denied");
```

### Attack Flow

1. The attacker deploys `PhishingAttacker.sol`, a contract with an innocent-looking function such as `claimAirDrop()`.
2. The attacker tricks the vault owner into calling `claimAirDrop()` — for example, through a fake airdrop website.
3. When the owner signs the transaction, the call chain becomes: **Owner (EOA) → PhishingAttacker → VaultTxOrigin**.
4. Inside `VaultTxOrigin.withdraw()`, `tx.origin` returns the owner's address (the EOA that started the chain), not `PhishingAttacker`'s address. The `require(tx.origin == owner)` check passes.
5. The vault's entire balance is transferred to `tx.origin` — the owner — but the withdrawal was triggered by the attacker's contract without the owner's knowledge or intent.

The owner never intended to call `withdraw()`. The attacker exploited the fact that `tx.origin` does not change across contract calls — it always points to the original signer.

### Mitigation

`VaultMsgSender.sol` replaces `tx.origin` with `msg.sender`. In the same attack scenario, `msg.sender` inside `withdraw()` would be `PhishingAttacker`'s address, not the owner. The check fails and the transaction reverts.

```solidity
require(msg.sender == owner);
```

## PoC #3 — Missing Role Modifier (OpenZeppelin AccessControl)

### Vulnerability

`RoleVaultVulnerable.sol` inherits from OpenZeppelin's `AccessControl` and defines roles (`WITHDRAWER_ROLE`, `MINTER_ROLE`), but the `withdraw()` function is missing the `onlyRole` modifier. The roles are properly assigned in the constructor, and `mint()` is correctly protected — but because `withdraw()` has no modifier, anyone can call it and drain the vault.

```solidity
function withdraw() public {
    (bool ok,) = msg.sender.call{value: address(this).balance}("");
    require(ok, "Transfer failed");
}
```

This is a realistic scenario: a developer sets up the role infrastructure correctly but forgets to apply the modifier to one critical function. Partial protection creates a false sense of security.

### Mitigation

`RoleVault.sol` applies `onlyRole(WITHDRAWER_ROLE)` to `withdraw()`. Only addresses that have been explicitly granted `WITHDRAWER_ROLE` by the admin can execute the function. All other callers receive an `AccessControlUnauthorizedAccount` revert.

```solidity
function withdraw() public onlyRole(WITHDRAWER_ROLE) {
    (bool ok,) = msg.sender.call{value: address(this).balance}("");
    require(ok, "Transfer failed");
}
```

Role-based access control also eliminates the single point of failure inherent in single-owner designs. If one role's key is compromised, only the functions guarded by that role are at risk — other privileged operations remain protected.

## PoC #4 — Unprotected Initializer

### Vulnerability

In proxy-based upgradeable contracts, constructors cannot be used because they run during deployment and write to the implementation contract's storage, not the proxy's. Instead, an `initialize()` function is used — a normal public function that acts as the proxy's constructor, called once after deployment via `delegatecall`.

`InitVaultVulnerable.sol` has an `initialize()` function that grants `DEFAULT_ADMIN_ROLE` to `msg.sender`, but it lacks the `initializer` modifier. Because it is a regular public function with no guard, anyone can call it at any time — including after the legitimate owner has already initialized the contract.

```solidity
function initialize() public {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
}
```

An attacker simply calls `initialize()`, becomes the admin, and drains the vault through the now-authorized `withdraw()` function.

### Mitigation

`InitVaultFixed.sol` inherits from OpenZeppelin's `Initializable` and applies the `initializer` modifier. This modifier uses an internal flag to ensure the function can only be called once. Any subsequent call reverts with `InvalidInitialization()`.

```solidity
function initialize() public initializer {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
}
```

## Tests

```bash
forge test -vvv
```

Eight tests validate all four vulnerability/mitigation pairs:

- `test_VulnerableVault_AnyoneCanDrain` — An attacker with no deposits calls `withdraw()` on the unprotected vault and receives all 3 ETH deposited by other users. Confirms the absence of access control allows arbitrary drainage.

- `test_FixedVault_OnlyOwnerCanWithdraw` — An attacker attempts `withdraw()` on the owner-protected vault and receives an "Access denied" revert. The owner then successfully withdraws. Confirms the `require(owner == msg.sender)` check works.

- `test_TxOrigin_PhishingDrainsVault` — The vault owner deposits 1 ETH, then is tricked into calling `claimAirDrop()` on the attacker's phishing contract. The phishing contract calls `vault.withdraw()`, which passes because `tx.origin` matches the owner. The vault is drained. Confirms the `tx.origin` phishing vector is exploitable.

- `test_MsgSender_PhishingReverts` — The same phishing attack is attempted against the `msg.sender`-protected vault. The call reverts because `msg.sender` inside `withdraw()` is the phishing contract, not the owner. Confirms `msg.sender` blocks the phishing vector.

- `test_RoleVaultVulnerable_AnyoneCanDrain` — An attacker with no assigned role calls `withdraw()` on the role-based vault that is missing the `onlyRole` modifier. The attacker drains the vault. Confirms that defining roles without applying modifiers provides no protection.

- `test_RoleVault_OnlyWithdrawerCanWithdraw` — An unauthorized address attempts `withdraw()` on the properly guarded vault and receives an `AccessControlUnauthorizedAccount` revert. The authorized withdrawer then succeeds. Confirms `onlyRole` enforcement.

- `test_InitVaultVulnerable_AnyoneCanTakeOwnership` — The legitimate owner initializes the vault and deposits 5 ETH. An attacker calls `initialize()` again, takes over the admin role, and drains the vault. Confirms that an unprotected initializer allows ownership theft.

- `test_InitVaultFixed_CannotReinitialize` — The legitimate owner initializes the vault. An attacker attempts to call `initialize()` again and receives an `InvalidInitialization()` revert. Confirms the `initializer` modifier prevents re-initialization.

## Historical Context

Access control failures have caused some of the largest losses in blockchain history:

- **Parity Multisig Wallet (July 2017)** — The `initWallet()` function, intended to run only during wallet setup, was left unprotected. An attacker called it on deployed wallets, took ownership, and stole ~$30M in ETH. A white hat group used the same exploit to rescue ~$180M from other vulnerable wallets. Four months later, a user accidentally triggered `selfdestruct` on the shared library contract, permanently freezing ~$300M across 500+ wallets.

- **Ronin Network (March 2022)** — Attackers compromised private keys for 5 of 9 validator nodes, partly due to temporary access permissions that were never revoked. They authorized fraudulent withdrawals of 173,600 ETH and 25.5M USDC (~$624M). The breach went undetected for six days. The attack was later attributed to North Korea's Lazarus Group.

## Access Control Audit Checklist

1. **Check every privileged function.** Identify all functions that move funds, change ownership, modify parameters, pause/unpause, mint, burn, or upgrade. Each must have an explicit access control check.
2. **Verify `msg.sender` is used, never `tx.origin`.** Any use of `tx.origin` for authorization is a phishing vulnerability. Replace with `msg.sender`.
3. **Confirm role coverage.** If using role-based access control, verify that every privileged function has the appropriate `onlyRole` modifier applied — not just some of them.
4. **Audit initializer protection.** For upgradeable contracts, confirm that `initialize()` has the `initializer` modifier and can only be called once. Check that the implementation contract's constructor calls `_disableInitializers()` to prevent direct initialization on the implementation.
5. **Apply least privilege.** Avoid concentrating all permissions in a single owner. Separate roles for distinct operations (withdraw, mint, pause, upgrade) so that a single key compromise does not grant full control.
6. **Check for privilege escalation paths.** Can a low-privilege role grant itself higher privileges? Verify that `grantRole` and `revokeRole` are restricted to the appropriate admin role.
7. **Review temporary permissions.** Any access granted for operational convenience (multi-sig co-signers, migration scripts, deployment helpers) must be revoked after use. Lingering permissions are attack surface.

## References

- [SWC-105: Unprotected Ether Withdrawal](https://swcregistry.io/docs/SWC-105)
- [SWC-115: Authorization through tx.origin](https://swcregistry.io/docs/SWC-115)
- [OpenZeppelin AccessControl](https://docs.openzeppelin.com/contracts/5.x/access-control)
- [OpenZeppelin Initializable](https://docs.openzeppelin.com/contracts/5.x/api/proxy#Initializable)

---

*Built as part of a structured audit training curriculum.*