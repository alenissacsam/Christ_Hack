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

contract PrivacyManager is AccessControl, ReentrancyGuard {
    bytes32 public constant PRIVACY_ADMIN_ROLE =
        keccak256("PRIVACY_ADMIN_ROLE");

    enum ConsentType {
        DataCollection,
        DataProcessing,
        DataSharing,
        MarketingCommunication,
        ThirdPartyAccess,
        CrossChainSync
    }

    struct ConsentRecord {
        bool granted;
        uint256 timestamp;
        string purpose;
        uint256 expiresAt;
    }

    struct PrivacyPreferences {
        bool allowPublicProfile;
        bool allowCertificateSharing;
        bool allowReputationDisplay;
        bool allowCrossChainSync;
        uint256 dataRetentionPeriod;
        string preferredDataRegion;
    }

    struct SelectiveDisclosure {
        address requester;
        string[] allowedAttributes;
        uint256 expiresAt;
        bool isActive;
        string purpose;
    }

    mapping(address => mapping(ConsentType => ConsentRecord)) public consents;
    mapping(address => PrivacyPreferences) public privacyPreferences;
    mapping(address => mapping(address => SelectiveDisclosure))
        public disclosures;
    mapping(address => address[]) public userDisclosureList;
    mapping(address => bool) public dataErasureRequests;
    mapping(address => uint256) public dataErasureRequestTime;

    IVerificationLogger public verificationLogger;

    uint256 public defaultDataRetention = 365 days * 5; // 5 years
    uint256 public erasureProcessingTime = 30 days;

    event ConsentUpdated(
        address indexed user,
        ConsentType indexed consentType,
        bool granted,
        string purpose
    );

    event PrivacyPreferencesUpdated(address indexed user);
    event SelectiveDisclosureGranted(
        address indexed user,
        address indexed requester
    );
    event SelectiveDisclosureRevoked(
        address indexed user,
        address indexed requester
    );
    event DataErasureRequested(address indexed user);
    event DataErased(address indexed user);

    constructor(address _verificationLogger) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PRIVACY_ADMIN_ROLE, msg.sender);

        verificationLogger = IVerificationLogger(_verificationLogger);
    }

    function updateConsent(
        ConsentType consentType,
        bool granted,
        string memory purpose,
        uint256 duration
    ) external nonReentrant {
        uint256 expiresAt = granted ? block.timestamp + duration : 0;

        consents[msg.sender][consentType] = ConsentRecord({
            granted: granted,
            timestamp: block.timestamp,
            purpose: purpose,
            expiresAt: expiresAt
        });

        verificationLogger.logEvent(
            "CONSENT_UPDATED",
            msg.sender,
            keccak256(abi.encodePacked(uint256(consentType), granted, purpose))
        );

        emit ConsentUpdated(msg.sender, consentType, granted, purpose);
    }

    function updatePrivacyPreferences(
        bool allowPublicProfile,
        bool allowCertificateSharing,
        bool allowReputationDisplay,
        bool allowCrossChainSync,
        uint256 dataRetentionPeriod,
        string memory preferredDataRegion
    ) external {
        require(dataRetentionPeriod >= 30 days, "Minimum retention 30 days");
        require(
            dataRetentionPeriod <= 10 * 365 days,
            "Maximum retention 10 years"
        );

        privacyPreferences[msg.sender] = PrivacyPreferences({
            allowPublicProfile: allowPublicProfile,
            allowCertificateSharing: allowCertificateSharing,
            allowReputationDisplay: allowReputationDisplay,
            allowCrossChainSync: allowCrossChainSync,
            dataRetentionPeriod: dataRetentionPeriod,
            preferredDataRegion: preferredDataRegion
        });

        verificationLogger.logEvent(
            "PRIVACY_PREFERENCES_UPDATED",
            msg.sender,
            keccak256(
                abi.encodePacked(
                    allowPublicProfile,
                    allowCertificateSharing,
                    preferredDataRegion
                )
            )
        );

        emit PrivacyPreferencesUpdated(msg.sender);
    }

    function grantSelectiveDisclosure(
        address requester,
        string[] memory allowedAttributes,
        uint256 duration,
        string memory purpose
    ) external nonReentrant {
        require(requester != address(0), "Invalid requester");
        require(allowedAttributes.length > 0, "No attributes specified");
        require(duration > 0, "Invalid duration");

        disclosures[msg.sender][requester] = SelectiveDisclosure({
            requester: requester,
            allowedAttributes: allowedAttributes,
            expiresAt: block.timestamp + duration,
            isActive: true,
            purpose: purpose
        });

        // Add to user's disclosure list if not already present
        bool exists = false;
        for (uint256 i = 0; i < userDisclosureList[msg.sender].length; i++) {
            if (userDisclosureList[msg.sender][i] == requester) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            userDisclosureList[msg.sender].push(requester);
        }

        verificationLogger.logEvent(
            "SELECTIVE_DISCLOSURE_GRANTED",
            msg.sender,
            keccak256(abi.encodePacked(requester, purpose))
        );

        emit SelectiveDisclosureGranted(msg.sender, requester);
    }

    function revokeSelectiveDisclosure(address requester) external {
        require(
            disclosures[msg.sender][requester].isActive,
            "No active disclosure"
        );

        disclosures[msg.sender][requester].isActive = false;

        verificationLogger.logEvent(
            "SELECTIVE_DISCLOSURE_REVOKED",
            msg.sender,
            keccak256(abi.encodePacked(requester))
        );

        emit SelectiveDisclosureRevoked(msg.sender, requester);
    }

    function requestDataErasure() external nonReentrant {
        require(!dataErasureRequests[msg.sender], "Erasure already requested");

        dataErasureRequests[msg.sender] = true;
        dataErasureRequestTime[msg.sender] = block.timestamp;

        verificationLogger.logEvent(
            "DATA_ERASURE_REQUESTED",
            msg.sender,
            bytes32(block.timestamp)
        );

        emit DataErasureRequested(msg.sender);
    }

    function processDataErasure(
        address user
    ) external onlyRole(PRIVACY_ADMIN_ROLE) {
        require(dataErasureRequests[user], "No erasure request");
        require(
            block.timestamp >=
                dataErasureRequestTime[user] + erasureProcessingTime,
            "Processing time not elapsed"
        );

        // Reset all consents
        for (uint256 i = 0; i <= uint256(ConsentType.CrossChainSync); i++) {
            delete consents[user][ConsentType(i)];
        }

        // Reset privacy preferences to default
        delete privacyPreferences[user];

        // Revoke all selective disclosures
        address[] memory disclosureList = userDisclosureList[user];
        for (uint256 i = 0; i < disclosureList.length; i++) {
            delete disclosures[user][disclosureList[i]];
        }
        delete userDisclosureList[user];

        // Mark as processed
        dataErasureRequests[user] = false;
        delete dataErasureRequestTime[user];

        verificationLogger.logEvent(
            "DATA_ERASED",
            user,
            bytes32(block.timestamp)
        );

        emit DataErased(user);
    }

    function hasValidConsent(
        address user,
        ConsentType consentType
    ) external view returns (bool) {
        ConsentRecord memory consent = consents[user][consentType];
        return
            consent.granted &&
            (consent.expiresAt == 0 || block.timestamp <= consent.expiresAt);
    }

    function canAccessAttribute(
        address user,
        address requester,
        string memory attribute
    ) external view returns (bool) {
        SelectiveDisclosure memory disclosure = disclosures[user][requester];

        if (!disclosure.isActive || block.timestamp > disclosure.expiresAt) {
            return false;
        }

        for (uint256 i = 0; i < disclosure.allowedAttributes.length; i++) {
            if (
                keccak256(bytes(disclosure.allowedAttributes[i])) ==
                keccak256(bytes(attribute))
            ) {
                return true;
            }
        }

        return false;
    }

    function getPrivacyPreferences(
        address user
    ) external view returns (PrivacyPreferences memory) {
        return privacyPreferences[user];
    }

    function getUserDisclosures(
        address user
    ) external view returns (address[] memory) {
        return userDisclosureList[user];
    }

    function getSelectiveDisclosure(
        address user,
        address requester
    )
        external
        view
        returns (
            string[] memory allowedAttributes,
            uint256 expiresAt,
            bool isActive,
            string memory purpose
        )
    {
        SelectiveDisclosure memory disclosure = disclosures[user][requester];
        return (
            disclosure.allowedAttributes,
            disclosure.expiresAt,
            disclosure.isActive,
            disclosure.purpose
        );
    }
}
