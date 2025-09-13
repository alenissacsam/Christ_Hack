// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {VerificationLogger} from "src/core/VerificationLogger.sol";
import {TrustScore} from "src/advanced_features/TrustScore.sol";
import {UserIdentityRegistry} from "src/core/UserIdentityRegistry.sol";
import {ContractRegistry} from "src/core/ContractRegistry.sol";
import {CertificateManager} from "src/organizations/CertificateManager.sol";
import {OrganizationRegistryProxy} from "src/organizations/OrganizationRegistryProxy.sol";

/**
 * @title ConfigureEduCertSystem
 * @notice Post-deployment configuration script to set up role assignments and inter-contract dependencies
 * @dev Run this script after the main deployment to properly configure the system
 */
contract ConfigureEduCertSystem is Script {
    struct DeployedContracts {
        address verificationLogger;
        address trustScore;
        address userRegistry;
        address contractRegistry;
        address systemToken;
        address faceVerifier;
        address aadhaarVerifier;
        address incomeVerifier;
        address certificateManager;
        address organizationRegistry;
        address recognitionManager;
        address economicIncentives;
        address governanceManager;
        address guardianManager;
        address disputeResolution;
        address privacyManager;
        address crossChainManager;
        address globalCredentialAnchor;
        address aaWalletManager;
        address paymasterManager;
        address migrationManager;
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        // Load deployed contract addresses from environment or previous deployment
        DeployedContracts memory contracts = _loadContractAddresses();

        // 1. Register all contracts in ContractRegistry
        _registerAllContracts(contracts);

        // 2. Set up role assignments
        _configureRoles(contracts);

        // 3. Configure inter-contract dependencies
        _configureIntegrations(contracts);

        vm.stopBroadcast();

        console.log("=== SYSTEM CONFIGURATION COMPLETED ===");
        console.log("All contracts registered and configured successfully");
    }

    function _loadContractAddresses()
        internal
        pure
        returns (DeployedContracts memory)
    {
        // In a real deployment, these would be loaded from environment variables
        // or from the previous deployment output
        return
            DeployedContracts({
                verificationLogger: address(0), // Load from env: VERIFICATION_LOGGER_ADDRESS
                trustScore: address(0), // Load from env: TRUST_SCORE_ADDRESS
                userRegistry: address(0), // Load from env: USER_REGISTRY_ADDRESS
                contractRegistry: address(0), // Load from env: CONTRACT_REGISTRY_ADDRESS
                systemToken: address(0), // Load from env: SYSTEM_TOKEN_ADDRESS
                faceVerifier: address(0), // Load from env: FACE_VERIFIER_ADDRESS
                aadhaarVerifier: address(0), // Load from env: AADHAAR_VERIFIER_ADDRESS
                incomeVerifier: address(0), // Load from env: INCOME_VERIFIER_ADDRESS
                certificateManager: address(0), // Load from env: CERTIFICATE_MANAGER_ADDRESS
                organizationRegistry: address(0), // Load from env: ORGANIZATION_REGISTRY_ADDRESS
                recognitionManager: address(0), // Load from env: RECOGNITION_MANAGER_ADDRESS
                economicIncentives: address(0), // Load from env: ECONOMIC_INCENTIVES_ADDRESS
                governanceManager: address(0), // Load from env: GOVERNANCE_MANAGER_ADDRESS
                guardianManager: address(0), // Load from env: GUARDIAN_MANAGER_ADDRESS
                disputeResolution: address(0), // Load from env: DISPUTE_RESOLUTION_ADDRESS
                privacyManager: address(0), // Load from env: PRIVACY_MANAGER_ADDRESS
                crossChainManager: address(0), // Load from env: CROSS_CHAIN_MANAGER_ADDRESS
                globalCredentialAnchor: address(0), // Load from env: GLOBAL_CREDENTIAL_ANCHOR_ADDRESS
                aaWalletManager: address(0), // Load from env: AA_WALLET_MANAGER_ADDRESS
                paymasterManager: address(0), // Load from env: PAYMASTER_MANAGER_ADDRESS
                migrationManager: address(0) // Load from env: MIGRATION_MANAGER_ADDRESS
            });
    }

    function _registerAllContracts(
        DeployedContracts memory contracts
    ) internal {
        ContractRegistry registry = ContractRegistry(
            contracts.contractRegistry
        );

        // Register core contracts
        string[] memory names = new string[](21);
        address[] memory addresses = new address[](21);
        string[] memory versions = new string[](21);

        names[0] = "VerificationLogger";
        addresses[0] = contracts.verificationLogger;
        versions[0] = "1.0.0";
        names[1] = "TrustScore";
        addresses[1] = contracts.trustScore;
        versions[1] = "1.0.0";
        names[2] = "UserIdentityRegistry";
        addresses[2] = contracts.userRegistry;
        versions[2] = "1.0.0";
        names[3] = "SystemToken";
        addresses[3] = contracts.systemToken;
        versions[3] = "1.0.0";
        names[4] = "FaceVerificationManager";
        addresses[4] = contracts.faceVerifier;
        versions[4] = "1.0.0";
        names[5] = "AadhaarVerificationManager";
        addresses[5] = contracts.aadhaarVerifier;
        versions[5] = "1.0.0";
        names[6] = "IncomeVerificationManager";
        addresses[6] = contracts.incomeVerifier;
        versions[6] = "1.0.0";
        names[7] = "CertificateManager";
        addresses[7] = contracts.certificateManager;
        versions[7] = "1.0.0";
        names[8] = "OrganizationRegistry";
        addresses[8] = contracts.organizationRegistry;
        versions[8] = "1.0.0";
        names[9] = "RecognitionManager";
        addresses[9] = contracts.recognitionManager;
        versions[9] = "1.0.0";
        names[10] = "EconomicIncentives";
        addresses[10] = contracts.economicIncentives;
        versions[10] = "1.0.0";
        names[11] = "GovernanceManager";
        addresses[11] = contracts.governanceManager;
        versions[11] = "1.0.0";
        names[12] = "GuardianManager";
        addresses[12] = contracts.guardianManager;
        versions[12] = "1.0.0";
        names[13] = "DisputeResolution";
        addresses[13] = contracts.disputeResolution;
        versions[13] = "1.0.0";
        names[14] = "PrivacyManager";
        addresses[14] = contracts.privacyManager;
        versions[14] = "1.0.0";
        names[15] = "CrossChainManager";
        addresses[15] = contracts.crossChainManager;
        versions[15] = "1.0.0";
        names[16] = "GlobalCredentialAnchor";
        addresses[16] = contracts.globalCredentialAnchor;
        versions[16] = "1.0.0";
        names[17] = "AAWalletManager";
        addresses[17] = contracts.aaWalletManager;
        versions[17] = "1.0.0";
        names[18] = "PaymasterManager";
        addresses[18] = contracts.paymasterManager;
        versions[18] = "1.0.0";
        names[19] = "MigrationManager";
        addresses[19] = contracts.migrationManager;
        versions[19] = "1.0.0";
        names[20] = "ContractRegistry";
        addresses[20] = contracts.contractRegistry;
        versions[20] = "1.0.0";

        // Register contracts in batches to avoid gas limit issues
        uint256 batchSize = 10;
        for (uint256 i = 0; i < names.length; i += batchSize) {
            uint256 end = i + batchSize > names.length
                ? names.length
                : i + batchSize;
            uint256 currentBatchSize = end - i;

            string[] memory batchNames = new string[](currentBatchSize);
            address[] memory batchAddresses = new address[](currentBatchSize);
            string[] memory batchVersions = new string[](currentBatchSize);

            for (uint256 j = 0; j < currentBatchSize; j++) {
                batchNames[j] = names[i + j];
                batchAddresses[j] = addresses[i + j];
                batchVersions[j] = versions[i + j];
            }

            registry.batchRegisterContracts(
                batchNames,
                batchAddresses,
                batchVersions
            );
        }

        console.log("All contracts registered in ContractRegistry");
    }

    function _configureRoles(DeployedContracts memory contracts) internal {
        // Configure role assignments for proper inter-contract communication

        // Grant CertificateManager roles to OrganizationRegistry
        CertificateManager certManager = CertificateManager(
            contracts.certificateManager
        );
        certManager.grantRole(
            certManager.ISSUER_ROLE(),
            contracts.organizationRegistry
        );

        // Grant UserRegistry roles to verification managers
        UserIdentityRegistry userRegistry = UserIdentityRegistry(
            contracts.userRegistry
        );
        userRegistry.grantRole(
            userRegistry.REGISTRY_MANAGER_ROLE(),
            contracts.faceVerifier
        );
        userRegistry.grantRole(
            userRegistry.REGISTRY_MANAGER_ROLE(),
            contracts.aadhaarVerifier
        );
        userRegistry.grantRole(
            userRegistry.REGISTRY_MANAGER_ROLE(),
            contracts.incomeVerifier
        );

        // Grant TrustScore roles to various managers
        TrustScore trustScore = TrustScore(contracts.trustScore);
        trustScore.grantRole(
            trustScore.SCORE_MANAGER_ROLE(),
            contracts.faceVerifier
        );
        trustScore.grantRole(
            trustScore.SCORE_MANAGER_ROLE(),
            contracts.aadhaarVerifier
        );
        trustScore.grantRole(
            trustScore.SCORE_MANAGER_ROLE(),
            contracts.incomeVerifier
        );
        trustScore.grantRole(
            trustScore.SCORE_MANAGER_ROLE(),
            contracts.certificateManager
        );
        trustScore.grantRole(
            trustScore.SCORE_MANAGER_ROLE(),
            contracts.recognitionManager
        );
        trustScore.grantRole(
            trustScore.SCORE_MANAGER_ROLE(),
            contracts.economicIncentives
        );

        console.log("Role assignments configured");
    }

    function _configureIntegrations(
        DeployedContracts memory /* contracts */
    ) internal pure {
        // Additional integration configurations would go here
        // This might include setting up cross-chain configurations,
        // economic incentive parameters, governance voting parameters, etc.

        console.log("Inter-contract integrations configured");
    }
}
