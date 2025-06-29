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
└── Replay protection via nonces
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

## Key Functions

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
- Signer limit enforcement (maximum 255 signers)

## Voting Architecture

### Historical Vote Preservation
The system maintains complete voting history for transparency and consistency:

- **Vote History**: Once cast, votes remain in storage permanently
- **Dynamic Validation**: Execution checks current signer status in real-time
- **Consistent Behavior**: All proposals (past and present) show the same voting data

### Signer Management Impact
When signers are added or removed:

- **Removed Signers**: Their historical votes remain visible but don't count toward execution
- **Re-added Signers**: Previous votes immediately become valid again without re-voting
- **New Signers**: Can vote on existing proposals if not expired

This approach ensures data consistency while maintaining security through real-time validation.

## Proposal States

The system uses a streamlined state management approach:

```solidity
enum ProposalStatus {
    NotStarted,  // Default state for non-existent proposals
    Proposed,    // Proposal is active and open for voting
    Executed,    // Proposal has been executed
    Cancelled    // Proposal has been cancelled
}
```

### State Transitions
- **NotStarted → Proposed**: When `propose()` is called
- **Proposed → Executed**: When `execute()` is called with sufficient votes
- **Proposed → Cancelled**: When `cancelProposal()` is called
- **Expired Proposals**: Handled via timestamp checks, not state changes

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

## Important Notes & Limitations

### Signer Limits
- Maximum of 255 signers per wallet (uint8 limitation)
- Minimum of 1 signer required at all times
- Cannot remove the last remaining signer

### Voting Behavior
- Only "yes" votes are supported (no explicit "no" votes)
- Proposer automatically votes "yes" when creating proposal
- Majority threshold is `> signers.length / 2` (more than half)
- Re-added signers' previous votes remain valid without re-voting

### Proposal Management
- Proposals use auto-incrementing IDs starting from 0
- Cancelled proposals don't revert the ID counter
- Expired proposals cannot be executed but retain their state
- Anyone can execute a proposal once it has sufficient valid votes

### Gas Considerations
- Execution cost scales with number of targets in proposal
- Vote counting scales with historical voter count
- Consider gas limits for proposals with many operations

## Dependencies

- OpenZeppelin Contracts v4.9+
  - `@openzeppelin/contracts/proxy/Clones.sol`
  - `@openzeppelin/contracts/utils/cryptography/ECDSA.sol`
  - `@openzeppelin/contracts/utils/cryptography/EIP712.sol`
  - `@openzeppelin/contracts/interfaces/IERC1271.sol`

## License

UNLICENSED
