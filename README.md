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

## Security Features

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
- Signer limit enforcement (maximum 50 signers)

## Features

- **Minimal Proxy Pattern**: Gas-efficient deployment using EIP-1167
- **k-of-n Multi-signature**: Configurable threshold voting system
- **EIP-712 Signatures**: Support for off-chain signature verification
- **EIP-1271 Support**: Contract-based signer compatibility
- **Proposal System**: Comprehensive proposal lifecycle management
- **Multicall Execution**: Execute multiple transactions atomically
- **Signer Management**: Add/remove signers through governance
- **Replay Protection**: Built-in nonce system prevents signature replay attacks

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

## Usage

### 1. Deploy Factory

```solidity
MultiSigWalletFactory factory = new MultiSigWalletFactory();
```

### 2. Create Wallet Instance

```solidity
address[] memory signers = [signer1, signer2, signer3];
address wallet = factory.createWallet(signers);
```

### 3. Create Proposal

```solidity
address[] memory targets = [targetContract];
uint256[] memory values = [0]; // ETH to send
bytes[] memory calldatas = [abi.encodeWithSignature("someFunction()")];
uint256 expiration = block.timestamp + 7 days;

uint256 proposalId = MultiSigWallet(wallet).propose(
    targets,
    values,
    calldatas,
    expiration
);
```

### 4. Vote on Proposal

**Direct voting:**
```solidity
MultiSigWallet(wallet).voteFor(proposalId);
```

**Off-chain signature voting:**
```solidity
// Generate signature off-chain using EIP-712
bytes memory signature = generateEIP712Signature(proposalId, true, voterPrivateKey);

// Submit vote with signature (support=true for yes, false for cancel)
MultiSigWallet(wallet).voteOnBehalfOf(proposalId, voter, true, signature);
```

### 5. Execute Proposal

```solidity
MultiSigWallet(wallet).execute(proposalId);
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

## Example Usage Scenarios

### 1. Treasury Management
```solidity
// Transfer 100 ETH to recipient
address[] memory targets = [recipient];
uint256[] memory values = [100 ether];
bytes[] memory calldatas = [""];
```

### 2. Contract Interaction
```solidity
// Call external contract function
address[] memory targets = [targetContract];
uint256[] memory values = [0];
bytes[] memory calldatas = [abi.encodeWithSignature("mint(address,uint256)", recipient, amount)];
```

### 3. Signer Management
```solidity
// Add new signer
address[] memory targets = [address(wallet)];
uint256[] memory values = [0];
bytes[] memory calldatas = [abi.encodeWithSignature("addSigner(address)", newSigner)];
```

## Gas Considerations & Performance

- **Execution Cost**: Scales with number of targets in proposal
- **Vote Counting**: Scales with historical voter count (not current signer count)
- **Storage Optimization**: 50-signer limit for gas efficiency, minimal proxy pattern for deployment
- **Gas Limits**: Consider transaction gas limits for proposals with many operations

## Testing TODO

### 🏭 Factory Contract Tests
- [ ] **Deployment**
  - [ ] Factory deploys with correct implementation address
  - [ ] Implementation contract is properly initialized (disabled)
- [ ] **Wallet Creation**
  - [ ] Create wallet with valid signers
  - [ ] Reject empty signer array
  - [ ] Reject invalid signer addresses (zero address)
  - [ ] Reject duplicate signers
  - [ ] Reject exceeding MAX_SIGNERS limit
  - [ ] Deterministic wallet creation works correctly
  - [ ] Predicted addresses match actual deployment
- [ ] **Tracking & Queries**
  - [ ] Deployed wallets are tracked correctly
  - [ ] Pagination works for large wallet lists
  - [ ] isWallet mapping accurate
  - [ ] getWalletInfo returns correct data

### 🔐 Core Wallet Functionality Tests

#### Initialization
- [ ] **Valid Initialization**
  - [ ] Initialize with 1 signer
  - [ ] Initialize with maximum signers (50)
  - [ ] Initialize with mixed EOA and contract signers
- [ ] **Invalid Initialization**
  - [ ] Reject double initialization
  - [ ] Reject initialization of implementation contract
  - [ ] Reject invalid signer configurations

#### Signer Management
- [ ] **Adding Signers**
  - [ ] Add signer through governance (self-call)
  - [ ] Reject adding existing signer
  - [ ] Reject adding zero address
  - [ ] Reject exceeding MAX_SIGNERS
  - [ ] Reject non-governance calls
  - [ ] Events emitted correctly
- [ ] **Removing Signers**
  - [ ] Remove signer through governance
  - [ ] Reject removing non-existent signer
  - [ ] Reject removing last signer
  - [ ] Reject non-governance calls
  - [ ] Array cleanup works correctly
  - [ ] Events emitted correctly

### 📋 Proposal Lifecycle Tests

#### Proposal Creation
- [ ] **Valid Proposals**
  - [ ] Create proposal with single target
  - [ ] Create proposal with multiple targets (multicall)
  - [ ] Create proposal with ETH transfers
  - [ ] Create proposal with contract calls
  - [ ] Create proposal with mixed operations
  - [ ] Proposer automatically votes yes
  - [ ] ProposalID increments correctly
- [ ] **Invalid Proposals**
  - [ ] Reject non-signer proposal creation
  - [ ] Reject empty proposal (no targets)
  - [ ] Reject array length mismatches
  - [ ] Reject expired timestamps
  - [ ] Reject invalid target addresses

#### Voting Mechanism
- [ ] **Direct Voting**
  - [ ] Signer can vote for proposal
  - [ ] Signer can cancel their vote
  - [ ] Reject double voting
  - [ ] Reject voting by non-signers
  - [ ] Reject voting on invalid proposals
  - [ ] Reject voting on expired proposals
  - [ ] Vote events emitted correctly
- [ ] **Signature-based Voting**
  - [ ] Valid EIP-712 signature voting
  - [ ] Valid EIP-1271 contract signature voting
  - [ ] Reject invalid signatures
  - [ ] Reject signature replay (nonce protection)
  - [ ] Reject voting for non-signers
  - [ ] Nonce increments correctly
  - [ ] Both support=true/false work correctly

#### Proposal Execution
- [ ] **Successful Execution**
  - [ ] Execute with exactly majority votes
  - [ ] Execute with more than majority votes
  - [ ] Execute multicall proposals atomically
  - [ ] Execute ETH transfer proposals
  - [ ] Execute contract interaction proposals
  - [ ] Anyone can execute approved proposals
- [ ] **Failed Execution**
  - [ ] Reject execution with insufficient votes
  - [ ] Reject execution of expired proposals
  - [ ] Reject execution of already executed proposals
  - [ ] Reject execution of cancelled proposals
  - [ ] All-or-nothing execution (one failure = all revert)

#### Proposal Cancellation
- [ ] **Valid Cancellation**
  - [ ] Proposer can cancel their proposal
  - [ ] Governance can cancel any proposal
- [ ] **Invalid Cancellation**
  - [ ] **CRITICAL**: Reject cancellation by removed proposer (security fix)
  - [ ] Reject cancellation by non-proposer
  - [ ] Reject cancellation of executed proposals
  - [ ] Reject cancellation of already cancelled proposals

### 🔒 Security & Edge Case Tests

#### Access Control
- [ ] **Modifier Verification**
  - [ ] onlySigner blocks non-signers
  - [ ] onlySelf blocks external calls
  - [ ] Functions accessible to correct roles only
- [ ] **Privilege Escalation**
  - [ ] Removed signers cannot vote
  - [ ] **CRITICAL**: Removed signers cannot cancel proposals
  - [ ] Non-signers cannot access restricted functions

#### Signer State Changes Impact
- [ ] **Dynamic Validation**
  - [ ] Execute recalculates valid votes correctly
  - [ ] Removed signer votes don't count toward execution
  - [ ] Re-added signer votes immediately count
  - [ ] Historical vote data preserved correctly
- [ ] **Race Conditions**
  - [ ] Signer removal during active proposals
  - [ ] Multiple concurrent votes
  - [ ] Execution during signer changes

#### Signature Security
- [ ] **EIP-712 Protection**
  - [ ] Domain separator prevents cross-contract replay
  - [ ] Nonce prevents same-transaction replay
  - [ ] Invalid signatures rejected
  - [ ] Signature malleability handled
- [ ] **EIP-1271 Contract Signatures**
  - [ ] Valid contract signatures accepted
  - [ ] Invalid contract signatures rejected
  - [ ] Failed contract calls handled gracefully

#### Numerical & Boundary Conditions
- [ ] **Limits Testing**
  - [ ] Exactly 50 signers (MAX_SIGNERS)
  - [ ] Single signer wallet operations
  - [ ] Maximum proposal targets/values/calldatas
  - [ ] Large ETH values in proposals
- [ ] **Integer Arithmetic**
  - [ ] Majority calculation (> signers.length / 2)
  - [ ] No integer overflow in vote counting
  - [ ] ProposalID increment overflow (unlikely but test)

### 🔄 State Transition Tests
- [ ] **Proposal Status Flow**
  - [ ] NotStarted → Proposed (creation)
  - [ ] Proposed → Executed (execution)
  - [ ] Proposed → Cancelled (cancellation)
  - [ ] Invalid state transitions blocked
- [ ] **Concurrent Operations**
  - [ ] Multiple proposals can exist simultaneously
  - [ ] Voting on multiple proposals
  - [ ] Signer changes during multiple active proposals

### 🌐 Integration & Interaction Tests
- [ ] **External Contract Calls**
  - [ ] ERC20 token transfers
  - [ ] ERC721 NFT operations
  - [ ] Custom contract interactions
  - [ ] Failed external calls handled correctly
- [ ] **Complex Scenarios**
  - [ ] Treasury management workflows
  - [ ] Governance parameter changes
  - [ ] Emergency response procedures
  - [ ] Multi-step protocol interactions

### ⛽ Gas & Performance Tests
- [ ] **Gas Optimization**
  - [ ] Vote counting scales reasonably with history
  - [ ] Execution cost scales with proposal complexity
  - [ ] Storage access patterns optimized
- [ ] **DOS Resistance**
  - [ ] Large yesVoters array doesn't block execution
  - [ ] Many proposals don't affect new proposal creation
  - [ ] Signer removal with large history doesn't fail

### 🧪 Regression & Upgrade Tests
- [ ] **Historical Consistency**
  - [ ] Old proposals maintain correct vote counts
  - [ ] Signer changes don't affect past proposal data
  - [ ] All view functions return consistent data
- [ ] **Proxy Pattern**
  - [ ] Multiple wallet instances work independently
  - [ ] Implementation upgrades don't affect proxies
  - [ ] Factory deployment creates identical bytecode

### 📊 View Function Tests
- [ ] **Data Integrity**
  - [ ] getSigners returns current signers
  - [ ] getProposal returns accurate data
  - [ ] hasVoted reflects actual voting status
  - [ ] getYesVoters includes historical voters
  - [ ] getValidYesVotes counts only current signers
- [ ] **Edge Cases**
  - [ ] Queries on non-existent proposals
  - [ ] Queries after signer changes
  - [ ] Queries on cancelled/executed proposals

### 🎭 Adversarial Testing
- [ ] **Front-running Attacks**
  - [ ] Vote execution race conditions
  - [ ] Signer addition/removal timing attacks
- [ ] **MEV Considerations**
  - [ ] Proposal execution timing
  - [ ] Multi-block attack scenarios
- [ ] **Social Engineering**
  - [ ] Malicious proposal data
  - [ ] Deceptive function calls in proposals

## Dependencies

- OpenZeppelin Contracts v4.9+
  - `@openzeppelin/contracts/proxy/Clones.sol`
  - `@openzeppelin/contracts/utils/cryptography/ECDSA.sol`
  - `@openzeppelin/contracts/utils/cryptography/EIP712.sol`
  - `@openzeppelin/contracts/interfaces/IERC1271.sol`

## License

UNLICENSED
