// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CertificateManager} from "../src/CertificateManager.sol";
import {CrossChainManager} from "../src/CrossChainManager.sol";
import {GlobalCredentialAnchor} from "../src/GlobalCredentialAnchor.sol";
import {OrganizationRegistry} from "../src/OrganizationRegistry.sol";
import {RecognitionManager} from "../src/RecognitionManager.sol";
import {UserIdentityRegistry} from "../src/UserIdentityRegistry.sol";
import {VerificationLogger} from "../src/VerificationLogger.sol";
import {Script} from "forge-std/Script.sol";

contract DeployAll is Script {
    function run()
        external
        returns (
            VerificationLogger,
            UserIdentityRegistry,
            OrganizationRegistry,
            GlobalCredentialAnchor,
            CertificateManager,
            CrossChainManager,
            RecognitionManager
        )
    {
        vm.startBroadcast();

        VerificationLogger verificationLogger = new VerificationLogger();
        UserIdentityRegistry userRegistry = new UserIdentityRegistry(address(verificationLogger));
        OrganizationRegistry organizationRegistry = new OrganizationRegistry(address(verificationLogger));
        GlobalCredentialAnchor globalCredentialAnchor =
            new GlobalCredentialAnchor(address(userRegistry), address(verificationLogger));
        CertificateManager certificateManager =
            new CertificateManager(address(organizationRegistry), address(userRegistry), address(verificationLogger));
        CrossChainManager crossChainManager =
            new CrossChainManager(address(globalCredentialAnchor), address(verificationLogger));
        RecognitionManager recognitionManager =
            new RecognitionManager(address(globalCredentialAnchor), address(verificationLogger));

        vm.stopBroadcast();

        return (
            verificationLogger,
            userRegistry,
            organizationRegistry,
            globalCredentialAnchor,
            certificateManager,
            crossChainManager,
            recognitionManager
        );
    }
}
