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

interface ITrustScore {
    function initializeUser(address user) external;
}

contract UserIdentityRegistry is AccessControl, ReentrancyGuard {
    bytes32 public constant REGISTRY_MANAGER_ROLE =
        keccak256("REGISTRY_MANAGER_ROLE");

    struct Identity {
        bytes32 identityCommitment;
        uint256 registeredAt;
        bool isActive;
        string metadataURI;
        bool faceVerified;
        bool aadhaarVerified;
        bool incomeVerified;
        uint256 verificationLevel; // 0=none, 1=face, 2=face+aadhaar, 3=all
    }

    mapping(address => Identity) public identities;
    mapping(bytes32 => bool) public nullifiers;
    mapping(bytes32 => address) public commitmentToAddress;

    IVerificationLogger public verificationLogger;
    ITrustScore public trustScore;

    event IdentityRegistered(address indexed user, bytes32 indexed commitment);
    event IdentityDeregistered(address indexed user);
    event IdentityUpdated(address indexed user, bytes32 newCommitment);
    event VerificationStatusUpdated(
        address indexed user,
        string verificationType,
        bool status
    );

    constructor(address _verificationLogger, address _trustScore) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGISTRY_MANAGER_ROLE, msg.sender);

        verificationLogger = IVerificationLogger(_verificationLogger);
        trustScore = ITrustScore(_trustScore);
    }

    function registerIdentity(
        address user,
        bytes32 identityCommitment
    ) external onlyRole(REGISTRY_MANAGER_ROLE) nonReentrant {
        require(user != address(0), "Invalid user address");
        require(identityCommitment != bytes32(0), "Invalid commitment");
        require(!identities[user].isActive, "Identity already registered");
        require(!nullifiers[identityCommitment], "Commitment already used");

        identities[user] = Identity({
            identityCommitment: identityCommitment,
            registeredAt: block.timestamp,
            isActive: true,
            metadataURI: "",
            faceVerified: false,
            aadhaarVerified: false,
            incomeVerified: false,
            verificationLevel: 0
        });

        nullifiers[identityCommitment] = true;
        commitmentToAddress[identityCommitment] = user;

        // Initialize trust score for new user
        trustScore.initializeUser(user);

        verificationLogger.logEvent(
            "IDENTITY_REGISTERED",
            user,
            identityCommitment
        );

        emit IdentityRegistered(user, identityCommitment);
    }

    function updateVerificationStatus(
        address user,
        string memory verificationType,
        bool status
    ) external onlyRole(REGISTRY_MANAGER_ROLE) {
        require(identities[user].isActive, "Identity not registered");

        bytes32 verificationHash = keccak256(bytes(verificationType));

        if (verificationHash == keccak256("face")) {
            identities[user].faceVerified = status;
        } else if (verificationHash == keccak256("aadhaar")) {
            identities[user].aadhaarVerified = status;
        } else if (verificationHash == keccak256("income")) {
            identities[user].incomeVerified = status;
        } else {
            revert("Invalid verification type");
        }

        // Update verification level
        uint256 level = 0;
        if (identities[user].faceVerified) level = 1;
        if (identities[user].faceVerified && identities[user].aadhaarVerified)
            level = 2;
        if (
            identities[user].faceVerified &&
            identities[user].aadhaarVerified &&
            identities[user].incomeVerified
        ) level = 3;

        identities[user].verificationLevel = level;

        verificationLogger.logEvent(
            "VERIFICATION_STATUS_UPDATED",
            user,
            keccak256(abi.encodePacked(verificationType, status))
        );

        emit VerificationStatusUpdated(user, verificationType, status);
    }

    function isRegistered(address user) external view returns (bool) {
        return identities[user].isActive;
    }

    function getVerificationStatus(
        address user
    )
        external
        view
        returns (
            bool faceVerified,
            bool aadhaarVerified,
            bool incomeVerified,
            uint256 verificationLevel
        )
    {
        Identity memory identity = identities[user];
        return (
            identity.faceVerified,
            identity.aadhaarVerified,
            identity.incomeVerified,
            identity.verificationLevel
        );
    }

    function getIdentityCommitment(
        address user
    ) external view returns (bytes32) {
        require(identities[user].isActive, "Identity not registered");
        return identities[user].identityCommitment;
    }
}
