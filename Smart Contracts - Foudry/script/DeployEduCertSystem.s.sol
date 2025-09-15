// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// Core Contracts
import "../src/core/VerificationLogger.sol";
import "../src/core/ContractRegistry.sol";
import "../src/core/SystemToken.sol";
import "../src/core/UserIdentityRegistry.sol";

// Trust Score
import "../src/advanced_features/TrustScore.sol";

// Verification Managers
import "../src/verification/FaceVerificationManager.sol";
import "../src/verification/AadhaarVerificationManager.sol";
import "../src/verification/IncomeVerificationManager.sol";
import "../src/verification/OfflineVerificationManager.sol";

// Organization Contracts
import "../src/organizations/OrganizationRegistryProxy.sol";
import "../src/organizations/CertificateManager.sol";
import "../src/organizations/RecognitionManager.sol";

// Account Abstraction Contracts
import "../src/advanced_features/EduCertEntryPoint.sol";
import "../src/advanced_features/EduCertAccountFactory.sol";
import "../src/advanced_features/EduCertModularAccount.sol";
import "../src/advanced_features/AlchemyGasManager.sol";

// Advanced Features
import "../src/advanced_features/GuardianManager.sol";
import "../src/advanced_features/AAWalletManager.sol";
import "../src/advanced_features/PaymasterManager.sol";
import "../src/advanced_features/MigrationManager.sol";
import "../src/advanced_features/EconomicIncentives.sol";

// Governance
import "../src/governance/GovernanceManager.sol";
import "../src/governance/DisputeResolution.sol";

// Privacy & Cross-Chain
import "../src/privacy_cross-chain/PrivacyManager.sol";
import "../src/privacy_cross-chain/CrossChainManager.sol";
import "../src/privacy_cross-chain/GlobalCredentialAnchor.sol";

/**
 * @title DeployEduCertSystem
 * @notice Comprehensive deployment script for the entire EduCert system
 * @dev Deploys all contracts in the correct order with proper dependencies
 */
contract DeployEduCertSystem is Script {
    // Environment variables
    string private constant COMMUNITY_WALLET = "COMMUNITY_WALLET";
    string private constant TEAM_WALLET = "TEAM_WALLET";
    string private constant TREASURY_WALLET = "TREASURY_WALLET";
    string private constant ECOSYSTEM_WALLET = "ECOSYSTEM_WALLET";
    string private constant LAYERZERO_ENDPOINT = "LAYERZERO_ENDPOINT";
    string private constant ENTRY_POINT = "ENTRY_POINT";
    string private constant ALCHEMY_POLICY_ID = "ALCHEMY_POLICY_ID";
    string private constant ALCHEMY_APP_ID = "ALCHEMY_APP_ID";
    string private constant ALCHEMY_PAYMASTER = "ALCHEMY_PAYMASTER";

    // Deployed contract addresses
    struct DeployedContracts {
        // Core System
        address verificationLogger;
        address contractRegistry;
        address systemToken;
        address userIdentityRegistry;
        
        // Trust Score
        address trustScore;
        
        // Verification Managers
        address faceVerificationManager;
        address aadhaarVerificationManager;
        address incomeVerificationManager;
        address offlineVerificationManager;
        
        // Organization Contracts
        address organizationRegistry;
        address certificateManager;
        address recognitionManager;
        
        // Account Abstraction
        address eduCertEntryPoint;
        address eduCertAccountFactory;
        address eduCertModularAccount;
        address alchemyGasManager;
        
        // Advanced Features
        address guardianManager;
        address aaWalletManager;
        address paymasterManager;
        address migrationManager;
        address economicIncentives;
        
        // Governance
        address governanceManager;
        address disputeResolution;
        
        // Privacy & Cross-Chain
        address privacyManager;
        address crossChainManager;
        address globalCredentialAnchor;
        
        // Proxy Admin
        address proxyAdmin;
    }

    DeployedContracts public deployed;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Starting EduCert System Deployment");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);

        // Deploy in dependency order
        _deployCoreSystem();
        _deployVerificationSystem();
        _deployOrganizationSystem();
        _deployAccountAbstractionSystem();
        _deployAdvancedFeatures();
        _deployGovernanceSystem();
        _deployPrivacyCrossChainSystem();

        // Register all contracts
        _registerAllContracts();

        // Output deployment summary
        _outputDeploymentSummary();

        vm.stopBroadcast();
    }

    function _deployCoreSystem() internal {
        console.log("\n=== DEPLOYING CORE SYSTEM ===");

        // 1. Deploy VerificationLogger (foundation)
        VerificationLogger verificationLogger = new VerificationLogger();
        deployed.verificationLogger = address(verificationLogger);
        console.log("VerificationLogger deployed at:", deployed.verificationLogger);

        // 2. Deploy ContractRegistry
        ContractRegistry contractRegistry = new ContractRegistry();
        deployed.contractRegistry = address(contractRegistry);
        console.log(" ContractRegistry deployed at:", deployed.contractRegistry);

        // 3. Deploy SystemToken
        SystemToken systemToken = new SystemToken();
        deployed.systemToken = address(systemToken);
        console.log(" SystemToken deployed at:", deployed.systemToken);

        // 4. Deploy UserIdentityRegistry
        UserIdentityRegistry userIdentityRegistry = new UserIdentityRegistry(
            deployed.verificationLogger,
            deployed.contractRegistry
        );
        deployed.userIdentityRegistry = address(userIdentityRegistry);
        console.log(" UserIdentityRegistry deployed at:", deployed.userIdentityRegistry);

        // 5. Deploy TrustScore
        TrustScore trustScore = new TrustScore(deployed.verificationLogger);
        deployed.trustScore = address(trustScore);
        console.log(" TrustScore deployed at:", deployed.trustScore);
    }

    function _deployVerificationSystem() internal {
        console.log("\n=== DEPLOYING VERIFICATION SYSTEM ===");

        // Deploy verification managers
        FaceVerificationManager faceVerificationManager = new FaceVerificationManager(
            deployed.verificationLogger,
            deployed.userIdentityRegistry,
            deployed.trustScore
        );
        deployed.faceVerificationManager = address(faceVerificationManager);
        console.log(" FaceVerificationManager deployed at:", deployed.faceVerificationManager);

        AadhaarVerificationManager aadhaarVerificationManager = new AadhaarVerificationManager(
            deployed.verificationLogger,
            deployed.userIdentityRegistry,
            deployed.trustScore
        );
        deployed.aadhaarVerificationManager = address(aadhaarVerificationManager);
        console.log(" AadhaarVerificationManager deployed at:", deployed.aadhaarVerificationManager);

        IncomeVerificationManager incomeVerificationManager = new IncomeVerificationManager(
            deployed.verificationLogger,
            deployed.userIdentityRegistry,
            deployed.trustScore
        );
        deployed.incomeVerificationManager = address(incomeVerificationManager);
        console.log(" IncomeVerificationManager deployed at:", deployed.incomeVerificationManager);

        OfflineVerificationManager offlineVerificationManager = new OfflineVerificationManager(
            deployed.verificationLogger,
            deployed.userIdentityRegistry,
            deployed.trustScore
        );
        deployed.offlineVerificationManager = address(offlineVerificationManager);
        console.log(" OfflineVerificationManager deployed at:", deployed.offlineVerificationManager);
    }

    function _deployOrganizationSystem() internal {
        console.log("\n=== DEPLOYING ORGANIZATION SYSTEM ===");

        // Deploy OrganizationRegistry
        OrganizationRegistry organizationRegistry = new OrganizationRegistry(
            deployed.verificationLogger,
            deployed.contractRegistry
        );
        deployed.organizationRegistry = address(organizationRegistry);
        console.log(" OrganizationRegistry deployed at:", deployed.organizationRegistry);

        // Deploy CertificateManager (upgradeable)
        CertificateManager certificateManagerImpl = new CertificateManager();
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        deployed.proxyAdmin = address(proxyAdmin);
        
        TransparentUpgradeableProxy certificateManagerProxy = new TransparentUpgradeableProxy(
            address(certificateManagerImpl),
            address(proxyAdmin),
            abi.encodeWithSelector(
                CertificateManager.initialize.selector,
                deployed.verificationLogger,
                deployed.organizationRegistry,
                deployed.trustScore,
                deployed.contractRegistry
            )
        );
        deployed.certificateManager = address(certificateManagerProxy);
        console.log(" CertificateManager deployed at:", deployed.certificateManager);

        // Deploy RecognitionManager
        RecognitionManager recognitionManager = new RecognitionManager(
            deployed.verificationLogger,
            deployed.organizationRegistry,
            deployed.trustScore
        );
        deployed.recognitionManager = address(recognitionManager);
        console.log(" RecognitionManager deployed at:", deployed.recognitionManager);
    }

    function _deployAccountAbstractionSystem() internal {
        console.log("\n=== DEPLOYING ACCOUNT ABSTRACTION SYSTEM ===");

        address entryPointAddress = vm.envAddress(ENTRY_POINT);
        
        // Deploy EduCertEntryPoint
        EduCertEntryPoint eduCertEntryPoint = new EduCertEntryPoint(
            entryPointAddress,
            deployed.verificationLogger,
            deployed.trustScore
        );
        deployed.eduCertEntryPoint = address(eduCertEntryPoint);
        console.log(" EduCertEntryPoint deployed at:", deployed.eduCertEntryPoint);

        // Deploy EduCertModularAccount (implementation)
        EduCertModularAccount eduCertModularAccountImpl = new EduCertModularAccount();
        deployed.eduCertModularAccount = address(eduCertModularAccountImpl);
        console.log(" EduCertModularAccount implementation deployed at:", deployed.eduCertModularAccount);

        // Deploy AlchemyGasManager
        AlchemyGasManager alchemyGasManagerImpl = new AlchemyGasManager(entryPointAddress);
        TransparentUpgradeableProxy alchemyGasManagerProxy = new TransparentUpgradeableProxy(
            address(alchemyGasManagerImpl),
            deployed.proxyAdmin,
            abi.encodeWithSelector(
                AlchemyGasManager.initialize.selector,
                deployed.trustScore,
                deployed.verificationLogger,
                vm.envString(ALCHEMY_POLICY_ID),
                vm.envString(ALCHEMY_APP_ID),
                vm.envAddress(ALCHEMY_PAYMASTER)
            )
        );
        deployed.alchemyGasManager = address(alchemyGasManagerProxy);
        console.log(" AlchemyGasManager deployed at:", deployed.alchemyGasManager);

        // Deploy EduCertAccountFactory
        EduCertAccountFactory eduCertAccountFactory = new EduCertAccountFactory(
            entryPointAddress,
            deployed.eduCertModularAccount,
            deployed.verificationLogger,
            deployed.trustScore,
            deployed.alchemyGasManager,
            vm.envString(ALCHEMY_APP_ID),
            vm.envAddress(ALCHEMY_PAYMASTER)
        );
        deployed.eduCertAccountFactory = address(eduCertAccountFactory);
        console.log(" EduCertAccountFactory deployed at:", deployed.eduCertAccountFactory);
    }

    function _deployAdvancedFeatures() internal {
        console.log("\n=== DEPLOYING ADVANCED FEATURES ===");

        // Deploy GuardianManager
        GuardianManager guardianManager = new GuardianManager(
            deployed.verificationLogger,
            deployed.trustScore,
            deployed.eduCertAccountFactory
        );
        deployed.guardianManager = address(guardianManager);
        console.log(" GuardianManager deployed at:", deployed.guardianManager);

        // Deploy AAWalletManager
        AAWalletManager aaWalletManager = new AAWalletManager(
            deployed.verificationLogger,
            deployed.trustScore,
            deployed.eduCertAccountFactory
        );
        deployed.aaWalletManager = address(aaWalletManager);
        console.log(" AAWalletManager deployed at:", deployed.aaWalletManager);

        // Deploy PaymasterManager
        PaymasterManager paymasterManager = new PaymasterManager(
            deployed.verificationLogger,
            deployed.trustScore,
            deployed.alchemyGasManager
        );
        deployed.paymasterManager = address(paymasterManager);
        console.log(" PaymasterManager deployed at:", deployed.paymasterManager);

        // Deploy MigrationManager
        MigrationManager migrationManager = new MigrationManager(
            deployed.verificationLogger,
            deployed.trustScore,
            deployed.eduCertAccountFactory
        );
        deployed.migrationManager = address(migrationManager);
        console.log(" MigrationManager deployed at:", deployed.migrationManager);

        // Deploy EconomicIncentives
        EconomicIncentives economicIncentives = new EconomicIncentives(
            deployed.verificationLogger,
            deployed.trustScore,
            deployed.systemToken
        );
        deployed.economicIncentives = address(economicIncentives);
        console.log(" EconomicIncentives deployed at:", deployed.economicIncentives);
    }

    function _deployGovernanceSystem() internal {
        console.log("\n=== DEPLOYING GOVERNANCE SYSTEM ===");

        // Deploy GovernanceManager
        GovernanceManager governanceManager = new GovernanceManager(
            deployed.verificationLogger,
            deployed.trustScore,
            deployed.systemToken
        );
        deployed.governanceManager = address(governanceManager);
        console.log(" GovernanceManager deployed at:", deployed.governanceManager);

        // Deploy DisputeResolution
        DisputeResolution disputeResolution = new DisputeResolution(
            deployed.verificationLogger,
            deployed.trustScore,
            deployed.governanceManager
        );
        deployed.disputeResolution = address(disputeResolution);
        console.log(" DisputeResolution deployed at:", deployed.disputeResolution);
    }

    function _deployPrivacyCrossChainSystem() internal {
        console.log("\n=== DEPLOYING PRIVACY & CROSS-CHAIN SYSTEM ===");

        address layerZeroEndpoint = vm.envAddress(LAYERZERO_ENDPOINT);

        // Deploy PrivacyManager
        PrivacyManager privacyManager = new PrivacyManager(
            deployed.verificationLogger,
            deployed.trustScore,
            deployed.userIdentityRegistry
        );
        deployed.privacyManager = address(privacyManager);
        console.log(" PrivacyManager deployed at:", deployed.privacyManager);

        // Deploy CrossChainManager
        CrossChainManager crossChainManagerImpl = new CrossChainManager();
        TransparentUpgradeableProxy crossChainManagerProxy = new TransparentUpgradeableProxy(
            address(crossChainManagerImpl),
            deployed.proxyAdmin,
            abi.encodeWithSelector(
                CrossChainManager.initialize.selector,
                layerZeroEndpoint,
                deployed.verificationLogger,
                deployed.trustScore,
                deployed.certificateManager
            )
        );
        deployed.crossChainManager = address(crossChainManagerProxy);
        console.log(" CrossChainManager deployed at:", deployed.crossChainManager);

        // Deploy GlobalCredentialAnchor
        GlobalCredentialAnchor globalCredentialAnchorImpl = new GlobalCredentialAnchor();
        TransparentUpgradeableProxy globalCredentialAnchorProxy = new TransparentUpgradeableProxy(
            address(globalCredentialAnchorImpl),
            deployed.proxyAdmin,
            abi.encodeWithSelector(
                GlobalCredentialAnchor.initialize.selector,
                deployed.verificationLogger,
                deployed.trustScore,
                deployed.crossChainManager,
                deployed.certificateManager
            )
        );
        deployed.globalCredentialAnchor = address(globalCredentialAnchorProxy);
        console.log(" GlobalCredentialAnchor deployed at:", deployed.globalCredentialAnchor);
    }

    function _registerAllContracts() internal {
        console.log("\n=== REGISTERING ALL CONTRACTS ===");

        ContractRegistry registry = ContractRegistry(deployed.contractRegistry);

        // Register core contracts
        registry.registerContract("VerificationLogger", deployed.verificationLogger, "1.0.0");
        registry.registerContract("ContractRegistry", deployed.contractRegistry, "1.0.0");
        registry.registerContract("SystemToken", deployed.systemToken, "1.0.0");
        registry.registerContract("UserIdentityRegistry", deployed.userIdentityRegistry, "1.0.0");
        registry.registerContract("TrustScore", deployed.trustScore, "1.0.0");

        // Register verification contracts
        registry.registerContract("FaceVerificationManager", deployed.faceVerificationManager, "1.0.0");
        registry.registerContract("AadhaarVerificationManager", deployed.aadhaarVerificationManager, "1.0.0");
        registry.registerContract("IncomeVerificationManager", deployed.incomeVerificationManager, "1.0.0");
        registry.registerContract("OfflineVerificationManager", deployed.offlineVerificationManager, "1.0.0");

        // Register organization contracts
        registry.registerContract("OrganizationRegistry", deployed.organizationRegistry, "1.0.0");
        registry.registerContract("CertificateManager", deployed.certificateManager, "1.0.0");
        registry.registerContract("RecognitionManager", deployed.recognitionManager, "1.0.0");

        // Register account abstraction contracts
        registry.registerContract("EduCertEntryPoint", deployed.eduCertEntryPoint, "1.0.0");
        registry.registerContract("EduCertAccountFactory", deployed.eduCertAccountFactory, "1.0.0");
        registry.registerContract("EduCertModularAccount", deployed.eduCertModularAccount, "1.0.0");
        registry.registerContract("AlchemyGasManager", deployed.alchemyGasManager, "1.0.0");

        // Register advanced features
        registry.registerContract("GuardianManager", deployed.guardianManager, "1.0.0");
        registry.registerContract("AAWalletManager", deployed.aaWalletManager, "1.0.0");
        registry.registerContract("PaymasterManager", deployed.paymasterManager, "1.0.0");
        registry.registerContract("MigrationManager", deployed.migrationManager, "1.0.0");
        registry.registerContract("EconomicIncentives", deployed.economicIncentives, "1.0.0");

        // Register governance contracts
        registry.registerContract("GovernanceManager", deployed.governanceManager, "1.0.0");
        registry.registerContract("DisputeResolution", deployed.disputeResolution, "1.0.0");

        // Register privacy & cross-chain contracts
        registry.registerContract("PrivacyManager", deployed.privacyManager, "1.0.0");
        registry.registerContract("CrossChainManager", deployed.crossChainManager, "1.0.0");
        registry.registerContract("GlobalCredentialAnchor", deployed.globalCredentialAnchor, "1.0.0");

        console.log(" All contracts registered in ContractRegistry");
    }

    function _outputDeploymentSummary() internal view {
        console.log("\n" + "=".repeat(80));
        console.log(" EDUCERT SYSTEM DEPLOYMENT COMPLETE");
        console.log("=".repeat(80));

        console.log("\n=== CORE SYSTEM CONTRACTS ===");
        console.log("VerificationLogger:", deployed.verificationLogger);
        console.log("ContractRegistry:", deployed.contractRegistry);
        console.log("SystemToken:", deployed.systemToken);
        console.log("UserIdentityRegistry:", deployed.userIdentityRegistry);

        console.log("\n=== TRUST SCORE CONTRACTS ===");
        console.log("TrustScore:", deployed.trustScore);

        console.log("\n=== VERIFICATION CONTRACTS ===");
        console.log("FaceVerificationManager:", deployed.faceVerificationManager);
        console.log("AadhaarVerificationManager:", deployed.aadhaarVerificationManager);
        console.log("IncomeVerificationManager:", deployed.incomeVerificationManager);
        console.log("OfflineVerificationManager:", deployed.offlineVerificationManager);

        console.log("\n=== ORGANIZATION CONTRACTS ===");
        console.log("OrganizationRegistry:", deployed.organizationRegistry);
        console.log("CertificateManager:", deployed.certificateManager);
        console.log("RecognitionManager:", deployed.recognitionManager);

        console.log("\n=== ACCOUNT ABSTRACTION CONTRACTS ===");
        console.log("EduCertEntryPoint:", deployed.eduCertEntryPoint);
        console.log("EduCertAccountFactory:", deployed.eduCertAccountFactory);
        console.log("EduCertModularAccount:", deployed.eduCertModularAccount);
        console.log("AlchemyGasManager:", deployed.alchemyGasManager);

        console.log("\n=== ADVANCED FEATURES ===");
        console.log("GuardianManager:", deployed.guardianManager);
        console.log("AAWalletManager:", deployed.aaWalletManager);
        console.log("PaymasterManager:", deployed.paymasterManager);
        console.log("MigrationManager:", deployed.migrationManager);
        console.log("EconomicIncentives:", deployed.economicIncentives);

        console.log("\n=== GOVERNANCE CONTRACTS ===");
        console.log("GovernanceManager:", deployed.governanceManager);
        console.log("DisputeResolution:", deployed.disputeResolution);

        console.log("\n=== PRIVACY & CROSS-CHAIN ===");
        console.log("PrivacyManager:", deployed.privacyManager);
        console.log("CrossChainManager:", deployed.crossChainManager);
        console.log("GlobalCredentialAnchor:", deployed.globalCredentialAnchor);

        console.log("\n=== PROXY ADMIN ===");
        console.log("ProxyAdmin:", deployed.proxyAdmin);

        console.log("\n" + "=".repeat(80));
        console.log("NEXT STEPS:");
        console.log("1. Run configuration script: ConfigureEduCertSystem.s.sol");
        console.log("2. Set up roles and permissions");
        console.log("3. Configure Alchemy integration");
        console.log("4. Test system functionality");
        console.log("5. Deploy to production networks");
        console.log("=".repeat(80));
    }
}
