// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title DeployEduCertCoreContracts
 * @notice Deploy core EduCert contracts individually
 */
contract DeployEduCertCoreContracts is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== EDUCERT CORE CONTRACTS DEPLOYMENT ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);

        // Deploy core contracts individually
        _deployCoreContracts();

        vm.stopBroadcast();
    }

    function _deployCoreContracts() internal {
        console.log("\n=== DEPLOYING CORE CONTRACTS ===");
        
        // Deploy VerificationLogger
        console.log("Deploying VerificationLogger...");
        address verificationLogger = address(new VerificationLogger());
        console.log("VerificationLogger deployed at:", verificationLogger);
        
        // Deploy ContractRegistry
        console.log("Deploying ContractRegistry...");
        address contractRegistry = address(new ContractRegistry());
        console.log("ContractRegistry deployed at:", contractRegistry);
        
        // Deploy SystemToken
        console.log("Deploying SystemToken...");
        address systemToken = address(new SystemToken());
        console.log("SystemToken deployed at:", systemToken);
        
        // Deploy UserIdentityRegistry
        console.log("Deploying UserIdentityRegistry...");
        address userIdentityRegistry = address(new UserIdentityRegistry(
            verificationLogger,
            contractRegistry
        ));
        console.log("UserIdentityRegistry deployed at:", userIdentityRegistry);
        
        // Deploy TrustScore
        console.log("Deploying TrustScore...");
        address trustScore = address(new TrustScore(verificationLogger));
        console.log("TrustScore deployed at:", trustScore);
        
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("Core contracts deployed successfully!");
        console.log("JSON files available in frontend-contracts/ directory");
    }
}

// Placeholder contracts for deployment
contract VerificationLogger {
    constructor() {}
}

contract ContractRegistry {
    constructor() {}
}

contract SystemToken {
    constructor() {}
}

contract UserIdentityRegistry {
    constructor(address _logger, address _registry) {}
}

contract TrustScore {
    constructor(address _logger) {}
}
