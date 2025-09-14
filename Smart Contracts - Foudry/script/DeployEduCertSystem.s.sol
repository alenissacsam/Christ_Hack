// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {VerificationLogger} from "src/core/VerificationLogger.sol";
import {TrustScore} from "src/advanced_features/TrustScore.sol";
import {UserIdentityRegistry} from "src/core/UserIdentityRegistry.sol";
import {ContractRegistry} from "src/core/ContractRegistry.sol";
import {SystemToken} from "src/core/SystemToken.sol";
import {FaceVerificationManager} from "src/verification/FaceVerificationManager.sol";
import {AadhaarVerificationManager} from "src/verification/AadhaarVerificationManager.sol";
import {IncomeVerificationManager} from "src/verification/IncomeVerificationManager.sol";
import {CertificateManager} from "src/organizations/CertificateManager.sol";
import {OrganizationRegistryProxy} from "src/organizations/OrganizationRegistryProxy.sol";
import {RecognitionManager} from "src/organizations/RecognitionManager.sol";
import {EconomicIncentives} from "src/advanced_features/EconomicIncentives.sol";
import {GovernanceManager} from "src/governance/GovernanceManager.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// You must add missing imports for these contracts!
import {GuardianManager} from "src/advanced_features/GuardianManager.sol";
import {DisputeResolution} from "src/governance/DisputeResolution.sol";
import {PrivacyManager} from "src/privacy_cross-chain/PrivacyManager.sol";
import {CrossChainManager} from "src/privacy_cross-chain/CrossChainManager.sol";
import {GlobalCredentialAnchor} from "src/privacy_cross-chain/GlobalCredentialAnchor.sol";
import {AAWalletManager} from "src/advanced_features/AAWalletManager.sol";
import {PaymasterManager} from "src/advanced_features/PaymasterManager.sol";
import {MigrationManager} from "src/advanced_features/MigrationManager.sol";

contract DeployEduCertSystem is Script {
    address constant COMMUNITY_WALLET = 0x1000000000000000000000000000000000000001;
    address constant TEAM_WALLET = 0x2000000000000000000000000000000000000002;
    address constant TREASURY_WALLET = 0x3000000000000000000000000000000000000003;
    address constant ECOSYSTEM_WALLET = 0x4000000000000000000000000000000000000004;
    address constant LAYERZERO_ENDPOINT = 0x3c2269811836af69497E5F486A85D7316753cf62;
    address constant WALLET_IMPLEMENTATION = 0x5000000000000000000000000000000000000005;
    address constant ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    struct Deployed {
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

        // Validate wallet addresses are set and non-zero
        require(COMMUNITY_WALLET != address(0), "COMMUNITY_WALLET not configured");
        require(TEAM_WALLET != address(0), "TEAM_WALLET not configured");
        require(TREASURY_WALLET != address(0), "TREASURY_WALLET not configured");
        require(ECOSYSTEM_WALLET != address(0), "ECOSYSTEM_WALLET not configured");

        console.log("=== STARTING EDUCERT SYSTEM DEPLOYMENT ===");
        console.log("Deployer:", vm.addr(pk));

        vm.startBroadcast(pk);

        Deployed memory d;

        // 1. VerificationLogger
        {
            address impl = address(new VerificationLogger());
            bytes memory init = abi.encodeWithSelector(VerificationLogger.initialize.selector);
            // add args if any

            d.verificationLogger = address(new ERC1967Proxy(impl, init));
        }

        // 2. TrustScore
        {
            address impl = address(new TrustScore());
            bytes memory init = abi.encodeWithSelector(TrustScore.initialize.selector, d.verificationLogger);
            d.trustScore = address(new ERC1967Proxy(impl, init));
        }

        // 3. UserIdentityRegistry
        {
            address impl = address(new UserIdentityRegistry());
            bytes memory init =
                abi.encodeWithSelector(UserIdentityRegistry.initialize.selector, d.verificationLogger, d.trustScore);
            d.userRegistry = address(new ERC1967Proxy(impl, init));
        }

        // 4. ContractRegistry
        {
            address impl = address(new ContractRegistry());
            bytes memory init = abi.encodeWithSelector(ContractRegistry.initialize.selector, d.verificationLogger);
            d.contractRegistry = address(new ERC1967Proxy(impl, init));
        }

        // 5. SystemToken
        {
            address impl = address(new SystemToken());
            bytes memory init = abi.encodeWithSelector(
                SystemToken.initialize.selector,
                COMMUNITY_WALLET,
                TEAM_WALLET,
                TREASURY_WALLET,
                ECOSYSTEM_WALLET,
                d.verificationLogger
            );
            d.systemToken = address(new ERC1967Proxy(impl, init));
        }

        // 6. FaceVerificationManager
        {
            address impl = address(new FaceVerificationManager());
            bytes memory init = abi.encodeWithSelector(
                FaceVerificationManager.initialize.selector, d.verificationLogger, d.userRegistry, d.trustScore
            );
            d.faceVerifier = address(new ERC1967Proxy(impl, init));
        }

        // 7. AadhaarVerificationManager
        {
            address impl = address(new AadhaarVerificationManager());
            bytes memory init = abi.encodeWithSelector(
                AadhaarVerificationManager.initialize.selector,
                d.verificationLogger,
                d.userRegistry,
                d.trustScore,
                d.faceVerifier
            );
            d.aadhaarVerifier = address(new ERC1967Proxy(impl, init));
        }

        // 8. IncomeVerificationManager
        {
            address impl = address(new IncomeVerificationManager());
            bytes memory init = abi.encodeWithSelector(
                IncomeVerificationManager.initialize.selector,
                d.verificationLogger,
                d.userRegistry,
                d.trustScore,
                d.aadhaarVerifier
            );
            d.incomeVerifier = address(new ERC1967Proxy(impl, init));
        }

        // 9. CertificateManager
        {
            address impl = address(new CertificateManager());
            bytes memory init = abi.encodeWithSelector(
                CertificateManager.initialize.selector, d.verificationLogger, d.userRegistry, d.trustScore
            );
            d.certificateManager = address(new ERC1967Proxy(impl, init));
        }

        // 10. OrganizationRegistryProxy
        {
            address impl = address(new OrganizationRegistryProxy());
            bytes memory init = abi.encodeWithSelector(
                OrganizationRegistryProxy.initializeAll.selector,
                d.certificateManager,
                d.verificationLogger,
                d.trustScore
            );
            d.organizationRegistry = address(new ERC1967Proxy(impl, init));
        }

        // 11. RecognitionManager
        {
            address impl = address(new RecognitionManager());
            bytes memory init = abi.encodeWithSelector(
                RecognitionManager.initialize.selector, d.trustScore, d.verificationLogger, d.certificateManager
            );
            d.recognitionManager = address(new ERC1967Proxy(impl, init));
        }

        // 12. EconomicIncentives
        {
            address impl = address(new EconomicIncentives());
            bytes memory init = abi.encodeWithSelector(
                EconomicIncentives.initialize.selector,
                d.systemToken, // stakingToken
                d.trustScore,
                d.verificationLogger
            );
            d.economicIncentives = address(new ERC1967Proxy(impl, init));
        }

        // 13. GovernanceManager
        {
            address impl = address(new GovernanceManager());
            bytes memory init = abi.encodeWithSelector(
                GovernanceManager.initialize.selector, d.trustScore, d.verificationLogger, d.economicIncentives
            );
            d.governanceManager = address(new ERC1967Proxy(impl, init));
        }

        // 14. GuardianManager
        {
            address impl = address(new GuardianManager());
            bytes memory init = abi.encodeWithSelector(
                GuardianManager.initialize.selector, d.verificationLogger, d.userRegistry, d.trustScore
            );
            d.guardianManager = address(new ERC1967Proxy(impl, init));
        }

        // 15. DisputeResolution
        {
            address impl = address(new DisputeResolution());
            bytes memory init = abi.encodeWithSelector(
                DisputeResolution.initialize.selector,
                d.verificationLogger,
                d.economicIncentives,
                d.trustScore,
                d.systemToken
            );
            d.disputeResolution = address(new ERC1967Proxy(impl, init));
        }

        // 16. PrivacyManager
        {
            address impl = address(new PrivacyManager());
            bytes memory init =
                abi.encodeWithSelector(PrivacyManager.initialize.selector, d.verificationLogger, d.userRegistry);
            d.privacyManager = address(new ERC1967Proxy(impl, init));
        }

        // 17. CrossChainManager
        {
            address impl = address(new CrossChainManager());
            bytes memory init =
                abi.encodeWithSelector(CrossChainManager.initialize.selector, d.verificationLogger, LAYERZERO_ENDPOINT);
            d.crossChainManager = address(new ERC1967Proxy(impl, init));
        }

        // 18. GlobalCredentialAnchor
        {
            address impl = address(new GlobalCredentialAnchor());
            bytes memory init = abi.encodeWithSelector(
                GlobalCredentialAnchor.initialize.selector, d.verificationLogger, d.crossChainManager, d.privacyManager
            );
            d.globalCredentialAnchor = address(new ERC1967Proxy(impl, init));
        }

        // 19. AAWalletManager
        {
            address impl = address(new AAWalletManager());
            bytes memory init = abi.encodeWithSelector(
                AAWalletManager.initialize.selector,
                d.verificationLogger,
                d.guardianManager,
                d.trustScore,
                WALLET_IMPLEMENTATION,
                ENTRY_POINT
            );
            d.aaWalletManager = address(new ERC1967Proxy(impl, init));
        }

        // 20. PaymasterManager
        {
            address impl = address(new PaymasterManager());
            bytes memory init = abi.encodeWithSelector(
                PaymasterManager.initialize.selector, d.verificationLogger, d.trustScore, ENTRY_POINT, d.systemToken
            );
            d.paymasterManager = address(new ERC1967Proxy(impl, init));
        }

        // 21. MigrationManager
        {
            address impl = address(new MigrationManager());
            bytes memory init =
                abi.encodeWithSelector(MigrationManager.initialize.selector, d.verificationLogger, d.contractRegistry);
            d.migrationManager = address(new ERC1967Proxy(impl, init));
        }

        vm.stopBroadcast();

        // Comprehensive logging of all deployed addresses
        console.log("=== CORE SYSTEM CONTRACTS ===");
        console.log("VerificationLogger:", d.verificationLogger);
        console.log("TrustScore:", d.trustScore);
        console.log("UserIdentityRegistry:", d.userRegistry);
        console.log("ContractRegistry:", d.contractRegistry);
        console.log("SystemToken:", d.systemToken);

        console.log("\n=== VERIFICATION CONTRACTS ===");
        console.log("FaceVerificationManager:", d.faceVerifier);
        console.log("AadhaarVerificationManager:", d.aadhaarVerifier);
        console.log("IncomeVerificationManager:", d.incomeVerifier);

        console.log("\n=== ORGANIZATION CONTRACTS ===");
        console.log("CertificateManager:", d.certificateManager);
        console.log("OrganizationRegistry:", d.organizationRegistry);
        console.log("RecognitionManager:", d.recognitionManager);

        console.log("\n=== GOVERNANCE CONTRACTS ===");
        console.log("EconomicIncentives:", d.economicIncentives);
        console.log("GovernanceManager:", d.governanceManager);
        console.log("DisputeResolution:", d.disputeResolution);

        console.log("\n=== ADVANCED FEATURES ===");
        console.log("GuardianManager:", d.guardianManager);
        console.log("AAWalletManager:", d.aaWalletManager);
        console.log("PaymasterManager:", d.paymasterManager);
        console.log("MigrationManager:", d.migrationManager);

        console.log("\n=== PRIVACY & CROSS-CHAIN ===");
        console.log("PrivacyManager:", d.privacyManager);
        console.log("CrossChainManager:", d.crossChainManager);
        console.log("GlobalCredentialAnchor:", d.globalCredentialAnchor);

        console.log("\n=== CONFIGURATION ===");
        console.log("Community Wallet:", COMMUNITY_WALLET);
        console.log("Team Wallet:", TEAM_WALLET);
        console.log("Treasury Wallet:", TREASURY_WALLET);
        console.log("Ecosystem Wallet:", ECOSYSTEM_WALLET);
        console.log("LayerZero Endpoint:", LAYERZERO_ENDPOINT);
        console.log("Wallet Implementation:", WALLET_IMPLEMENTATION);
        console.log("Entry Point:", ENTRY_POINT);

        // Register all contracts in the ContractRegistry
        _registerContracts(d);
    }

    function _registerContracts(Deployed memory /* d */ ) internal pure {
        // This function would register all deployed contracts in the ContractRegistry
        // for easy access and upgradability. Implementation would require additional
        // transactions after deployment.
        console.log("\n=== CONTRACT REGISTRATION REQUIRED ===");
        console.log("Post-deployment: Register all contracts in ContractRegistry");
        console.log("Post-deployment: Set up proper role assignments");
        console.log("Post-deployment: Configure inter-contract dependencies");
    }
}
