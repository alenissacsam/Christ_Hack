// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IVerificationLogger {
    function logEvent(
        string memory eventType,
        address user,
        bytes32 dataHash
    ) external;
}

interface IUserIdentityRegistry {
    function updateVerificationStatus(
        address user,
        string memory verificationType,
        bool status
    ) external;

    function isRegistered(address user) external view returns (bool);
}

interface ITrustScore {
    function updateScore(
        address user,
        int256 delta,
        string memory reason
    ) external;
}

interface IFaceVerificationManager {
    function isFaceVerified(address user) external view returns (bool);
}

contract AadhaarVerificationManager is AccessControl, ReentrancyGuard {
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant UIDAI_ORACLE_ROLE = keccak256("UIDAI_ORACLE_ROLE");

    struct AadhaarVerification {
        address user;
        bytes32 aadhaarHashCommitment;
        bytes32 otpHash;
        uint256 timestamp;
        bool isVerified;
        bool isActive;
        string verificationMethod; // "OTP", "Biometric", "eKYC"
    }

    mapping(address => AadhaarVerification) public aadhaarVerifications;
    mapping(bytes32 => bool) public usedAadhaarHashes;

    IVerificationLogger public verificationLogger;
    IUserIdentityRegistry public userRegistry;
    ITrustScore public trustScore;
    IFaceVerificationManager public faceVerificationManager;

    uint256 public constant AADHAAR_VERIFICATION_SCORE = 50;

    event AadhaarVerificationRequested(
        address indexed user,
        bytes32 aadhaarHashCommitment
    );
    event AadhaarVerificationCompleted(
        address indexed user,
        bool success,
        string method
    );
    event AadhaarVerificationRevoked(address indexed user, string reason);

    constructor(
        address _verificationLogger,
        address _userRegistry,
        address _trustScore,
        address _faceVerificationManager
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
        _grantRole(UIDAI_ORACLE_ROLE, msg.sender);

        verificationLogger = IVerificationLogger(_verificationLogger);
        userRegistry = IUserIdentityRegistry(_userRegistry);
        trustScore = ITrustScore(_trustScore);
        faceVerificationManager = IFaceVerificationManager(
            _faceVerificationManager
        );
    }

    function requestAadhaarVerification(
        bytes32 aadhaarHashCommitment,
        bytes32 otpHash,
        string memory verificationMethod
    ) external nonReentrant {
        require(userRegistry.isRegistered(msg.sender), "User not registered");
        require(
            faceVerificationManager.isFaceVerified(msg.sender),
            "Face verification required first"
        );
        require(
            !aadhaarVerifications[msg.sender].isActive,
            "Aadhaar verification already active"
        );
        require(
            !usedAadhaarHashes[aadhaarHashCommitment],
            "Aadhaar hash already used"
        );
        require(aadhaarHashCommitment != bytes32(0), "Invalid Aadhaar hash");
        require(otpHash != bytes32(0), "Invalid OTP hash");

        bytes32 methodHash = keccak256(bytes(verificationMethod));
        require(
            methodHash == keccak256("OTP") ||
                methodHash == keccak256("Biometric") ||
                methodHash == keccak256("eKYC"),
            "Invalid verification method"
        );

        aadhaarVerifications[msg.sender] = AadhaarVerification({
            user: msg.sender,
            aadhaarHashCommitment: aadhaarHashCommitment,
            otpHash: otpHash,
            timestamp: block.timestamp,
            isVerified: false,
            isActive: true,
            verificationMethod: verificationMethod
        });

        usedAadhaarHashes[aadhaarHashCommitment] = true;

        verificationLogger.logEvent(
            "AADHAAR_VERIFICATION_REQUESTED",
            msg.sender,
            aadhaarHashCommitment
        );

        emit AadhaarVerificationRequested(msg.sender, aadhaarHashCommitment);
    }

    function completeAadhaarVerification(
        address user,
        bool success,
        bytes memory uidaiSignature
    ) external onlyRole(UIDAI_ORACLE_ROLE) {
        require(
            aadhaarVerifications[user].isActive,
            "No active Aadhaar verification"
        );

        // Verify UIDAI oracle signature (simplified)
        require(
            _verifyUidaiSignature(user, success, uidaiSignature),
            "Invalid UIDAI signature"
        );

        aadhaarVerifications[user].isVerified = success;

        if (success) {
            // Update user registry
            userRegistry.updateVerificationStatus(user, "aadhaar", true);

            // Update trust score
            trustScore.updateScore(
                user,
                int256(AADHAAR_VERIFICATION_SCORE),
                "Aadhaar verification completed"
            );
        } else {
            aadhaarVerifications[user].isActive = false;
        }

        verificationLogger.logEvent(
            success
                ? "AADHAAR_VERIFICATION_SUCCESS"
                : "AADHAAR_VERIFICATION_FAILED",
            user,
            keccak256(
                abi.encodePacked(
                    aadhaarVerifications[user].verificationMethod,
                    success
                )
            )
        );

        emit AadhaarVerificationCompleted(
            user,
            success,
            aadhaarVerifications[user].verificationMethod
        );
    }

    function revokeAadhaarVerification(
        address user,
        string memory reason
    ) external onlyRole(VERIFIER_ROLE) {
        require(aadhaarVerifications[user].isVerified, "Aadhaar not verified");

        aadhaarVerifications[user].isVerified = false;
        aadhaarVerifications[user].isActive = false;

        // Update user registry
        userRegistry.updateVerificationStatus(user, "aadhaar", false);

        // Deduct trust score
        trustScore.updateScore(
            user,
            -int256(AADHAAR_VERIFICATION_SCORE),
            "Aadhaar verification revoked"
        );

        verificationLogger.logEvent(
            "AADHAAR_VERIFICATION_REVOKED",
            user,
            keccak256(bytes(reason))
        );

        emit AadhaarVerificationRevoked(user, reason);
    }

    function isAadhaarVerified(address user) external view returns (bool) {
        return
            aadhaarVerifications[user].isVerified &&
            aadhaarVerifications[user].isActive;
    }

    function getAadhaarVerificationInfo(
        address user
    )
        external
        view
        returns (
            bytes32 aadhaarHashCommitment,
            uint256 timestamp,
            bool isVerified,
            string memory verificationMethod
        )
    {
        AadhaarVerification memory verification = aadhaarVerifications[user];
        return (
            verification.aadhaarHashCommitment,
            verification.timestamp,
            verification.isVerified,
            verification.verificationMethod
        );
    }

    function _verifyUidaiSignature(
        address user,
        bool success,
        bytes memory signature
    ) private pure returns (bool) {
        // Simplified UIDAI signature verification - in production use proper verification
        return signature.length > 0 && user != address(0);
    }
}
