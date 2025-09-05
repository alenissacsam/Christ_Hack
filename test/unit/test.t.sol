// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VerificationLogger} from "../../src/VerificationLogger.sol";
import {UserIdentityRegistry} from "../../src/UserIdentityRegistry.sol";
import {RecognitionManager} from "../../src/RecognitionManager.sol";
import {GlobalCredentialAnchor} from "../../src/GlobalCredentialAnchor.sol";
import {CrossChainManager} from "../../src/CrossChainManager.sol";
import {CertificateManager} from "../../src/CertificateManager.sol";
import {OrganizationRegistry} from "../../src/OrganizationRegistry.sol";
import {Test, console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract VerficationTest is Test {
    VerificationLogger verificationLogger;
    UserIdentityRegistry userRegistry;
    RecognitionManager recognitionManager;
    GlobalCredentialAnchor globalAnchor;
    CrossChainManager crossChainManager;
    CertificateManager certificateManager;
    OrganizationRegistry organizationRegistry;

    address adminAdd = vm.addr(1);
    address userAdd = vm.addr(2);
    address orgAdd = vm.addr(3);

    bytes32 faceHash = keccak256("face-embedding-data");

    function setUp() public {
        vm.startPrank(adminAdd);

        verificationLogger = new VerificationLogger();

        userRegistry = new UserIdentityRegistry(address(verificationLogger));

        globalAnchor = new GlobalCredentialAnchor(
            address(userRegistry),
            address(verificationLogger)
        );

        recognitionManager = new RecognitionManager(
            address(globalAnchor),
            address(verificationLogger)
        );

        crossChainManager = new CrossChainManager(
            address(globalAnchor),
            address(verificationLogger)
        );

        organizationRegistry = new OrganizationRegistry(
            address(verificationLogger)
        );

        certificateManager = new CertificateManager(
            address(organizationRegistry),
            address(userRegistry),
            address(verificationLogger)
        );

        verificationLogger.addLogger(address(userRegistry));
        verificationLogger.addLogger(address(globalAnchor));
        verificationLogger.addLogger(address(recognitionManager));
        verificationLogger.addLogger(address(crossChainManager));
        verificationLogger.addLogger(address(organizationRegistry));
        verificationLogger.addLogger(address(certificateManager));
        userRegistry.setBackendSigner(adminAdd, true);
        vm.stopPrank();
    }

    modifier UserRegistered(){
        vm.prank(userAdd);
        userRegistry.registerUser("xxxx");
        _;
    }
    function testRegisterUser() public {
        vm.prank(userAdd);
        vm.expectEmit(true, false, false, false, address(userRegistry));
        emit UserIdentityRegistry.UserRegistered(userAdd, 0);
        userRegistry.registerUser("xxxx");
    }

    function testFaceScan() public UserRegistered{
        bytes32 msgHash = keccak256(abi.encodePacked(userAdd, faceHash));
        bytes32 ethMsgHash = MessageHashUtils.toEthSignedMessageHash(msgHash);

        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, ethMsgHash); // signing as backend signer

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(userAdd);
        userRegistry.verifyFace(faceHash, signature);
    }
}
