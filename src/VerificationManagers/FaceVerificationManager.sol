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

contract FaceVerificationManager is AccessControl, ReentrancyGuard {
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    struct FaceVerification {
        address user;
        bytes32 faceHashCommitment;
        bytes32 livenessProof;
        uint256 timestamp;
        bool isVerified;
        bool isActive;
        string verificationProvider;
    }

    mapping(address => FaceVerification) public faceVerifications;
    mapping(bytes32 => bool) public usedFaceHashes;

    IVerificationLogger public verificationLogger;
    IUserIdentityRegistry public userRegistry;
    ITrustScore public trustScore;

    uint256 public constant FACE_VERIFICATION_SCORE = 25;

    event FaceVerificationRequested(
        address indexed user,
        bytes32 faceHashCommitment
    );
    event FaceVerificationCompleted(
        address indexed user,
        bool success,
        string provider
    );
    event FaceVerificationRevoked(address indexed user, string reason);

    constructor(
        address _verificationLogger,
        address _userRegistry,
        address _trustScore
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);

        verificationLogger = IVerificationLogger(_verificationLogger);
        userRegistry = IUserIdentityRegistry(_userRegistry);
        trustScore = ITrustScore(_trustScore);
    }

    function requestFaceVerification(
        bytes32 faceHashCommitment,
        bytes32 livenessProof
    ) external nonReentrant {
        require(userRegistry.isRegistered(msg.sender), "User not registered");
        require(
            !faceVerifications[msg.sender].isActive,
            "Face verification already active"
        );
        require(!usedFaceHashes[faceHashCommitment], "Face hash already used");
        require(faceHashCommitment != bytes32(0), "Invalid face hash");
        require(livenessProof != bytes32(0), "Invalid liveness proof");

        faceVerifications[msg.sender] = FaceVerification({
            user: msg.sender,
            faceHashCommitment: faceHashCommitment,
            livenessProof: livenessProof,
            timestamp: block.timestamp,
            isVerified: false,
            isActive: true,
            verificationProvider: ""
        });

        usedFaceHashes[faceHashCommitment] = true;

        verificationLogger.logEvent(
            "FACE_VERIFICATION_REQUESTED",
            msg.sender,
            faceHashCommitment
        );

        emit FaceVerificationRequested(msg.sender, faceHashCommitment);
    }

    function completeFaceVerification(
        address user,
        bool success,
        string memory verificationProvider,
        bytes memory oracleSignature
    ) external onlyRole(ORACLE_ROLE) {
        require(
            faceVerifications[user].isActive,
            "No active face verification"
        );
        require(bytes(verificationProvider).length > 0, "Provider required");

        // Verify oracle signature (simplified)
        require(
            _verifyOracleSignature(user, success, oracleSignature),
            "Invalid oracle signature"
        );

        faceVerifications[user].isVerified = success;
        faceVerifications[user].verificationProvider = verificationProvider;

        if (success) {
            // Update user registry
            userRegistry.updateVerificationStatus(user, "face", true);

            // Update trust score
            trustScore.updateScore(
                user,
                int256(FACE_VERIFICATION_SCORE),
                "Face verification completed"
            );
        } else {
            faceVerifications[user].isActive = false;
        }

        verificationLogger.logEvent(
            success ? "FACE_VERIFICATION_SUCCESS" : "FACE_VERIFICATION_FAILED",
            user,
            keccak256(abi.encodePacked(verificationProvider, success))
        );

        emit FaceVerificationCompleted(user, success, verificationProvider);
    }

    function revokeFaceVerification(
        address user,
        string memory reason
    ) external onlyRole(VERIFIER_ROLE) {
        require(faceVerifications[user].isVerified, "Face not verified");

        faceVerifications[user].isVerified = false;
        faceVerifications[user].isActive = false;

        // Update user registry
        userRegistry.updateVerificationStatus(user, "face", false);

        // Deduct trust score
        trustScore.updateScore(
            user,
            -int256(FACE_VERIFICATION_SCORE),
            "Face verification revoked"
        );

        verificationLogger.logEvent(
            "FACE_VERIFICATION_REVOKED",
            user,
            keccak256(bytes(reason))
        );

        emit FaceVerificationRevoked(user, reason);
    }

    function isFaceVerified(address user) external view returns (bool) {
        return
            faceVerifications[user].isVerified &&
            faceVerifications[user].isActive;
    }

    function getFaceVerificationInfo(
        address user
    )
        external
        view
        returns (
            bytes32 faceHashCommitment,
            uint256 timestamp,
            bool isVerified,
            string memory verificationProvider
        )
    {
        FaceVerification memory verification = faceVerifications[user];
        return (
            verification.faceHashCommitment,
            verification.timestamp,
            verification.isVerified,
            verification.verificationProvider
        );
    }

    function _verifyOracleSignature(
        address user,
        bool success,
        bytes memory signature
    ) private pure returns (bool) {
        // Simplified signature verification - in production use proper ECDSA verification
        return signature.length > 0 && user != address(0);
    }
}
