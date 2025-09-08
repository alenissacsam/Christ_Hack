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

interface IAadhaarVerificationManager {
    function isAadhaarVerified(address user) external view returns (bool);
}

contract IncomeVerificationManager is AccessControl, ReentrancyGuard {
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant INCOME_ORACLE_ROLE =
        keccak256("INCOME_ORACLE_ROLE");

    enum IncomeRange {
        Below1Lakh, // < 1,00,000
        Lakh1to5, // 1,00,000 - 5,00,000
        Lakh5to10, // 5,00,000 - 10,00,000
        Lakh10to25, // 10,00,000 - 25,00,000
        Above25Lakh // > 25,00,000
    }

    struct IncomeVerification {
        address user;
        bytes32 incomeProofHash;
        IncomeRange incomeRange;
        uint256 timestamp;
        bool isVerified;
        bool isActive;
        string verificationSource; // "ITR", "BankStatement", "SalarySlip", "GST"
    }

    mapping(address => IncomeVerification) public incomeVerifications;

    IVerificationLogger public verificationLogger;
    IUserIdentityRegistry public userRegistry;
    ITrustScore public trustScore;
    IAadhaarVerificationManager public aadhaarVerificationManager;

    uint256 public constant INCOME_VERIFICATION_SCORE = 25; // Optional verification

    event IncomeVerificationRequested(
        address indexed user,
        IncomeRange incomeRange
    );
    event IncomeVerificationCompleted(
        address indexed user,
        bool success,
        string source
    );
    event IncomeVerificationRevoked(address indexed user, string reason);

    constructor(
        address _verificationLogger,
        address _userRegistry,
        address _trustScore,
        address _aadhaarVerificationManager
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
        _grantRole(INCOME_ORACLE_ROLE, msg.sender);

        verificationLogger = IVerificationLogger(_verificationLogger);
        userRegistry = IUserIdentityRegistry(_userRegistry);
        trustScore = ITrustScore(_trustScore);
        aadhaarVerificationManager = IAadhaarVerificationManager(
            _aadhaarVerificationManager
        );
    }

    function requestIncomeVerification(
        bytes32 incomeProofHash,
        IncomeRange incomeRange,
        string memory verificationSource
    ) external nonReentrant {
        require(userRegistry.isRegistered(msg.sender), "User not registered");
        require(
            aadhaarVerificationManager.isAadhaarVerified(msg.sender),
            "Aadhaar verification required"
        );
        require(
            !incomeVerifications[msg.sender].isActive,
            "Income verification already active"
        );
        require(incomeProofHash != bytes32(0), "Invalid income proof hash");

        bytes32 sourceHash = keccak256(bytes(verificationSource));
        require(
            sourceHash == keccak256("ITR") ||
                sourceHash == keccak256("BankStatement") ||
                sourceHash == keccak256("SalarySlip") ||
                sourceHash == keccak256("GST"),
            "Invalid verification source"
        );

        incomeVerifications[msg.sender] = IncomeVerification({
            user: msg.sender,
            incomeProofHash: incomeProofHash,
            incomeRange: incomeRange,
            timestamp: block.timestamp,
            isVerified: false,
            isActive: true,
            verificationSource: verificationSource
        });

        verificationLogger.logEvent(
            "INCOME_VERIFICATION_REQUESTED",
            msg.sender,
            incomeProofHash
        );

        emit IncomeVerificationRequested(msg.sender, incomeRange);
    }

    function completeIncomeVerification(
        address user,
        bool success,
        bytes memory oracleSignature
    ) external onlyRole(INCOME_ORACLE_ROLE) {
        require(
            incomeVerifications[user].isActive,
            "No active income verification"
        );

        // Verify oracle signature (simplified)
        require(
            _verifyOracleSignature(user, success, oracleSignature),
            "Invalid oracle signature"
        );

        incomeVerifications[user].isVerified = success;

        if (success) {
            // Update user registry
            userRegistry.updateVerificationStatus(user, "income", true);

            // Update trust score with bonus based on income range
            uint256 bonus = _calculateIncomeBonus(
                incomeVerifications[user].incomeRange
            );
            trustScore.updateScore(
                user,
                int256(INCOME_VERIFICATION_SCORE + bonus),
                "Income verification completed"
            );
        } else {
            incomeVerifications[user].isActive = false;
        }

        verificationLogger.logEvent(
            success
                ? "INCOME_VERIFICATION_SUCCESS"
                : "INCOME_VERIFICATION_FAILED",
            user,
            keccak256(
                abi.encodePacked(
                    incomeVerifications[user].verificationSource,
                    success
                )
            )
        );

        emit IncomeVerificationCompleted(
            user,
            success,
            incomeVerifications[user].verificationSource
        );
    }

    function revokeIncomeVerification(
        address user,
        string memory reason
    ) external onlyRole(VERIFIER_ROLE) {
        require(incomeVerifications[user].isVerified, "Income not verified");

        uint256 deductionAmount = INCOME_VERIFICATION_SCORE +
            _calculateIncomeBonus(incomeVerifications[user].incomeRange);

        incomeVerifications[user].isVerified = false;
        incomeVerifications[user].isActive = false;

        // Update user registry
        userRegistry.updateVerificationStatus(user, "income", false);

        // Deduct trust score
        trustScore.updateScore(
            user,
            -int256(deductionAmount),
            "Income verification revoked"
        );

        verificationLogger.logEvent(
            "INCOME_VERIFICATION_REVOKED",
            user,
            keccak256(bytes(reason))
        );

        emit IncomeVerificationRevoked(user, reason);
    }

    function isIncomeVerified(address user) external view returns (bool) {
        return
            incomeVerifications[user].isVerified &&
            incomeVerifications[user].isActive;
    }

    function getIncomeVerificationInfo(
        address user
    )
        external
        view
        returns (
            IncomeRange incomeRange,
            uint256 timestamp,
            bool isVerified,
            string memory verificationSource
        )
    {
        IncomeVerification memory verification = incomeVerifications[user];
        return (
            verification.incomeRange,
            verification.timestamp,
            verification.isVerified,
            verification.verificationSource
        );
    }

    function _calculateIncomeBonus(
        IncomeRange range
    ) private pure returns (uint256) {
        if (range == IncomeRange.Below1Lakh) return 0;
        if (range == IncomeRange.Lakh1to5) return 5;
        if (range == IncomeRange.Lakh5to10) return 10;
        if (range == IncomeRange.Lakh10to25) return 15;
        if (range == IncomeRange.Above25Lakh) return 20;
        return 0;
    }

    function _verifyOracleSignature(
        address user,
        bool success,
        bytes memory signature
    ) private pure returns (bool) {
        // Simplified oracle signature verification - in production use proper verification
        return signature.length > 0 && user != address(0);
    }
}
