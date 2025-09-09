// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IVerificationLogger {
    function logEvent(string memory eventType, address user, bytes32 dataHash) external;
}

interface ITrustScore {
    function getTrustScore(address user) external view returns (uint256);
    function updateScore(address user, int256 delta, string memory reason) external;
}

interface ICertificateManager {
    function getCertificatesByHolder(address holder) external view returns (uint256[] memory);
}

contract RecognitionManager is 
    Initializable,
    ERC1155Upgradeable, 
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant BADGE_ADMIN_ROLE = keccak256("BADGE_ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 private _badgeIdCounter;

    enum BadgeType {
        Achievement,      // General achievements
        Milestone,       // Progress milestones
        Certification,   // Certification completion
        Participation,   // Event participation
        Leadership,      // Leadership roles
        Community,       // Community contribution
        Skill,          // Skill demonstration
        Special         // Special recognition
    }

    enum BadgeRarity {
        Common,         // Easy to obtain
        Uncommon,       // Moderate difficulty
        Rare,           // Difficult to obtain
        Epic,           // Very difficult
        Legendary       // Extremely rare
    }

    struct Badge {
        uint256 id;
        BadgeType badgeType;
        BadgeRarity rarity;
        string name;
        string description;
        string imageURI;
        string externalURL;
        uint256 requiredTrustScore;
        uint256 maxSupply;
        uint256 currentSupply;
        bool isActive;
        bool isTransferable;
        uint256 createdAt;
        address creator;
        bytes32 criteriaHash; // Hash of the criteria for earning this badge
        uint256 validityPeriod; // 0 = permanent, >0 = expires after this duration
    }

    struct UserBadgeInfo {
        uint256 earnedAt;
        uint256 expiresAt;
        bool isRevoked;
        string earnReason;
        bytes32 evidenceHash;
    }

    mapping(uint256 => Badge) public badges;
    mapping(address => mapping(uint256 => UserBadgeInfo)) public userBadges;
    mapping(address => uint256[]) public userBadgeList;
    mapping(BadgeType => uint256[]) public badgesByType;
    mapping(BadgeRarity => uint256[]) public badgesByRarity;
    
    ITrustScore public trustScore;
    IVerificationLogger public verificationLogger;
    ICertificateManager public certificateManager;

    // Badge earning automation rules
    mapping(uint256 => uint256) public trustScoreThresholds; // badgeId => trustScore required
    mapping(uint256 => uint256) public certificateCountThresholds; // badgeId => certificate count required

    event BadgeCreated(uint256 indexed badgeId, BadgeType badgeType, BadgeRarity rarity, string name, address creator);
    event BadgeAwarded(uint256 indexed badgeId, address indexed recipient, string reason);
    event BadgeRevoked(uint256 indexed badgeId, address indexed user, string reason);
    event BadgeExpired(uint256 indexed badgeId, address indexed user);
    event BadgeRenewed(uint256 indexed badgeId, address indexed user, uint256 newExpiryDate);
    event BadgeUpdated(uint256 indexed badgeId, string field);
    event AutoBadgeAwarded(uint256 indexed badgeId, address indexed recipient, string trigger);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _trustScore,
        address _verificationLogger,
        address _certificateManager
    ) public initializer {
        __ERC1155_init("https://api.educert.org/badge/{id}.json");
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BADGE_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        trustScore = ITrustScore(_trustScore);
        verificationLogger = IVerificationLogger(_verificationLogger);
        certificateManager = ICertificateManager(_certificateManager);

        _createDefaultBadges();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function createBadge(
        BadgeType badgeType,
        BadgeRarity rarity,
        string memory name,
        string memory description,
        string memory imageURI,
        string memory externalURL,
        uint256 requiredTrustScore,
        uint256 maxSupply,
        bool isTransferable,
        bytes32 criteriaHash,
        uint256 validityPeriod
    ) external onlyRole(BADGE_ADMIN_ROLE) returns (uint256) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");

        _badgeIdCounter++;
        uint256 badgeId = _badgeIdCounter;

        badges[badgeId] = Badge({
            id: badgeId,
            badgeType: badgeType,
            rarity: rarity,
            name: name,
            description: description,
            imageURI: imageURI,
            externalURL: externalURL,
            requiredTrustScore: requiredTrustScore,
            maxSupply: maxSupply,
            currentSupply: 0,
            isActive: true,
            isTransferable: isTransferable,
            createdAt: block.timestamp,
            creator: msg.sender,
            criteriaHash: criteriaHash,
            validityPeriod: validityPeriod
        });

        badgesByType[badgeType].push(badgeId);
        badgesByRarity[rarity].push(badgeId);

        verificationLogger.logEvent(
            "BADGE_CREATED",
            msg.sender,
            keccak256(abi.encodePacked(badgeId, name, uint256(badgeType), uint256(rarity)))
        );

        emit BadgeCreated(badgeId, badgeType, rarity, name, msg.sender);
        return badgeId;
    }

    function awardBadge(
        uint256 badgeId,
        address recipient,
        string memory reason,
        bytes32 evidenceHash
    ) public onlyRole(MINTER_ROLE) nonReentrant {
        require(badges[badgeId].isActive, "Badge not active");
        require(badges[badgeId].currentSupply < badges[badgeId].maxSupply || badges[badgeId].maxSupply == 0, "Max supply reached");
        require(balanceOf(recipient, badgeId) == 0, "Badge already awarded");

        uint256 userTrustScore = trustScore.getTrustScore(recipient);
        require(userTrustScore >= badges[badgeId].requiredTrustScore, "Insufficient trust score");

        // Calculate expiry date
        uint256 expiresAt = badges[badgeId].validityPeriod > 0 ? 
            block.timestamp + badges[badgeId].validityPeriod : 0;

        userBadges[recipient][badgeId] = UserBadgeInfo({
            earnedAt: block.timestamp,
            expiresAt: expiresAt,
            isRevoked: false,
            earnReason: reason,
            evidenceHash: evidenceHash
        });

        badges[badgeId].currentSupply++;
        userBadgeList[recipient].push(badgeId);

        _mint(recipient, badgeId, 1, "");

        // Award trust score based on badge rarity
        int256 trustScoreReward = _getBadgeTrustScore(badges[badgeId].rarity);
        trustScore.updateScore(recipient, trustScoreReward, "Badge earned");

        verificationLogger.logEvent(
            "BADGE_AWARDED",
            recipient,
            keccak256(abi.encodePacked(badgeId, reason, evidenceHash))
        );

        emit BadgeAwarded(badgeId, recipient, reason);
    }

    function revokeBadge(
        uint256 badgeId,
        address user,
        string memory reason
    ) external onlyRole(BADGE_ADMIN_ROLE) {
        require(balanceOf(user, badgeId) > 0, "Badge not owned");
        require(!userBadges[user][badgeId].isRevoked, "Badge already revoked");

        userBadges[user][badgeId].isRevoked = true;
        badges[badgeId].currentSupply--;

        _burn(user, badgeId, 1);
        _removeFromBadgeList(user, badgeId);

        // Deduct trust score
        int256 trustScorePenalty = -_getBadgeTrustScore(badges[badgeId].rarity);
        trustScore.updateScore(user, trustScorePenalty, "Badge revoked");

        verificationLogger.logEvent(
            "BADGE_REVOKED",
            user,
            keccak256(abi.encodePacked(badgeId, reason))
        );

        emit BadgeRevoked(badgeId, user, reason);
    }

    function renewBadge(uint256 badgeId, address user) external onlyRole(MINTER_ROLE) {
        require(balanceOf(user, badgeId) > 0, "Badge not owned");
        require(!userBadges[user][badgeId].isRevoked, "Badge is revoked");
        require(badges[badgeId].validityPeriod > 0, "Badge is permanent");

        UserBadgeInfo storage badgeInfo = userBadges[user][badgeId];
        badgeInfo.expiresAt = block.timestamp + badges[badgeId].validityPeriod;

        verificationLogger.logEvent(
            "BADGE_RENEWED",
            user,
            keccak256(abi.encodePacked(badgeId, badgeInfo.expiresAt))
        );

        emit BadgeRenewed(badgeId, user, badgeInfo.expiresAt);
    }

    function checkAndExpireBadges(address[] memory users) external {
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256[] memory userBadgeIds = userBadgeList[user];
            
            for (uint256 j = 0; j < userBadgeIds.length; j++) {
                uint256 badgeId = userBadgeIds[j];
                UserBadgeInfo memory badgeInfo = userBadges[user][badgeId];
                
                if (badgeInfo.expiresAt > 0 && 
                    block.timestamp > badgeInfo.expiresAt && 
                    !badgeInfo.isRevoked &&
                    balanceOf(user, badgeId) > 0) {
                    
                    _expireBadge(badgeId, user);
                }
            }
        }
    }

    function autoAwardBasedOnCriteria(address user) external {
        uint256 userTrustScore = trustScore.getTrustScore(user);
        uint256[] memory userCertificates = certificateManager.getCertificatesByHolder(user);

        // Check trust score based badges
        for (uint256 i = 1; i <= _badgeIdCounter; i++) {
            if (badges[i].isActive && 
                balanceOf(user, i) == 0 && 
                userTrustScore >= badges[i].requiredTrustScore &&
                badges[i].currentSupply < badges[i].maxSupply || badges[i].maxSupply == 0) {
                
                // Auto-award based on trust score milestones
                if (_shouldAutoAward(i, userTrustScore, userCertificates.length)) {
                    _autoAward(i, user);
                }
            }
        }
    }

    function batchAwardBadges(
        uint256[] memory badgeIds,
        address[] memory recipients,
        string[] memory reasons,
        bytes32[] memory evidenceHashes
    ) external onlyRole(MINTER_ROLE) {
        require(
            badgeIds.length == recipients.length && 
            recipients.length == reasons.length && 
            reasons.length == evidenceHashes.length,
            "Array lengths must match"
        );

        for (uint256 i = 0; i < badgeIds.length; i++) {
            awardBadge(badgeIds[i], recipients[i], reasons[i], evidenceHashes[i]);
        }
    }

    function updateBadge(
        uint256 badgeId,
        string memory imageURI,
        string memory externalURL,
        uint256 requiredTrustScore,
        bool isActive
    ) external onlyRole(BADGE_ADMIN_ROLE) {
        require(badges[badgeId].id != 0, "Badge does not exist");

        badges[badgeId].imageURI = imageURI;
        badges[badgeId].externalURL = externalURL;
        badges[badgeId].requiredTrustScore = requiredTrustScore;
        badges[badgeId].isActive = isActive;

        verificationLogger.logEvent(
            "BADGE_UPDATED",
            msg.sender,
            keccak256(abi.encodePacked(badgeId, imageURI))
        );

        emit BadgeUpdated(badgeId, "metadata");
    }

    function setBadgeTransferability(uint256 badgeId, bool isTransferable) external onlyRole(BADGE_ADMIN_ROLE) {
        require(badges[badgeId].id != 0, "Badge does not exist");
        badges[badgeId].isTransferable = isTransferable;
        emit BadgeUpdated(badgeId, "transferability");
    }

    function getUserBadges(address user) external view returns (uint256[] memory) {
        return userBadgeList[user];
    }

    function getUserBadgeInfo(address user, uint256 badgeId) external view returns (
        uint256 earnedAt,
        uint256 expiresAt,
        bool isRevoked,
        bool isExpired,
        string memory earnReason
    ) {
        UserBadgeInfo memory info = userBadges[user][badgeId];
        bool expired = info.expiresAt > 0 && block.timestamp > info.expiresAt;
        
        return (
            info.earnedAt,
            info.expiresAt,
            info.isRevoked,
            expired,
            info.earnReason
        );
    }

    function getBadgesByType(BadgeType badgeType) external view returns (uint256[] memory) {
        return badgesByType[badgeType];
    }

    function getBadgesByRarity(BadgeRarity rarity) external view returns (uint256[] memory) {
        return badgesByRarity[rarity];
    }

    function hasBadge(address user, uint256 badgeId) external view returns (bool) {
        return balanceOf(user, badgeId) > 0 && !userBadges[user][badgeId].isRevoked;
    }

    function isValidBadge(address user, uint256 badgeId) external view returns (bool) {
        if (balanceOf(user, badgeId) == 0 || userBadges[user][badgeId].isRevoked) return false;
        
        UserBadgeInfo memory info = userBadges[user][badgeId];
        if (info.expiresAt > 0 && block.timestamp > info.expiresAt) return false;
        
        return true;
    }

    function getBadgeStats() external view returns (
        uint256 totalBadges,
        uint256 totalAwarded,
        uint256 activeBadges
    ) {
        totalBadges = _badgeIdCounter;
        
        uint256 awarded = 0;
        uint256 active = 0;
        
        for (uint256 i = 1; i <= _badgeIdCounter; i++) {
            awarded += badges[i].currentSupply;
            if (badges[i].isActive) active++;
        }
        
        totalAwarded = awarded;
        activeBadges = active;
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        require(badges[tokenId].id != 0, "Badge does not exist");
        
        if (bytes(badges[tokenId].imageURI).length > 0) {
            return badges[tokenId].imageURI;
        }
        
        return super.uri(tokenId);
    }

    function _shouldAutoAward(uint256 badgeId, uint256 userTrustScore, uint256 certificateCount) private view returns (bool) {
        // Auto-award logic based on predefined criteria
        Badge memory badge = badges[badgeId];
        
        // Trust score milestone badges
        if (badge.badgeType == BadgeType.Milestone) {
            if (badgeId == 1 && userTrustScore >= 25) return true;  // First Steps
            if (badgeId == 2 && userTrustScore >= 100) return true; // Trusted Member
            if (badgeId == 3 && userTrustScore >= 250) return true; // Expert
            if (badgeId == 4 && userTrustScore >= 500) return true; // Master
        }
        
        // Certificate count badges
        if (badge.badgeType == BadgeType.Achievement) {
            if (badgeId == 5 && certificateCount >= 1) return true;  // First Certificate
            if (badgeId == 6 && certificateCount >= 5) return true;  // Certificate Collector
            if (badgeId == 7 && certificateCount >= 10) return true; // Certification Expert
        }
        
        return false;
    }

    function _autoAward(uint256 badgeId, address user) private {
        userBadges[user][badgeId] = UserBadgeInfo({
            earnedAt: block.timestamp,
            expiresAt: badges[badgeId].validityPeriod > 0 ? block.timestamp + badges[badgeId].validityPeriod : 0,
            isRevoked: false,
            earnReason: "Auto-awarded based on criteria",
            evidenceHash: keccak256(abi.encodePacked("auto", badgeId, user, block.timestamp))
        });

        badges[badgeId].currentSupply++;
        userBadgeList[user].push(badgeId);

        _mint(user, badgeId, 1, "");

        int256 trustScoreReward = _getBadgeTrustScore(badges[badgeId].rarity);
        trustScore.updateScore(user, trustScoreReward, "Auto badge awarded");

        verificationLogger.logEvent(
            "BADGE_AUTO_AWARDED",
            user,
            keccak256(abi.encodePacked(badgeId, "auto-criteria"))
        );

        emit AutoBadgeAwarded(badgeId, user, "criteria-met");
    }

    function _expireBadge(uint256 badgeId, address user) private {
        userBadges[user][badgeId].isRevoked = true;
        badges[badgeId].currentSupply--;

        _burn(user, badgeId, 1);
        _removeFromBadgeList(user, badgeId);

        verificationLogger.logEvent(
            "BADGE_EXPIRED",
            user,
            keccak256(abi.encodePacked(badgeId))
        );

        emit BadgeExpired(badgeId, user);
    }

    function _getBadgeTrustScore(BadgeRarity rarity) private pure returns (int256) {
        if (rarity == BadgeRarity.Legendary) return 50;
        if (rarity == BadgeRarity.Epic) return 25;
        if (rarity == BadgeRarity.Rare) return 15;
        if (rarity == BadgeRarity.Uncommon) return 8;
        if (rarity == BadgeRarity.Common) return 3;
        return 2;
    }

    function _removeFromBadgeList(address user, uint256 badgeId) private {
        uint256[] storage badgeList = userBadgeList[user];
        for (uint256 i = 0; i < badgeList.length; i++) {
            if (badgeList[i] == badgeId) {
                badgeList[i] = badgeList[badgeList.length - 1];
                badgeList.pop();
                break;
            }
        }
    }

    function _createDefaultBadges() private {
        // Milestone badges
        _badgeIdCounter = 1;
        badges[1] = Badge({
            id: 1,
            badgeType: BadgeType.Milestone,
            rarity: BadgeRarity.Common,
            name: "First Steps",
            description: "Reached 25 trust score",
            imageURI: "first-steps.png",
            externalURL: "",
            requiredTrustScore: 25,
            maxSupply: 0,
            currentSupply: 0,
            isActive: true,
            isTransferable: false,
            createdAt: block.timestamp,
            creator: msg.sender,
            criteriaHash: keccak256("trust_score_25"),
            validityPeriod: 0
        });

        _badgeIdCounter = 2;
        badges[2] = Badge({
            id: 2,
            badgeType: BadgeType.Milestone,
            rarity: BadgeRarity.Uncommon,
            name: "Trusted Member",
            description: "Reached 100 trust score",
            imageURI: "trusted-member.png",
            externalURL: "",
            requiredTrustScore: 100,
            maxSupply: 0,
            currentSupply: 0,
            isActive: true,
            isTransferable: false,
            createdAt: block.timestamp,
            creator: msg.sender,
            criteriaHash: keccak256("trust_score_100"),
            validityPeriod: 0
        });

        // Achievement badges
        _badgeIdCounter = 5;
        badges[5] = Badge({
            id: 5,
            badgeType: BadgeType.Achievement,
            rarity: BadgeRarity.Common,
            name: "First Certificate",
            description: "Earned first certificate",
            imageURI: "first-certificate.png",
            externalURL: "",
            requiredTrustScore: 10,
            maxSupply: 0,
            currentSupply: 0,
            isActive: true,
            isTransferable: false,
            createdAt: block.timestamp,
            creator: msg.sender,
            criteriaHash: keccak256("certificate_count_1"),
            validityPeriod: 0
        });

        badgesByType[BadgeType.Milestone].push(1);
        badgesByType[BadgeType.Milestone].push(2);
        badgesByType[BadgeType.Achievement].push(5);
        
        badgesByRarity[BadgeRarity.Common].push(1);
        badgesByRarity[BadgeRarity.Common].push(5);
        badgesByRarity[BadgeRarity.Uncommon].push(2);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(badges[id].isTransferable, "Badge is not transferable");
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        for (uint256 i = 0; i < ids.length; i++) {
            require(badges[ids[i]].isTransferable, "Badge is not transferable");
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155Upgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}