// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./MultiSigWallet.sol";

/**
 * @author Sean
 * @title MultiSigWalletFactory
 * @notice This is a demo interview contract. Do not use in production!!
 * @custom:disclaimer The language used in this code is for coding convenience
 *                    only, and is not intended to, and does not, have any
 *                    particular legal or regulatory significance.
 */
contract MultiSigWalletFactory {
    using Clones for address;

    // Implementation contract address
    address public immutable implementation;
    
    // Array to track all deployed wallets
    address[] public deployedWallets;
    
    // Mapping to check if an address is a deployed wallet
    mapping(address => bool) public isWallet;

    // Events
    event WalletCreated(
        address indexed wallet,
        address[] signers,
        address indexed creator
    );

    constructor() {
        // Deploy the implementation contract
        implementation = address(new MultiSigWallet());
    }

    /**
     * @notice Create a new MultiSig wallet using minimal proxy pattern
     * @param signers Array of signer addresses
     * @return wallet Address of the newly created wallet
     */
    function createWallet(address[] memory signers) external returns (address) {
        require(signers.length > 0, "At least one signer required");
        
        // Validate signers
        for (uint256 i = 0; i < signers.length; i++) {
            require(signers[i] != address(0), "Invalid signer address");
            
            // Check for duplicates
            for (uint256 j = i + 1; j < signers.length; j++) {
                require(signers[i] != signers[j], "Duplicate signer");
            }
        }

        // Clone the implementation contract
        address wallet = implementation.clone();
        
        // Initialize the cloned contract
        MultiSigWallet(payable(wallet)).initialize(signers);
        
        // Track the deployed wallet
        deployedWallets.push(wallet);
        isWallet[wallet] = true;
        
        emit WalletCreated(wallet, signers, msg.sender);
        
        return wallet;
    }

    /**
     * @notice Create a new MultiSig wallet with deterministic address
     * @param signers Array of signer addresses
     * @param salt Salt for deterministic deployment
     * @return wallet Address of the newly created wallet
     */
    function createWalletDeterministic(
        address[] memory signers,
        bytes32 salt
    ) external returns (address) {
        require(signers.length > 0, "At least one signer required");
        
        // Validate signers
        for (uint256 i = 0; i < signers.length; i++) {
            require(signers[i] != address(0), "Invalid signer address");
            
            // Check for duplicates
            for (uint256 j = i + 1; j < signers.length; j++) {
                require(signers[i] != signers[j], "Duplicate signer");
            }
        }

        // Clone the implementation contract with deterministic address
        address wallet = implementation.cloneDeterministic(salt);
        
        // Initialize the cloned contract
        MultiSigWallet(payable(wallet)).initialize(signers);
        
        // Track the deployed wallet
        deployedWallets.push(wallet);
        isWallet[wallet] = true;
        
        emit WalletCreated(wallet, signers, msg.sender);
        
        return wallet;
    }

    /**
     * @notice Predict the address of a deterministic wallet deployment
     * @param salt Salt for deterministic deployment
     * @return predicted The predicted address
     */
    function predictDeterministicAddress(bytes32 salt) external view returns (address) {
        return implementation.predictDeterministicAddress(salt);
    }

    /**
     * @notice Get the number of deployed wallets
     * @return count Number of deployed wallets
     */
    function getDeployedWalletsCount() external view returns (uint256) {
        return deployedWallets.length;
    }

    /**
     * @notice Get all deployed wallet addresses
     * @return wallets Array of all deployed wallet addresses
     */
    function getDeployedWallets() external view returns (address[] memory) {
        return deployedWallets;
    }

    /**
     * @notice Get deployed wallets with pagination
     * @param offset Starting index
     * @param limit Maximum number of wallets to return
     * @return wallets Array of wallet addresses
     */
    function getDeployedWalletsPaginated(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory wallets) {
        require(offset < deployedWallets.length, "Offset out of bounds");
        
        uint256 end = offset + limit;
        if (end > deployedWallets.length) {
            end = deployedWallets.length;
        }
        
        wallets = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            wallets[i - offset] = deployedWallets[i];
        }
    }

    /**
     * @notice Get wallet info including signers
     * @param wallet Address of the wallet
     * @return signers Array of signer addresses
     * @return signerCount Number of signers
     * @return nextProposalID Next proposal ID to be assigned
     */
    function getWalletInfo(address wallet) external view returns (
        address[] memory signers,
        uint256 signerCount,
        uint256 nextProposalID
    ) {
        require(isWallet[wallet], "Not a deployed wallet");
        
        MultiSigWallet multiSig = MultiSigWallet(payable(wallet));
        signers = multiSig.getSigners();
        signerCount = multiSig.getSignerCount();
        nextProposalID = multiSig.nextProposalID();
    }
} 