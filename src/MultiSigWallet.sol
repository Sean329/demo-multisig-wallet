// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @author Sean
 * @title MultiSigWallet
 * @notice This is a demo interview contract. Do not use in production!!
 * @custom:disclaimer The language used in this code is for coding convenience
 *                    only, and is not intended to, and does not, have any
 *                    particular legal or regulatory significance.
 */
contract MultiSigWallet is EIP712, Initializable {
    using ECDSA for bytes32;

    // Proposal statuses
    enum ProposalStatus {
        NotStarted,  // Default state for non-existent proposals
        Proposed,    // Proposal is active and open for voting
        Executed,    // Proposal has been executed
        Cancelled   // Proposal has been cancelled
    }

    // Proposal struct
    //@dev This struct does not need to store the yesCount because the execute function will
    //     always dynamically calculate the validYesVotes to handle the situation where a 
    //     removed signer has voted yes before being removed.
    struct Proposal {
        address proposer;
        uint256 expirationTimestamp;
        address[] yesVoters;  // Array of addresses that voted yes
        mapping(address => bool) hasVotedYes;  // Quick lookup for yes votes
        ProposalStatus status;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
    }

    // Constants
    uint8 public constant MAX_SIGNERS = 50;

    // State variables
    address[] public signers;
    mapping(address => bool) public isSigner;
    uint256 public nextProposalID;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public nonces; // For EIP712 replay protection

    // Events
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer);
    event ProposalCanceled(uint256 indexed proposalId);
    event Voted(uint256 indexed proposalId, address indexed voter);
    event VoteCanceled(uint256 indexed proposalId, address indexed voter);
    event ProposalExecuted(uint256 indexed proposalId);

    // EIP712 type hashes
    bytes32 private constant VOTE_TYPEHASH = keccak256("Vote(uint256 proposalId,bool support,uint256 nonce)");

    modifier onlySigner() {
        require(isSigner[msg.sender], "Not a signer");
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "Only self");
        _;
    }

    constructor() EIP712("MultiSigWallet", "1") {
        // Disable initialization for the implementation contract
        // This prevents the implementation contract itself from being initialized
        _disableInitializers();
    }

    /**
     * @notice Initialize the wallet with the given signers
     * @param _signers Array of signer addresses
     */
    function initialize(address[] memory _signers) external initializer {
        require(_signers.length > 0, "At least one signer required");
        require(_signers.length <= MAX_SIGNERS, "Too many signers");
        
        for (uint256 i = 0; i < _signers.length; i++) {
            require(_signers[i] != address(0), "Invalid signer address");
            require(!isSigner[_signers[i]], "Duplicate signer");
            
            signers.push(_signers[i]);
            isSigner[_signers[i]] = true;
        }
    }

    /**
     * @notice Add a new signer to the wallet
     * @param newSigner The address of the new signer
     * @dev This function is only callable by the wallet itself via the execute function
     */
    function addSigner(address newSigner) external onlySelf {
        require(newSigner != address(0), "Invalid signer address");
        require(!isSigner[newSigner], "Already a signer");
        require(signers.length < MAX_SIGNERS, "Too many signers");
        
        signers.push(newSigner);
        isSigner[newSigner] = true;
        
        emit SignerAdded(newSigner);
    }

    /**
     * @notice Remove a signer from the wallet
     * @param signerToRemove The address of the signer to remove
     * @dev This function is only callable by the wallet itself via the execute function
     */
    function removeSigner(address signerToRemove) external onlySelf {
        require(isSigner[signerToRemove], "Not a signer");
        require(signers.length > 1, "Cannot remove last signer");
        
        isSigner[signerToRemove] = false;
        
        // Remove from signers array
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == signerToRemove) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }
        
        emit SignerRemoved(signerToRemove);
    }

    /**
     * @notice Create a new proposal
     * @param targets Array of target addresses
     * @param values Array of values
     * @param calldatas Array of calldatas
     * @param expirationTimestamp The timestamp when the proposal will expire
     * @return proposalId The ID of the new proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        uint256 expirationTimestamp
    ) external onlySigner returns (uint256) {
        require(targets.length == values.length && values.length == calldatas.length, "Array length mismatch");
        require(targets.length > 0, "Empty proposal");
        require(expirationTimestamp > block.timestamp, "Invalid expiration");

        uint256 proposalId = nextProposalID;
        Proposal storage proposal = proposals[proposalId];
        
        proposal.proposer = msg.sender;
        proposal.expirationTimestamp = expirationTimestamp;
        proposal.yesVoters.push(msg.sender);
        proposal.hasVotedYes[msg.sender] = true;
        proposal.status = ProposalStatus.Proposed;
        proposal.targets = targets;
        proposal.values = values;
        proposal.calldatas = calldatas;

        nextProposalID++;

        emit ProposalCreated(proposalId, msg.sender);
        emit Voted(proposalId, msg.sender);

        return proposalId;
    }

    /**
     * @notice Cancel a proposal
     * @param proposalId The ID of the proposal to cancel
     * @dev This function is only callable by the proposer or the wallet itself via the execute function;
     *      and, canceling a proposal does not revert the nextProposalID which is always incremented.
     */
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Proposed, "Invalid proposal status");
        require(
            (msg.sender == proposal.proposer && isSigner[msg.sender]) ||
            msg.sender == address(this),
            "Only current signer proposer or self can cancel"
        );
        
        proposal.status = ProposalStatus.Cancelled;
        emit ProposalCanceled(proposalId);
    }

    /**
     * @notice Vote on a proposal
     * @param proposalId The ID of the proposal to vote on
     */
    function voteFor(uint256 proposalId) external onlySigner {
        _voteFor(proposalId, msg.sender);
    }

    /**
     * @notice Cancel a vote on a proposal
     * @param proposalId The ID of the proposal to cancel the vote on
     */
    function cancelVoteFor(uint256 proposalId) external onlySigner {
        _cancelVoteFor(proposalId, msg.sender);
    }

    /**
     * @notice Vote on a proposal on behalf of a signer
     * @param proposalId The ID of the proposal to vote on
     * @param voter The address of the signer voting
     * @param support Whether the signer supports the proposal
     * @param signature The signature of the signer
     */
    function voteOnBehalfOf(
        uint256 proposalId,
        address voter,
        bool support,
        bytes memory signature
    ) external {
        require(isSigner[voter], "Voter not a signer");
        
        bytes32 structHash = keccak256(abi.encode(VOTE_TYPEHASH, proposalId, support, nonces[voter]));
        bytes32 hash = _hashTypedDataV4(structHash);
        
        // Try ECDSA first
        address recoveredSigner = hash.recover(signature);
        bool validSignature = false;
        
        if (recoveredSigner == voter) {
            validSignature = true;
        } else {
            // Try EIP1271 for contract signers
            validSignature = _isValidEIP1271Signature(voter, hash, signature);
        }
        
        require(validSignature, "Invalid signature");
        
        // Increment nonce after successful verification
        nonces[voter]++;
        
        if (support) {
            _voteFor(proposalId, voter);
        } else {
            _cancelVoteFor(proposalId, voter);
        }
    }

    /**
     * @notice Execute a proposal
     * @param proposalId The ID of the proposal to execute
     * @dev This function is callable by anyone.
     */
    function execute(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Proposed, "Invalid proposal status");
        require(block.timestamp <= proposal.expirationTimestamp, "Proposal expired");
        
        // Recount valid votes by checking if yes voters are still signers
        uint256 validYesVotes = 0;
        
        // Check each yes voter to see if they're still a valid signer
        for (uint256 i = 0; i < proposal.yesVoters.length; i++) {
            address voter = proposal.yesVoters[i];
            if (isSigner[voter]) {
                validYesVotes++;
            }
            // Note: We don't clean up hasVotedYes mapping to maintain historical consistency
            // and avoid the complexity of array cleanup
        }
        
        // Note: We preserve all voting history for consistency across all proposals
        // Only current signers' votes count toward execution, but historical data remains intact
        
        // Don't update proposal.yesCount to maintain consistency
        // Use real-time calculated validYesVotes for execution check
        require(validYesVotes > signers.length / 2, "Insufficient votes");
        
        // CEI pattern to prevent reentrancy
        proposal.status = ProposalStatus.Executed;
        
        // Execute multicall - all must succeed or all revert
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(proposal.calldatas[i]);
            require(success, "Execution failed");
        }
        
        emit ProposalExecuted(proposalId);
    }

    function _voteFor(uint256 proposalId, address voter) internal {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Proposed, "Invalid proposal status");
        require(block.timestamp <= proposal.expirationTimestamp, "Proposal expired");
        require(!proposal.hasVotedYes[voter], "Already voted yes");
        
        proposal.hasVotedYes[voter] = true;
        proposal.yesVoters.push(voter);
        
        emit Voted(proposalId, voter);
    }

    function _cancelVoteFor(uint256 proposalId, address voter) internal {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Proposed, "Invalid proposal status");
        require(proposal.hasVotedYes[voter], "Has not voted yes");
        
        proposal.hasVotedYes[voter] = false;
        
        // Remove from yesVoters array
        for (uint256 i = 0; i < proposal.yesVoters.length; i++) {
            if (proposal.yesVoters[i] == voter) {
                proposal.yesVoters[i] = proposal.yesVoters[proposal.yesVoters.length - 1];
                proposal.yesVoters.pop();
                break;
            }
        }
        
        emit VoteCanceled(proposalId, voter);
    }

    function _isValidEIP1271Signature(address account, bytes32 hash, bytes memory signature) internal view returns (bool) {
        try IERC1271(account).isValidSignature(hash, signature) returns (bytes4 magicValue) {
            return magicValue == IERC1271.isValidSignature.selector;
        } catch {
            return false;
        }
    }

    // View functions
    function getSigners() external view returns (address[] memory) {
        return signers;
    }

    function getSignerCount() external view returns (uint256) {
        return signers.length;
    }

    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        uint256 expirationTimestamp,
        ProposalStatus status,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.expirationTimestamp,
            proposal.status,
            proposal.targets,
            proposal.values,
            proposal.calldatas
        );
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVotedYes[voter];
    }

    //@dev yesVoters is a historical record of all voters for a proposal, namely,
    //     it is not updated when a signer is removed.
    function getYesVoters(uint256 proposalId) external view returns (address[] memory) {
        return proposals[proposalId].yesVoters;
    }

    function getValidYesVotes(uint256 proposalId) external view returns (uint256) {
        Proposal storage proposal = proposals[proposalId];
        uint256 validYesVotes = 0;
        
        // Count votes from current signers only
        for (uint256 i = 0; i < proposal.yesVoters.length; i++) {
            address voter = proposal.yesVoters[i];
            if (isSigner[voter]) {
                validYesVotes++;
            }
        }
        
        return validYesVotes;
    }

    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function getVoteTypehash() external pure returns (bytes32) {
        return VOTE_TYPEHASH;
    }

    // Allow contract to receive ETH
    receive() external payable {}
} 