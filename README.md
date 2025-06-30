# MultiSig Wallet Design & Implementation Doc

A complete implementation of a multi-signature wallet system using the Minimal Proxy Pattern (EIP-1167) with advanced features including EIP-712 signature support and comprehensive proposal management.

## Why Minimal Proxy Pattern?

This wallet service is ideally suited for a factory-based architecture that generates multiple proxy instances executing the same implementation logic. When designing such a system, two primary patterns emerge:

1. **Beacon Proxy Pattern**: Where the factory acts as a beacon, preserving upgradeability for all wallet instances
2. **Minimal Proxy Pattern**: A more lightweight approach that eliminates upgradeability in favor of immutability

Given the requirements of this implementation, the **Minimal Proxy Pattern** was chosen for several key reasons:

**🎯 Inherent Flexibility Reduces Upgrade Necessity**
The wallet's minimalist design already provides tremendous flexibility through its ability to "execute an arbitrary method on an arbitrary contract." This architectural flexibility significantly diminishes the need for future upgrades to the core logic.

**🔒 User Security Preferences**
From a user perspective, once the wallet logic has undergone thorough security audits, the requirement for code immutability typically outweighs the desire for new feature additions through upgrades. Users generally prefer the certainty that their wallet's behavior cannot be changed post-deployment.

**⚡ Gas Efficiency**
The minimal proxy pattern offers superior gas efficiency for deployment, with each wallet instance requiring only ~55 bytes compared to much larger beacon proxy implementations.

**🏗️ Real-World Validation**
This design choice aligns with industry standards - **Gnosis Safe**, one of the most widely adopted multi-signature wallet systems, employs the same minimal proxy architecture, validating this approach's effectiveness in production environments.

By eliminating upgradeability, I prioritize security, transparency, and user trust while maintaining the system's core flexibility through its arbitrary contract execution capabilities.

## Key Design Decisions

### Features

- **Minimal Proxy Pattern**: Gas-efficient deployment using EIP-1167
- **k-of-n Multi-signature**: Configurable threshold voting system
- **EIP-712 Signatures**: Support for off-chain signature verification
- **EIP-1271 Support**: Contract-based signer compatibility
- **Proposal System**: Comprehensive proposal lifecycle management
- **Multicall Execution**: Execute multiple transactions atomically
- **Signer Management**: Add/remove signers through governance
- **Replay Protection**: Built-in nonce system prevents signature replay attacks

### Voting Architecture: Historical Preservation + Dynamic Validation

The system employs a unique approach to vote management that balances data consistency with security:

**Design Philosophy:**
- **Vote History Immutable**: Once cast, votes remain in storage permanently
- **Validation Dynamic**: Execution checks current signer status in real-time
- **Behavior Consistent**: All proposals show the same voting data regardless of when viewed

**Signer Management Impact:**
- **Removed Signers**: Historical votes remain visible but don't count toward execution
- **Re-added Signers**: Previous votes immediately become valid again without re-voting
- **New Signers**: Can vote on existing proposals if not expired

**Why This Approach?**
1. **Data Consistency**: Eliminates confusion between "historical" vs "current" vote counts
2. **Gas Efficiency**: Avoids expensive array cleanup operations
3. **User Experience**: Re-added signers don't need to re-vote on existing proposals
4. **Transparency**: Complete voting history preserved for audit purposes

### System Limitations & Constraints

**Signer Constraints:**
- Maximum of 50 signers per wallet (gas optimization + practical limit)
- Minimum of 1 signer required at all times
- Cannot remove the last remaining signer

**Voting Rules:**
- Only "yes" votes supported (no explicit "no" votes)
- Majority threshold: `> signers.length / 2` (more than half)
- Proposer automatically votes "yes" when creating proposal
- Execution open to anyone once threshold met

**Proposal Management:**
- Auto-incrementing IDs starting from 0
- Cancelled proposals don't revert ID counter
- Expired proposals retain state but cannot execute
- States: NotStarted → Proposed → Executed/Cancelled

## Security Considerations

### Replay Protection
- Each signer has an individual nonce counter
- Nonces prevent signature replay across transactions
- Domain separator prevents cross-contract replay

### Governance Protection
- Only contract itself can modify signers
- Requires majority approval for signer changes
- Prevents unauthorized access to critical functions

### Execution Safety
- All-or-nothing execution (atomic multicall)
- Real-time validation of signer status during execution
- Historical vote preservation with dynamic validity checking
- CEI pattern in the execute() function to prevent reentrancy

## Architecture

### Core Contracts

1. **MultiSigWallet.sol** - Main implementation contract
2. **MultiSigWalletFactory.sol** - Factory for deploying wallet instances
3. **SignatureHelper.sol** - Not part of this take-home assignemnt, but demonstrates utility for offchain EIP-712 signature generation

### Contract Structure

```
MultiSigWalletFactory
├── Creates minimal proxies pointing to MultiSigWallet implementation
├── Tracks all deployed wallets
└── Provides deterministic deployment options

MultiSigWallet (Implementation)
├── Proposal management (create, vote, execute, cancel)
├── Signer management (add/remove through governance)
├── EIP-712 signature verification
├── Multicall execution
└── Replay protection via nonce and domain separator
```

## API Reference

### Proposal Management

- `propose()` - Create new proposal (proposer automatically votes)
- `voteFor()` - Vote yes on proposal
- `cancelVoteFor()` - Remove yes vote from proposal
- `execute()` - Execute approved proposal (anyone can call)
- `cancelProposal()` - Cancel proposal (proposer or governance only)

### Signature-based Voting

- `voteOnBehalfOf()` - Vote using EIP-712/EIP-1271 signature (support parameter controls yes/cancel)

### Signer Management

- `addSigner()` - Add new signer (governance only)
- `removeSigner()` - Remove existing signer (governance only)

### View Functions

- `getSigners()` - Get all current signers
- `getSignerCount()` - Get number of current signers
- `getProposal()` - Get proposal details (without vote counts)
- `hasVoted()` - Check if address voted yes on proposal
- `getYesVoters()` - Get historical list of yes voters (includes removed signers)
- `getValidYesVotes()` - Get current valid yes votes (only current signers)
- `getDomainSeparator()` - Get EIP-712 domain separator

## EIP-712 Signature Structure

```solidity
struct Vote {
    uint256 proposalId;
    bool support;
    uint256 nonce;
}
```

**Domain:**
- name: "MultiSigWallet"
- version: "1"
- chainId: Current chain ID
- verifyingContract: Wallet address

## Testing TODO

### 🏭 Factory Tests
- [ ] Deploy factory with valid implementation
- [ ] Create wallets with 1-50 signers
- [ ] Reject invalid configurations (empty/duplicate signers, >50 limit)
- [ ] Track deployed wallets correctly
- [ ] Deterministic deployment works

### 🔐 Core Functionality Tests

#### Initialization & Signer Management
- [ ] Initialize with valid signer configurations
- [ ] Reject double initialization
- [ ] Add/remove signers through governance only
- [ ] Maintain minimum 1 signer requirement
- [ ] Events emitted correctly

#### Proposal Lifecycle
- [ ] **Creation**: Valid multicall proposals, reject invalid inputs
- [ ] **Voting**: Direct & signature-based voting, prevent double voting
- [ ] **Execution**: Majority threshold (>50%), atomic success/failure
- [ ] **Cancellation**: Proposer & governance can cancel
- [ ] **Expiration**: Expired proposals cannot execute

### 🔒 Critical Security Tests

#### Access Control & Privilege Escalation
- [ ] Removed signers cannot cancel proposals even if he was the proposer
- [ ] onlySigner/onlySelf modifiers work correctly
- [ ] Non-signers blocked from restricted functions
- [ ] Removed signers cannot vote

#### Dynamic Validation & State Changes
- [ ] Execute recalculates valid votes with current signers only
- [ ] Re-added signers' votes immediately count
- [ ] Historical voting data preserved consistently
- [ ] Concurrent signer changes handled safely

#### Signature Security
- [ ] EIP-712 domain separation prevents replay attacks
- [ ] Nonce increments prevent signature reuse
- [ ] EIP-1271 contract signatures validated
- [ ] Invalid signatures rejected

### 🔢 Edge Cases & Boundaries
- [ ] Single signer wallet operations
- [ ] Maximum signers (50) functionality
- [ ] Large proposal payloads
- [ ] Majority calculation edge cases (1-signer, even/odd counts)
- [ ] Proposal ID overflow (theoretical)

### 📋 State & Data Integrity
- [ ] Proposal status transitions (NotStarted → Proposed → Executed/Cancelled)
- [ ] Multiple concurrent proposals
- [ ] View functions return accurate data after state changes
- [ ] Historical consistency across signer changes

## Dependencies

- OpenZeppelin Contracts v4.9+
  - `@openzeppelin/contracts/proxy/Clones.sol`
  - `@openzeppelin/contracts/utils/cryptography/ECDSA.sol`
  - `@openzeppelin/contracts/utils/cryptography/EIP712.sol`
  - `@openzeppelin/contracts/interfaces/IERC1271.sol`

## License

UNLICENSED
