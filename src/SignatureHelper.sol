// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./MultiSigWallet.sol";

/**
 * @author Sean
 * @title SignatureHelper
 * @notice This is a demo interview contract. Do not use in production!!
 * @custom:disclaimer The language used in this code is for coding convenience
 *                    only, and is not intended to, and does not, have any
 *                    particular legal or regulatory significance.
 */
contract SignatureHelper {
    
    // Type hash for voting (must match the one in MultiSigWallet)
    bytes32 public constant VOTE_TYPEHASH = keccak256("Vote(uint256 proposalId,bool support,uint256 nonce)");
    
    /**
     * @notice Generate the EIP712 hash for a vote
     * @param wallet Address of the MultiSig wallet
     * @param proposalId ID of the proposal
     * @param support Whether voting in support (true) or against (false)
     * @param voter Address of the voter
     * @return hash The EIP712 hash to be signed
     */
    function generateVoteHash(
        address wallet,
        uint256 proposalId,
        bool support,
        address voter
    ) external view returns (bytes32) {
        MultiSigWallet multiSig = MultiSigWallet(payable(wallet));
        
        // Get the current nonce for the voter
        uint256 nonce = multiSig.nonces(voter);
        
        // Get the domain separator from the wallet
        bytes32 domainSeparator = multiSig.getDomainSeparator();
        
        // Create the struct hash
        bytes32 structHash = keccak256(abi.encode(VOTE_TYPEHASH, proposalId, support, nonce));
        
        // Create the final hash according to EIP712
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
    
    /**
     * @notice Verify if a signature is valid for a vote
     * @param wallet Address of the MultiSig wallet
     * @param proposalId ID of the proposal
     * @param support Whether voting in support
     * @param voter Expected signer address
     * @param signature The signature to verify
     * @return isValid Whether the signature is valid
     */
    function verifyVoteSignature(
        address wallet,
        uint256 proposalId,
        bool support,
        address voter,
        bytes memory signature
    ) external view returns (bool) {
        bytes32 hash = this.generateVoteHash(wallet, proposalId, support, voter);
        
        // Recover the signer from the signature
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        address recoveredSigner = recoverSigner(ethSignedHash, signature);
        
        return recoveredSigner == voter;
    }
    
    /**
     * @notice Helper function to recover signer from signature
     * @param hash The hash that was signed
     * @param signature The signature
     * @return signer The recovered signer address
     */
    function recoverSigner(bytes32 hash, bytes memory signature) public pure returns (address) {
        require(signature.length == 65, "Invalid signature length");
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        return ecrecover(hash, v, r, s);
    }
    
    /**
     * @notice Get the current nonce for a voter in a specific wallet
     * @param wallet Address of the MultiSig wallet
     * @param voter Address of the voter
     * @return nonce Current nonce
     */
    function getVoterNonce(address wallet, address voter) external view returns (uint256) {
        MultiSigWallet multiSig = MultiSigWallet(payable(wallet));
        return multiSig.nonces(voter);
    }
    
    /**
     * @notice Get the domain separator for a specific wallet
     * @param wallet Address of the MultiSig wallet
     * @return domainSeparator The EIP712 domain separator
     */
    function getDomainSeparator(address wallet) external view returns (bytes32) {
        MultiSigWallet multiSig = MultiSigWallet(payable(wallet));
        return multiSig.getDomainSeparator();
    }
} 