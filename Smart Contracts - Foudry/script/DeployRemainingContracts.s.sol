// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title DeployRemainingContracts
 * @notice Deploy the remaining 4 contracts individually
 */
contract DeployRemainingContracts is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== DEPLOYING REMAINING CONTRACTS ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Chain ID:", block.chainid);

        // Deploy remaining contracts one by one
        _deployRemainingContracts();

        vm.stopBroadcast();
    }

    function _deployRemainingContracts() internal {
        console.log("\n=== DEPLOYING CONTRACT REGISTRY ===");
        
        // Deploy ContractRegistry
        ContractRegistry contractRegistry = new ContractRegistry();
        console.log("ContractRegistry deployed at:", address(contractRegistry));
        
        console.log("\n=== DEPLOYING SYSTEM TOKEN ===");
        
        // Deploy SystemToken
        SystemToken systemToken = new SystemToken();
        console.log("SystemToken deployed at:", address(systemToken));
        
        console.log("\n=== DEPLOYING USER IDENTITY REGISTRY ===");
        
        // Deploy UserIdentityRegistry with dependencies
        UserIdentityRegistry userRegistry = new UserIdentityRegistry(
            address(0x5e8952e1f68aaf5a789e8a45668acc744507fd78), // VerificationLogger
            address(contractRegistry) // ContractRegistry
        );
        console.log("UserIdentityRegistry deployed at:", address(userRegistry));
        
        console.log("\n=== DEPLOYING TRUST SCORE ===");
        
        // Deploy TrustScore
        TrustScore trustScore = new TrustScore(
            address(0x5e8952e1f68aaf5a789e8a45668acc744507fd78) // VerificationLogger
        );
        console.log("TrustScore deployed at:", address(trustScore));
        
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("All remaining contracts deployed successfully!");
    }
}

// Import the contracts
import "../src/core/ContractRegistry.sol";
import "../src/core/SystemToken.sol";
import "../src/core/UserIdentityRegistry.sol";
import "../src/advanced_features/TrustScore.sol";
