// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IVerificationLogger {
    function logEvent(string memory eventType, address user, bytes32 dataHash) external;
}

interface IUserIdentityRegistry {
    function updateVerificationStatus(address user, string memory verificationType, bool status) external;
    function isRegistered(address user) external view returns (bool);
    function isIdentityLocked(address user) external view returns (bool);
}

interface ITrustScore {
    function updateScore(address user, int256 delta, string memory reason) external;
}

contract FaceVerificationManager is 
    Initializable,
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable 
{
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    struct FaceVerification {
        address user;
        bytes32 faceHashCommitment;
        bytes32 livenessProof;
        uint256 timestamp;
        bool isVerified;
        bool isActive;
        string verificationProvider;
        uint256 retryCount;
        uint256 lastRetry;
    }

    mapping(address => FaceVerification) public faceVerifications;
    mapping(bytes32 => bool) public usedFaceHashes;
    mapping(address => uint256) public failedAttempts;
    
    IVerificationLogger public verificationLogger;
    IUserIdentityRegistry public userRegistry;
    ITrustScore public trustScore;

    uint256 public constant FACE_VERIFICATION_SCORE = 25;
    uint256 public constant MAX_RETRY_ATTEMPTS = 3;
    uint256 public constant RETRY_COOLDOWN = 1 hours;
    uint256 public constant MAX_FAILED_ATTEMPTS = 5;

    event FaceVerificationRequested(address indexed user, bytes32 faceHashCommitment);
    event FaceVerificationCompleted(address indexed user, bool success, string provider);
    event FaceVerificationRevoked(address indexed user, string reason);
    event RetryAttempt(address indexed user, uint256 attemptNumber);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _verificationLogger,
        address _userRegistry,
        address _trustScore
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        verificationLogger = IVerificationLogger(_verificationLogger);
        userRegistry = IUserIdentityRegistry(_userRegistry);
        trustScore = ITrustScore(_trustScore);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function requestFaceVerification(
        bytes32 faceHashCommitment,
        bytes32 livenessProof
    ) external nonReentrant {
        require(userRegistry.isRegistered(msg.sender), "User not registered");
        require(!userRegistry.isIdentityLocked(msg.sender), "Identity is locked");
        require(!faceVerifications[msg.sender].isActive, "Face verification already active");
        require(!usedFaceHashes[faceHashCommitment], "Face hash already used");
        require(faceHashCommitment != bytes32(0), "Invalid face hash");
        require(livenessProof != bytes32(0), "Invalid liveness proof");
        require(failedAttempts[msg.sender] < MAX_FAILED_ATTEMPTS, "Too many failed attempts");

        // Check retry cooldown
        FaceVerification storage existing = faceVerifications[msg.sender];
        if (existing.retryCount > 0) {
            require(
                block.timestamp >= existing.lastRetry + RETRY_COOLDOWN,
                "Retry cooldown not expired"
            );
        }

        faceVerifications[msg.sender] = FaceVerification({
            user: msg.sender,
            faceHashCommitment: faceHashCommitment,
            livenessProof: livenessProof,
            timestamp: block.timestamp,
            isVerified: false,
            isActive: true,
            verificationProvider: "",
            retryCount: existing.retryCount + 1,
            lastRetry: block.timestamp
        });

        usedFaceHashes[faceHashCommitment] = true;

        verificationLogger.logEvent(
            "FACE_VERIFICATION_REQUESTED",
            msg.sender,
            faceHashCommitment
        );

        emit FaceVerificationRequested(msg.sender, faceHashCommitment);
        
        if (existing.retryCount > 0) {
            emit RetryAttempt(msg.sender, existing.retryCount + 1);
        }
    }

    function completeFaceVerification(
        address user,
        bool success,
        string memory verificationProvider,
        bytes memory oracleSignature
    ) public onlyRole(ORACLE_ROLE) {
        require(faceVerifications[user].isActive, "No active face verification");
        require(bytes(verificationProvider).length > 0, "Provider required");
        require(_verifyOracleSignature(user, success, oracleSignature), "Invalid oracle signature");

        faceVerifications[user].isVerified = success;
        faceVerifications[user].verificationProvider = verificationProvider;

        if (success) {
            userRegistry.updateVerificationStatus(user, "face", true);
            trustScore.updateScore(user, int256(FACE_VERIFICATION_SCORE), "Face verification completed");
            
            // Reset failed attempts on success
            failedAttempts[user] = 0;
        } else {
            faceVerifications[user].isActive = false;
            failedAttempts[user]++;
            
            // Apply penalty for failed verification
            trustScore.updateScore(user, -5, "Face verification failed");
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

        userRegistry.updateVerificationStatus(user, "face", false);
        trustScore.updateScore(user, -int256(FACE_VERIFICATION_SCORE), "Face verification revoked");

        verificationLogger.logEvent(
            "FACE_VERIFICATION_REVOKED",
            user,
            keccak256(bytes(reason))
        );

        emit FaceVerificationRevoked(user, reason);
    }

    function resetFailedAttempts(address user) external onlyRole(VERIFIER_ROLE) {
        failedAttempts[user] = 0;
        
        verificationLogger.logEvent(
            "FACE_VERIFICATION_ATTEMPTS_RESET",
            user,
            bytes32(0)
        );
    }

    function bulkCompleteFaceVerification(
        address[] memory users,
        bool[] memory successes,
        string[] memory providers,
        bytes[] memory signatures
    ) external onlyRole(ORACLE_ROLE) {
        require(
            users.length == successes.length && 
            successes.length == providers.length && 
            providers.length == signatures.length,
            "Array lengths must match"
        );

        for (uint256 i = 0; i < users.length; i++) {
            if (faceVerifications[users[i]].isActive) {
                completeFaceVerification(users[i], successes[i], providers[i], signatures[i]);
            }
        }
    }

    function isFaceVerified(address user) external view returns (bool) {
        return faceVerifications[user].isVerified && faceVerifications[user].isActive;
    }

    function getFaceVerificationInfo(address user) external view returns (
        bytes32 faceHashCommitment,
        uint256 timestamp,
        bool isVerified,
        string memory verificationProvider,
        uint256 retryCount,
        uint256 failedAttemptCount
    ) {
        FaceVerification memory verification = faceVerifications[user];
        return (
            verification.faceHashCommitment,
            verification.timestamp,
            verification.isVerified,
            verification.verificationProvider,
            verification.retryCount,
            failedAttempts[user]
        );
    }

    function canRetryVerification(address user) external view returns (bool) {
        if (failedAttempts[user] >= MAX_FAILED_ATTEMPTS) return false;
        if (faceVerifications[user].retryCount >= MAX_RETRY_ATTEMPTS) return false;
        
        FaceVerification memory verification = faceVerifications[user];
        if (verification.retryCount > 0) {
            return block.timestamp >= verification.lastRetry + RETRY_COOLDOWN;
        }
        
        return true;
    }

    function getVerificationStats() external view returns (
        uint256 totalRequests,
        uint256 successfulVerifications,
        uint256 failedVerifications,
        uint256 activeRequests
    ) {
        // This would require additional state tracking in production
        // For now, return placeholder values
        return (0, 0, 0, 0);
    }

    function _verifyOracleSignature(
        address user,
        bool success,
        bytes memory signature
    ) private pure returns (bool) {
        // Simplified signature verification - in production use proper ECDSA verification
        // This should verify that the oracle signed the (user, success) data
        return signature.length > 0 && user != address(0);
    }
}