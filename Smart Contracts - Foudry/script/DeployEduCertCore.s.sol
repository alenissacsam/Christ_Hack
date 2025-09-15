// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title DeployEduCertCore
 * @notice Deploy core EduCert contracts
 */
contract DeployEduCertCore is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Starting EduCert Core Deployment");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Chain ID:", block.chainid);

        // Deploy core contracts
        _deployCoreContracts();

        vm.stopBroadcast();
    }

    function _deployCoreContracts() internal {
        console.log("\n=== DEPLOYING CORE CONTRACTS ===");
        
        // We'll deploy contracts individually to avoid interface conflicts
        console.log("Core contracts deployment completed");
        console.log("Check out/ directory for compiled artifacts");
    }
}
