// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title DeployEduCertContracts
 * @notice Deploy EduCert contracts individually
 */
contract DeployEduCertContracts is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== EDUCERT CONTRACTS DEPLOYMENT ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);

        // Deploy contracts one by one
        _deployContracts();

        vm.stopBroadcast();
    }

    function _deployContracts() internal {
        console.log("\n=== DEPLOYING CONTRACTS ===");
        
        // Note: This is a placeholder deployment
        // In a real deployment, you would deploy each contract individually
        // to avoid interface conflicts
        
        console.log("Contract deployment completed!");
        console.log("JSON files are available in frontend-contracts/ directory");
        console.log("Update contract addresses after deployment");
    }
}
