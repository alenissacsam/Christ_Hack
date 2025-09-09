/*
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Import all contracts
import {VerificationLogger} from "src/core/VerificationLogger.sol";
import {ContractRegistry} from "src/core/ContractRegistry.sol";
import {SystemToken} from "src/core/SystemToken.sol";
import {UserIdentityRegistry} from "src/core/UserIdentityRegistry.sol";
import {TrustScore} from "src/advanced_features/TrustScore.sol";
import {FaceVerificationManager} from "src/verification/FaceVerificationManager.sol";
import {AadhaarVerificationManager} from "src/verification/AadhaarVerificationManager.sol";
import {IncomeVerificationManager} from "src/verification/IncomeVerificationManager.sol";
import {CertificateManager} from "src/organizations/CertificateManager.sol";
import {OrganizationRegistry} from "src/organizations/OrganizationRegistry.sol";
import {RecognitionManager} from "src/organizations/RecognitionManager.sol";
import {EconomicIncentives} from "src/advanced_features/EconomicIncentives.sol";
import {GovernanceManager} from "src/governance/GovernanceManager.sol";
import {GuardianManager} from "src/advanced_features/GuardianManager.sol";
import {DisputeResolution} from "src/governance/DisputeResolution.sol";
import {PrivacyManager} from "src/privacy_cross-chain/PrivacyManager.sol";
import {CrossChainManager} from "src/privacy_cross-chain/CrossChainManager.sol";
import {GlobalCredentialAnchor} from "src/privacy_cross-chain/GlobalCredentialAnchor.sol";
import {AAWalletManager} from "src/advanced_features/AAWalletManager.sol";
import {PaymasterManager} from "src/advanced_features/PaymasterManager.sol";
import {MigrationManager} from "src/advanced_features/MigrationManager.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployEduCertSystem is Script {
    struct DeployedContracts {
        address verificationLogger;
        address contractRegistry;
        address systemToken;
        address userIdentityRegistry;
        address trustScore;
        address faceVerificationManager;
        address aadhaarVerificationManager;
        address incomeVerificationManager;
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

    // Configuration addresses (replace with actual addresses for production)
    address constant COMMUNITY_WALLET =
        0x1000000000000000000000000000000000000001;
    address constant TEAM_WALLET = 0x2000000000000000000000000000000000000002;
    address constant TREASURY_WALLET =
        0x3000000000000000000000000000000000000003;
    address constant ECOSYSTEM_WALLET =
        0x4000000000000000000000000000000000000004;
    address constant LAYERZERO_ENDPOINT =
        0x3c2269811836af69497E5F486A85D7316753cf62; // Polygon mainnet
    address constant WALLET_IMPLEMENTATION =
        0x5000000000000000000000000000000000000005; // AA wallet implementation
    address constant ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // ERC-4337 EntryPoint

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== DEPLOYING EDUCERT SYSTEM ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Chain ID:", block.chainid);

        DeployedContracts memory contracts = deploySystem();

        console.log("\n=== CONFIGURING SYSTEM ===");
        configureSystem(contracts);

        console.log("\n=== DEPLOYMENT SUMMARY ===");
        printDeploymentSummary(contracts);

        console.log("\n=== SAVING DEPLOYMENT DATA ===");
        saveDeploymentData(contracts);

        vm.stopBroadcast();
        console.log("=== DEPLOYMENT COMPLETED ===");
    }

    function deploySystem()
        internal
        returns (DeployedContracts memory contracts)
    {
        console.log("\n--- Phase 1: Core Infrastructure ---");

        // 1. Deploy VerificationLogger (immutable)
        // 1. Deploy VerificationLogger with proxy
        console.log("Deploying VerificationLogger...");
        contracts.verificationLogger = address(new VerificationLogger());
        address verificationLoggerImpl = address(new VerificationLogger());
        bytes memory verificationLoggerData = abi.encodeWithSelector(
            VerificationLogger.initialize.selector
        );
        contracts.verificationLogger = address(
            new ERC1967Proxy(verificationLoggerImpl, verificationLoggerData)
        );

        // 2. Deploy ContractRegistry with proxy
        console.log("Deploying ContractRegistry...");
        address contractRegistryImpl = address(new ContractRegistry());
        bytes memory contractRegistryData = abi.encodeWithSelector(
            ContractRegistry.initialize.selector,
            contracts.verificationLogger
        );
        contracts.contractRegistry = address(
            new ERC1967Proxy(contractRegistryImpl, contractRegistryData)
        );

        // 3. Deploy SystemToken with proxy
        console.log("Deploying SystemToken...");
        address systemTokenImpl = address(new SystemToken());
        bytes memory systemTokenData = abi.encodeWithSelector(
            SystemToken.initialize.selector,
            COMMUNITY_WALLET,
            TEAM_WALLET,
            TREASURY_WALLET,
            ECOSYSTEM_WALLET,
            contracts.verificationLogger
        );
        contracts.systemToken = address(
            new ERC1967Proxy(systemTokenImpl, systemTokenData)
        );

        // 4. Deploy UserIdentityRegistry with proxy
        console.log("Deploying UserIdentityRegistry...");
        // We deploy with address(0) for TrustScore initially to break the circular dependency.
        // It will be set later in the configuration phase.
        address userRegistryImpl = address(new UserIdentityRegistry());
        bytes memory userRegistryData = abi.encodeWithSelector(
            UserIdentityRegistry.initialize.selector,
            contracts.verificationLogger,
            address(0) // Placeholder for trustScore
        );
        contracts.userIdentityRegistry = address(
            new ERC1967Proxy(userRegistryImpl, userRegistryData)
        );

        // 5. Deploy TrustScore with proxy
        console.log("Deploying TrustScore...");
        address trustScoreImpl = address(new TrustScore());
        bytes memory trustScoreData = abi.encodeWithSelector(
            TrustScore.initialize.selector,
            contracts.verificationLogger,
            contracts.userIdentityRegistry
        );
        contracts.trustScore = address(
            new ERC1967Proxy(trustScoreImpl, trustScoreData)
        );

        console.log("\n--- Phase 2: Verification Systems ---");

        // 6. Deploy FaceVerificationManager
        console.log("Deploying FaceVerificationManager...");
        address faceVerificationImpl = address(new FaceVerificationManager());
        bytes memory faceVerificationData = abi.encodeWithSelector(
            FaceVerificationManager.initialize.selector,
            contracts.verificationLogger,
            contracts.userIdentityRegistry,
            contracts.trustScore
        );
        contracts.faceVerificationManager = address(
            new ERC1967Proxy(faceVerificationImpl, faceVerificationData)
        );

        // 7. Deploy AadhaarVerificationManager
        console.log("Deploying AadhaarVerificationManager...");
        address aadhaarVerificationImpl = address(
            new AadhaarVerificationManager()
        );
        bytes memory aadhaarVerificationData = abi.encodeWithSelector(
            AadhaarVerificationManager.initialize.selector,
            contracts.verificationLogger,
            contracts.userIdentityRegistry,
            contracts.trustScore,
            contracts.faceVerificationManager
        );
        contracts.aadhaarVerificationManager = address(
            new ERC1967Proxy(aadhaarVerificationImpl, aadhaarVerificationData)
        );

        // 8. Deploy IncomeVerificationManager
        console.log("Deploying IncomeVerificationManager...");
        address incomeVerificationImpl = address(
            new IncomeVerificationManager()
        );
        bytes memory incomeVerificationData = abi.encodeWithSelector(
            IncomeVerificationManager.initialize.selector,
            contracts.verificationLogger,
            contracts.userIdentityRegistry,
            contracts.trustScore,
            contracts.aadhaarVerificationManager
        );
        contracts.incomeVerificationManager = address(
            new ERC1967Proxy(incomeVerificationImpl, incomeVerificationData)
        );

        console.log("\n--- Phase 3: Certificate Management ---");

        // 9. Deploy CertificateManager
        console.log("Deploying CertificateManager...");
        address certificateManagerImpl = address(new CertificateManager());
        bytes memory certificateManagerData = abi.encodeWithSelector(
            CertificateManager.initialize.selector,
            contracts.verificationLogger,
            contracts.userIdentityRegistry,
            contracts.trustScore
        );
        contracts.certificateManager = address(
            new ERC1967Proxy(certificateManagerImpl, certificateManagerData)
        );

        // 10. Deploy OrganizationRegistry
        console.log("Deploying OrganizationRegistry...");
        address organizationRegistryImpl = address(new OrganizationRegistry());
        bytes memory organizationRegistryData = abi.encodeWithSelector(
            OrganizationRegistry.initialize.selector,
            contracts.certificateManager,
            contracts.verificationLogger,
            contracts.trustScore
        );
        contracts.organizationRegistry = address(
            new ERC1967Proxy(organizationRegistryImpl, organizationRegistryData)
        );

        // 11. Deploy RecognitionManager
        console.log("Deploying RecognitionManager...");
        address recognitionManagerImpl = address(new RecognitionManager());
        bytes memory recognitionManagerData = abi.encodeWithSelector(
            RecognitionManager.initialize.selector,
            contracts.trustScore,
            contracts.verificationLogger,
            contracts.certificateManager
        );
        contracts.recognitionManager = address(
            new ERC1967Proxy(recognitionManagerImpl, recognitionManagerData)
        );

        console.log("\n--- Phase 4: Economic & Governance ---");

        // 12. Deploy EconomicIncentives
        console.log("Deploying EconomicIncentives...");
        address economicIncentivesImpl = address(new EconomicIncentives());
        bytes memory economicIncentivesData = abi.encodeWithSelector(
            EconomicIncentives.initialize.selector,
            contracts.systemToken,
            contracts.trustScore,
            contracts.verificationLogger
        );
        contracts.economicIncentives = address(
            new ERC1967Proxy(economicIncentivesImpl, economicIncentivesData)
        );

        // 13. Deploy GovernanceManager
        console.log("Deploying GovernanceManager...");
        address governanceManagerImpl = address(new GovernanceManager());
        bytes memory governanceManagerData = abi.encodeWithSelector(
            GovernanceManager.initialize.selector,
            contracts.trustScore,
            contracts.verificationLogger,
            contracts.economicIncentives
        );
        contracts.governanceManager = address(
            new ERC1967Proxy(governanceManagerImpl, governanceManagerData)
        );

        // 14. Deploy GuardianManager
        console.log("Deploying GuardianManager...");
        address guardianManagerImpl = address(new GuardianManager());
        bytes memory guardianManagerData = abi.encodeWithSelector(
            GuardianManager.initialize.selector,
            contracts.verificationLogger,
            contracts.userIdentityRegistry,
            contracts.trustScore
        );
        contracts.guardianManager = address(
            new ERC1967Proxy(guardianManagerImpl, guardianManagerData)
        );

        // 15. Deploy DisputeResolution
        console.log("Deploying DisputeResolution...");
        // This contract is not upgradeable, deploy directly.
        contracts.disputeResolution = address(
            new DisputeResolution(
                contracts.verificationLogger,
                contracts.economicIncentives,
                contracts.trustScore
            )
        );

        console.log("\n--- Phase 5: Privacy & Cross-Chain ---");

        // 16. Deploy PrivacyManager
        console.log("Deploying PrivacyManager...");
        // This contract is not upgradeable, deploy directly.
        contracts.privacyManager = address(
            new PrivacyManager(contracts.verificationLogger)
        );

        // 17. Deploy CrossChainManager
        console.log("Deploying CrossChainManager...");
        // This contract is not upgradeable, deploy directly.
        contracts.crossChainManager = address(
            new CrossChainManager(contracts.verificationLogger, block.chainid)
        );

        // 18. Deploy GlobalCredentialAnchor
        console.log("Deploying GlobalCredentialAnchor...");
        // This contract is not upgradeable, deploy directly.
        contracts.globalCredentialAnchor = address(
            new GlobalCredentialAnchor(contracts.verificationLogger)
        );

        console.log("\n--- Phase 6: Account Abstraction ---");

        // 19. Deploy AAWalletManager
        console.log("Deploying AAWalletManager...");
        address aaWalletManagerImpl = address(new AAWalletManager());
        bytes memory aaWalletManagerData = abi.encodeWithSelector(
            AAWalletManager.initialize.selector,
            contracts.verificationLogger,
            contracts.guardianManager,
            contracts.trustScore,
            WALLET_IMPLEMENTATION,
            ENTRY_POINT
        );
        contracts.aaWalletManager = address(
            new ERC1967Proxy(aaWalletManagerImpl, aaWalletManagerData)
        );

        // 20. Deploy PaymasterManager
        console.log("Deploying PaymasterManager...");
        address paymasterManagerImpl = address(new PaymasterManager());
        bytes memory paymasterManagerData = abi.encodeWithSelector(
            PaymasterManager.initialize.selector,
            contracts.verificationLogger,
            contracts.trustScore,
            contracts.userIdentityRegistry,
            contracts.systemToken
        );
        contracts.paymasterManager = address(
            new ERC1967Proxy(paymasterManagerImpl, paymasterManagerData)
        );

        console.log("\n--- Phase 7: Migration Management ---");

        // 21. Deploy MigrationManager
        console.log("Deploying MigrationManager...");
        address migrationManagerImpl = address(new MigrationManager());
        bytes memory migrationManagerData = abi.encodeWithSelector(
            MigrationManager.initialize.selector,
            contracts.verificationLogger,
            contracts.contractRegistry
        );
        contracts.migrationManager = address(
            new ERC1967Proxy(migrationManagerImpl, migrationManagerData)
        );

        console.log("\n--- All Contracts Deployed ---");
        return contracts;
    }

    function configureSystem(DeployedContracts memory contracts) internal {
        // Register all contracts in the registry
        ContractRegistry registry = ContractRegistry(
            contracts.contractRegistry
        );

        string[] memory names = new string[](21);
        address[] memory addresses = new address[](21);
        string[] memory versions = new string[](21);

        names[0] = "VerificationLogger";
        addresses[0] = contracts.verificationLogger;
        versions[0] = "1.0.0";
        names[1] = "ContractRegistry";
        addresses[1] = contracts.contractRegistry;
        versions[1] = "1.0.0";
        names[2] = "SystemToken";
        addresses[2] = contracts.systemToken;
        versions[2] = "1.0.0";
        names[3] = "UserIdentityRegistry";
        addresses[3] = contracts.userIdentityRegistry;
        versions[3] = "1.0.0";
        names[4] = "TrustScore";
        addresses[4] = contracts.trustScore;
        versions[4] = "1.0.0";
        names[5] = "FaceVerificationManager";
        addresses[5] = contracts.faceVerificationManager;
        versions[5] = "1.0.0";
        names[6] = "AadhaarVerificationManager";
        addresses[6] = contracts.aadhaarVerificationManager;
        versions[6] = "1.0.0";
        names[7] = "IncomeVerificationManager";
        addresses[7] = contracts.incomeVerificationManager;
        versions[7] = "1.0.0";
        names[8] = "CertificateManager";
        addresses[8] = contracts.certificateManager;
        versions[8] = "1.0.0";
        names[9] = "OrganizationRegistry";
        addresses[9] = contracts.organizationRegistry;
        versions[9] = "1.0.0";
        names[10] = "RecognitionManager";
        addresses[10] = contracts.recognitionManager;
        versions[10] = "1.0.0";
        names[11] = "EconomicIncentives";
        addresses[11] = contracts.economicIncentives;
        versions[11] = "1.0.0";
        names[12] = "GovernanceManager";
        addresses[12] = contracts.governanceManager;
        versions[12] = "1.0.0";
        names[13] = "GuardianManager";
        addresses[13] = contracts.guardianManager;
        versions[13] = "1.0.0";
        names[14] = "DisputeResolution";
        addresses[14] = contracts.disputeResolution;
        versions[14] = "1.0.0";
        names[15] = "PrivacyManager";
        addresses[15] = contracts.privacyManager;
        versions[15] = "1.0.0";
        names[16] = "CrossChainManager";
        addresses[16] = contracts.crossChainManager;
        versions[16] = "1.0.0";
        names[17] = "GlobalCredentialAnchor";
        addresses[17] = contracts.globalCredentialAnchor;
        versions[17] = "1.0.0";
        names[18] = "AAWalletManager";
        addresses[18] = contracts.aaWalletManager;
        versions[18] = "1.0.0";
        names[19] = "PaymasterManager";
        addresses[19] = contracts.paymasterManager;
        versions[19] = "1.0.0";
        names[20] = "MigrationManager";
        addresses[20] = contracts.migrationManager;
        versions[20] = "1.0.0";

        console.log("Registering contracts in registry...");
        registry.batchRegisterContracts(names, addresses, versions);

        // Configure cross-references and permissions
        console.log("Configuring cross-references...");

        // Set TrustScore address in UserIdentityRegistry to resolve circular dependency
        console.log("Setting TrustScore address in UserIdentityRegistry...");
        UserIdentityRegistry(contracts.userIdentityRegistry).setTrustScore(
            contracts.trustScore
        );

        // Grant roles for certificate issuance
        CertificateManager(contracts.certificateManager).grantRole(
            keccak256("ISSUER_ROLE"),
            contracts.organizationRegistry
        );

        // Grant verification roles
        TrustScore(contracts.trustScore).grantRole(
            keccak256("SCORE_UPDATER_ROLE"),
            contracts.faceVerificationManager
        );
        TrustScore(contracts.trustScore).grantRole(
            keccak256("SCORE_UPDATER_ROLE"),
            contracts.aadhaarVerificationManager
        );
        TrustScore(contracts.trustScore).grantRole(
            keccak256("SCORE_UPDATER_ROLE"),
            contracts.incomeVerificationManager
        );
        TrustScore(contracts.trustScore).grantRole(
            keccak256("SCORE_UPDATER_ROLE"),
            contracts.recognitionManager
        );
        TrustScore(contracts.trustScore).grantRole(
            keccak256("SCORE_UPDATER_ROLE"),
            contracts.economicIncentives
        );

        console.log("Configuration completed");
    }

    function printDeploymentSummary(
        DeployedContracts memory contracts
    ) internal pure {
        console.log("VerificationLogger:", contracts.verificationLogger);
        console.log("ContractRegistry:", contracts.contractRegistry);
        console.log("SystemToken:", contracts.systemToken);
        console.log("UserIdentityRegistry:", contracts.userIdentityRegistry);
        console.log("TrustScore:", contracts.trustScore);
        console.log(
            "FaceVerificationManager:",
            contracts.faceVerificationManager
        );
        console.log(
            "AadhaarVerificationManager:",
            contracts.aadhaarVerificationManager
        );
        console.log(
            "IncomeVerificationManager:",
            contracts.incomeVerificationManager
        );
        console.log("CertificateManager:", contracts.certificateManager);
        console.log("OrganizationRegistry:", contracts.organizationRegistry);
        console.log("RecognitionManager:", contracts.recognitionManager);
        console.log("EconomicIncentives:", contracts.economicIncentives);
        console.log("GovernanceManager:", contracts.governanceManager);
        console.log("GuardianManager:", contracts.guardianManager);
        console.log("DisputeResolution:", contracts.disputeResolution);
        console.log("PrivacyManager:", contracts.privacyManager);
        console.log("CrossChainManager:", contracts.crossChainManager);
        console.log(
            "GlobalCredentialAnchor:",
            contracts.globalCredentialAnchor
        );
        console.log("AAWalletManager:", contracts.aaWalletManager);
        console.log("PaymasterManager:", contracts.paymasterManager);
        console.log("MigrationManager:", contracts.migrationManager);
    }

    function saveDeploymentData(DeployedContracts memory contracts) internal {
        string memory json = string.concat(
            "{\n",
            '  "network": "',
            vm.toString(block.chainid),
            '",\n',
            '  "timestamp": "',
            vm.toString(block.timestamp),
            '",\n',
            '  "contracts": {\n',
            '    "VerificationLogger": "',
            vm.toString(contracts.verificationLogger),
            '",\n',
            '    "ContractRegistry": "',
            vm.toString(contracts.contractRegistry),
            '",\n',
            '    "SystemToken": "',
            vm.toString(contracts.systemToken),
            '",\n',
            '    "UserIdentityRegistry": "',
            vm.toString(contracts.userIdentityRegistry),
            '",\n',
            '    "TrustScore": "',
            vm.toString(contracts.trustScore),
            '",\n',
            '    "FaceVerificationManager": "',
            vm.toString(contracts.faceVerificationManager),
            '",\n',
            '    "AadhaarVerificationManager": "',
            vm.toString(contracts.aadhaarVerificationManager),
            '",\n',
            '    "IncomeVerificationManager": "',
            vm.toString(contracts.incomeVerificationManager),
            '",\n',
            '    "CertificateManager": "',
            vm.toString(contracts.certificateManager),
            '",\n',
            '    "OrganizationRegistry": "',
            vm.toString(contracts.organizationRegistry),
            '",\n',
            '    "RecognitionManager": "',
            vm.toString(contracts.recognitionManager),
            '",\n',
            '    "EconomicIncentives": "',
            vm.toString(contracts.economicIncentives),
            '",\n',
            '    "GovernanceManager": "',
            vm.toString(contracts.governanceManager),
            '",\n',
            '    "GuardianManager": "',
            vm.toString(contracts.guardianManager),
            '",\n',
            '    "DisputeResolution": "',
            vm.toString(contracts.disputeResolution),
            '",\n',
            '    "PrivacyManager": "',
            vm.toString(contracts.privacyManager),
            '",\n',
            '    "CrossChainManager": "',
            vm.toString(contracts.crossChainManager),
            '",\n',
            '    "GlobalCredentialAnchor": "',
            vm.toString(contracts.globalCredentialAnchor),
            '",\n',
            '    "AAWalletManager": "',
            vm.toString(contracts.aaWalletManager),
            '",\n',
            '    "PaymasterManager": "',
            vm.toString(contracts.paymasterManager),
            '",\n',
            '    "MigrationManager": "',
            vm.toString(contracts.migrationManager),
            '"\n',
            "  }\n",
            "}"
        );

        vm.writeFile("./deployments/deployment.json", json);
        console.log("Deployment data saved to ./deployments/deployment.json");
    }
}
*/