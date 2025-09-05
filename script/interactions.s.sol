// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script,console} from "forge-std/Script.sol";
import {VerificationLogger} from "../src/VerificationLogger.sol";
import {UserIdentityRegistry} from "../src/UserIdentityRegistry.sol";
import {RecognitionManager} from "../src/RecognitionManager.sol";
import {GlobalCredentialAnchor} from "../src/GlobalCredentialAnchor.sol";
import {CrossChainManager} from "../src/CrossChainManager.sol";
import {CertificateManager} from "../src/CertificateManager.sol";
import {OrganizationRegistry} from "../src/OrganizationRegistry.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";


contract faceVerification is Script {
    UserIdentityRegistry userRegistry;
    function run() public {
        userRegistry =
            UserIdentityRegistry(0x9754F529b2c4Acd30f3830d4198aE210667ed411); 
        vm.broadcast();   
        userRegistry.setBackendSigner(0xE827EB87Dcfed45916f7Df2804d8621dC12a560b, true);
        vm.broadcast(); 
        userRegistry.registerUser("xxxx");
    }
}
