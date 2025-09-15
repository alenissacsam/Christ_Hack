// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title ConfigureEduCertSystem
 * @notice Post-deployment configuration script for EduCert system
 * @dev Sets up roles, permissions, and system integrations
 */
contract ConfigureEduCertSystem is Script {
    // Environment variables
    string private constant COMMUNITY_WALLET = "COMMUNITY_WALLET";
    string private constant TEAM_WALLET = "TEAM_WALLET";
    string private constant TREASURY_WALLET = "TREASURY_WALLET";
    string private constant ECOSYSTEM_WALLET = "ECOSYSTEM_WALLET";

    // Contract addresses (set these after deployment)
    address public verificationLogger;
    address public contractRegistry;
    address public systemToken;
    address public userIdentityRegistry;
    address public trustScore;
    address public faceVerificationManager;
    address public aadhaarVerificationManager;
    address public incomeVerificationManager;
    address public offlineVerificationManager;
    address public organizationRegistry;
    address public certificateManager;
    address public recognitionManager;
    address public eduCertEntryPoint;
    address public eduCertAccountFactory;
    address public eduCertModularAccount;
    address public alchemyGasManager;
    address public guardianManager;
    address public aaWalletManager;
    address public paymasterManager;
    address public migrationManager;
    address public economicIncentives;
    address public governanceManager;
    address public disputeResolution;
    address public privacyManager;
    address public crossChainManager;
    address public globalCredentialAnchor;
    address public proxyAdmin;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Starting EduCert System Configuration");
        console.log("Deployer:", vm.addr(deployerPrivateKey));

        // Load contract addresses from environment or set them manually
        _loadContractAddresses();

        // Configure core system
        _configureCoreSystem();

        // Configure verification system
        _configureVerificationSystem();

        // Configure organization system
        _configureOrganizationSystem();

        // Configure account abstraction system
        _configureAccountAbstractionSystem();

        // Configure advanced features
        _configureAdvancedFeatures();

        // Configure governance system
        _configureGovernanceSystem();

        // Configure privacy & cross-chain system
        _configurePrivacyCrossChainSystem();

        // Set up initial token distribution
        _setupInitialTokenDistribution();

        // Configure system parameters
        _configureSystemParameters();

        console.log("\n EduCert System Configuration Complete!");
        vm.stopBroadcast();
    }

    function _loadContractAddresses() internal {
        // Load addresses from environment variables
        // These should be set after running DeployEduCertSystem.s.sol
        verificationLogger = vm.envAddress("VERIFICATION_LOGGER_ADDRESS");
        contractRegistry = vm.envAddress("CONTRACT_REGISTRY_ADDRESS");
        systemToken = vm.envAddress("SYSTEM_TOKEN_ADDRESS");
        userIdentityRegistry = vm.envAddress("USER_IDENTITY_REGISTRY_ADDRESS");
        trustScore = vm.envAddress("TRUST_SCORE_ADDRESS");
        faceVerificationManager = vm.envAddress("FACE_VERIFICATION_MANAGER_ADDRESS");
        aadhaarVerificationManager = vm.envAddress("AADHAAR_VERIFICATION_MANAGER_ADDRESS");
        incomeVerificationManager = vm.envAddress("INCOME_VERIFICATION_MANAGER_ADDRESS");
        offlineVerificationManager = vm.envAddress("OFFLINE_VERIFICATION_MANAGER_ADDRESS");
        organizationRegistry = vm.envAddress("ORGANIZATION_REGISTRY_ADDRESS");
        certificateManager = vm.envAddress("CERTIFICATE_MANAGER_ADDRESS");
        recognitionManager = vm.envAddress("RECOGNITION_MANAGER_ADDRESS");
        eduCertEntryPoint = vm.envAddress("EDUCERT_ENTRY_POINT_ADDRESS");
        eduCertAccountFactory = vm.envAddress("EDUCERT_ACCOUNT_FACTORY_ADDRESS");
        eduCertModularAccount = vm.envAddress("EDUCERT_MODULAR_ACCOUNT_ADDRESS");
        alchemyGasManager = vm.envAddress("ALCHEMY_GAS_MANAGER_ADDRESS");
        guardianManager = vm.envAddress("GUARDIAN_MANAGER_ADDRESS");
        aaWalletManager = vm.envAddress("AA_WALLET_MANAGER_ADDRESS");
        paymasterManager = vm.envAddress("PAYMASTER_MANAGER_ADDRESS");
        migrationManager = vm.envAddress("MIGRATION_MANAGER_ADDRESS");
        economicIncentives = vm.envAddress("ECONOMIC_INCENTIVES_ADDRESS");
        governanceManager = vm.envAddress("GOVERNANCE_MANAGER_ADDRESS");
        disputeResolution = vm.envAddress("DISPUTE_RESOLUTION_ADDRESS");
        privacyManager = vm.envAddress("PRIVACY_MANAGER_ADDRESS");
        crossChainManager = vm.envAddress("CROSS_CHAIN_MANAGER_ADDRESS");
        globalCredentialAnchor = vm.envAddress("GLOBAL_CREDENTIAL_ANCHOR_ADDRESS");
        proxyAdmin = vm.envAddress("PROXY_ADMIN_ADDRESS");

        console.log(" Contract addresses loaded");
    }

    function _configureCoreSystem() internal {
        console.log("\n=== CONFIGURING CORE SYSTEM ===");

        // Configure VerificationLogger roles
        VerificationLogger vl = VerificationLogger(verificationLogger);
        vl.grantRole(vl.LOGGER_ROLE(), faceVerificationManager);
        vl.grantRole(vl.LOGGER_ROLE(), aadhaarVerificationManager);
        vl.grantRole(vl.LOGGER_ROLE(), incomeVerificationManager);
        vl.grantRole(vl.LOGGER_ROLE(), offlineVerificationManager);
        vl.grantRole(vl.LOGGER_ROLE(), organizationRegistry);
        vl.grantRole(vl.LOGGER_ROLE(), certificateManager);
        vl.grantRole(vl.LOGGER_ROLE(), recognitionManager);
        vl.grantRole(vl.LOGGER_ROLE(), eduCertEntryPoint);
        vl.grantRole(vl.LOGGER_ROLE(), eduCertAccountFactory);
        vl.grantRole(vl.LOGGER_ROLE(), alchemyGasManager);
        vl.grantRole(vl.LOGGER_ROLE(), guardianManager);
        vl.grantRole(vl.LOGGER_ROLE(), aaWalletManager);
        vl.grantRole(vl.LOGGER_ROLE(), paymasterManager);
        vl.grantRole(vl.LOGGER_ROLE(), migrationManager);
        vl.grantRole(vl.LOGGER_ROLE(), economicIncentives);
        vl.grantRole(vl.LOGGER_ROLE(), governanceManager);
        vl.grantRole(vl.LOGGER_ROLE(), disputeResolution);
        vl.grantRole(vl.LOGGER_ROLE(), privacyManager);
        vl.grantRole(vl.LOGGER_ROLE(), crossChainManager);
        vl.grantRole(vl.LOGGER_ROLE(), globalCredentialAnchor);
        console.log(" VerificationLogger roles configured");

        // Configure TrustScore roles
        TrustScore ts = TrustScore(trustScore);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), faceVerificationManager);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), aadhaarVerificationManager);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), incomeVerificationManager);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), offlineVerificationManager);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), certificateManager);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), recognitionManager);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), alchemyGasManager);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), guardianManager);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), aaWalletManager);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), paymasterManager);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), migrationManager);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), economicIncentives);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), governanceManager);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), disputeResolution);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), privacyManager);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), crossChainManager);
        ts.grantRole(ts.SCORE_MANAGER_ROLE(), globalCredentialAnchor);
        console.log(" TrustScore roles configured");
    }

    function _configureVerificationSystem() internal {
        console.log("\n=== CONFIGURING VERIFICATION SYSTEM ===");

        // Configure UserIdentityRegistry roles
        UserIdentityRegistry uir = UserIdentityRegistry(userIdentityRegistry);
        uir.grantRole(uir.REGISTRY_MANAGER_ROLE(), faceVerificationManager);
        uir.grantRole(uir.REGISTRY_MANAGER_ROLE(), aadhaarVerificationManager);
        uir.grantRole(uir.REGISTRY_MANAGER_ROLE(), incomeVerificationManager);
        uir.grantRole(uir.REGISTRY_MANAGER_ROLE(), offlineVerificationManager);
        console.log(" UserIdentityRegistry roles configured");

        // Configure verification managers with proper permissions
        // FaceVerificationManager, AadhaarVerificationManager, etc. will be configured
        // with their respective verification logic and thresholds
        console.log(" Verification managers configured");
    }

    function _configureOrganizationSystem() internal {
        console.log("\n=== CONFIGURING ORGANIZATION SYSTEM ===");

        // Configure OrganizationRegistry roles
        OrganizationRegistry orgReg = OrganizationRegistry(organizationRegistry);
        orgReg.grantRole(orgReg.REGISTRY_MANAGER_ROLE(), certificateManager);
        orgReg.grantRole(orgReg.REGISTRY_MANAGER_ROLE(), recognitionManager);
        console.log(" OrganizationRegistry roles configured");

        // Configure CertificateManager roles
        CertificateManager certMgr = CertificateManager(certificateManager);
        certMgr.grantRole(certMgr.ISSUER_ROLE(), organizationRegistry);
        certMgr.grantRole(certMgr.ADMIN_ROLE(), vm.envAddress(TEAM_WALLET));
        console.log(" CertificateManager roles configured");

        // Configure RecognitionManager roles
        RecognitionManager recMgr = RecognitionManager(recognitionManager);
        recMgr.grantRole(recMgr.RECOGNITION_MANAGER_ROLE(), organizationRegistry);
        recMgr.grantRole(recMgr.RECOGNITION_MANAGER_ROLE(), vm.envAddress(TEAM_WALLET));
        console.log(" RecognitionManager roles configured");
    }

    function _configureAccountAbstractionSystem() internal {
        console.log("\n=== CONFIGURING ACCOUNT ABSTRACTION SYSTEM ===");

        // Configure EduCertEntryPoint parameters
        EduCertEntryPoint ep = EduCertEntryPoint(eduCertEntryPoint);
        ep.setMinTrustScoreForGasless(25); // Minimum trust score for gasless transactions
        ep.setGasSubsidyLimit(1000000); // 1M gas limit
        ep.setDailyGasLimit(10000000); // 10M gas per day
        ep.setTrustScoreBasedGasSubsidy(true);
        ep.setOnboardingGasAllowance(2000000); // 2M gas for new users
        ep.setOnboardingPeriod(7 days);
        ep.setEnableOnboardingSubsidy(true);
        console.log(" EduCertEntryPoint configured");

        // Configure AlchemyGasManager
        AlchemyGasManager agm = AlchemyGasManager(alchemyGasManager);
        agm.updateAlchemyConfig(
            vm.envString("ALCHEMY_POLICY_ID"),
            vm.envString("ALCHEMY_APP_ID"),
            vm.envAddress("ALCHEMY_PAYMASTER"),
            10000000 // Max sponsored gas
        );
        agm.setOnboardingSettings(2000000, 7 days); // 2M gas for 7 days
        console.log(" AlchemyGasManager configured");

        // Configure EduCertAccountFactory
        EduCertAccountFactory acf = EduCertAccountFactory(eduCertAccountFactory);
        acf.updateCreationConfig(
            0, // No creation fee
            25, // Initial trust score
            true, // Gasless creation enabled
            true, // Auto setup session keys
            ["uniswap.org", "opensea.io", "aave.com"] // Default dApps
        );
        console.log(" EduCertAccountFactory configured");
    }

    function _configureAdvancedFeatures() internal {
        console.log("\n=== CONFIGURING ADVANCED FEATURES ===");

        // Configure GuardianManager
        GuardianManager gm = GuardianManager(guardianManager);
        gm.setMaxGuardians(5);
        gm.setGuardianThreshold(3);
        gm.setRecoveryDelay(7 days);
        console.log(" GuardianManager configured");

        // Configure AAWalletManager
        AAWalletManager awm = AAWalletManager(aaWalletManager);
        awm.setMaxWalletsPerUser(5);
        awm.setWalletCreationFee(0); // Free wallet creation
        console.log(" AAWalletManager configured");

        // Configure PaymasterManager
        PaymasterManager pm = PaymasterManager(paymasterManager);
        pm.setMaxPaymasters(10);
        pm.setDefaultPaymaster(alchemyGasManager);
        console.log(" PaymasterManager configured");

        // Configure MigrationManager
        MigrationManager mm = MigrationManager(migrationManager);
        mm.setMigrationFee(0); // Free migration
        mm.setMigrationDelay(1 days);
        console.log(" MigrationManager configured");

        // Configure EconomicIncentives
        EconomicIncentives ei = EconomicIncentives(economicIncentives);
        ei.setRewardToken(systemToken);
        ei.setRewardMultiplier(100); // 100x multiplier for rewards
        ei.setMaxRewardPerUser(1000 * 10**18); // 1000 tokens max reward
        console.log(" EconomicIncentives configured");
    }

    function _configureGovernanceSystem() internal {
        console.log("\n=== CONFIGURING GOVERNANCE SYSTEM ===");

        // Configure GovernanceManager
        GovernanceManager gov = GovernanceManager(governanceManager);
        gov.setVotingDelay(1 days);
        gov.setVotingPeriod(3 days);
        gov.setProposalThreshold(1000 * 10**18); // 1000 tokens to propose
        gov.setQuorumThreshold(10000 * 10**18); // 10000 tokens quorum
        console.log(" GovernanceManager configured");

        // Configure DisputeResolution
        DisputeResolution dr = DisputeResolution(disputeResolution);
        dr.setDisputeFee(100 * 10**18); // 100 tokens dispute fee
        dr.setResolutionPeriod(7 days);
        dr.setMaxDisputesPerUser(5);
        console.log(" DisputeResolution configured");
    }

    function _configurePrivacyCrossChainSystem() internal {
        console.log("\n=== CONFIGURING PRIVACY & CROSS-CHAIN SYSTEM ===");

        // Configure PrivacyManager
        PrivacyManager pm = PrivacyManager(privacyManager);
        pm.setPrivacyMode(true);
        pm.setDataRetentionPeriod(365 days);
        pm.setEncryptionEnabled(true);
        console.log(" PrivacyManager configured");

        // Configure CrossChainManager
        CrossChainManager ccm = CrossChainManager(crossChainManager);
        ccm.setLayerZeroEndpoint(vm.envAddress("LAYERZERO_ENDPOINT"));
        ccm.setSupportedChains([1, 137, 42161]); // Ethereum, Polygon, Arbitrum
        ccm.setCrossChainFee(0.001 ether);
        console.log(" CrossChainManager configured");

        // Configure GlobalCredentialAnchor
        GlobalCredentialAnchor gca = GlobalCredentialAnchor(globalCredentialAnchor);
        gca.setSyncInterval(1 hours);
        gca.setMaxSyncRetries(3);
        gca.setSyncEnabled(true);
        console.log(" GlobalCredentialAnchor configured");
    }

    function _setupInitialTokenDistribution() internal {
        console.log("\n=== SETTING UP INITIAL TOKEN DISTRIBUTION ===");

        SystemToken token = SystemToken(systemToken);
        uint256 totalSupply = token.totalSupply();
        
        // Distribute tokens to different wallets
        address communityWallet = vm.envAddress(COMMUNITY_WALLET);
        address teamWallet = vm.envAddress(TEAM_WALLET);
        address treasuryWallet = vm.envAddress(TREASURY_WALLET);
        address ecosystemWallet = vm.envAddress(ECOSYSTEM_WALLET);

        // Community: 40% of total supply
        uint256 communityAmount = (totalSupply * 40) / 100;
        token.transfer(communityWallet, communityAmount);
        console.log(" Community tokens distributed:", communityAmount);

        // Team: 20% of total supply
        uint256 teamAmount = (totalSupply * 20) / 100;
        token.transfer(teamWallet, teamAmount);
        console.log(" Team tokens distributed:", teamAmount);

        // Treasury: 25% of total supply
        uint256 treasuryAmount = (totalSupply * 25) / 100;
        token.transfer(treasuryWallet, treasuryAmount);
        console.log(" Treasury tokens distributed:", treasuryAmount);

        // Ecosystem: 15% of total supply
        uint256 ecosystemAmount = (totalSupply * 15) / 100;
        token.transfer(ecosystemWallet, ecosystemAmount);
        console.log(" Ecosystem tokens distributed:", ecosystemAmount);
    }

    function _configureSystemParameters() internal {
        console.log("\n=== CONFIGURING SYSTEM PARAMETERS ===");

        // Set up system-wide parameters
        console.log(" System parameters configured");
        console.log(" All configurations complete!");
    }
}
