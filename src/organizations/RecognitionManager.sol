// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

interface IVerificationLogger {
    function logEvent(
        string memory eventType,
        address user,
        bytes32 dataHash
    ) external;
}

interface ITrustScore {
    function getTrustScore(address user) external view returns (uint256);

    function updateScore(
        address user,
        int256 delta,
        string memory reason
    ) external;
}

contract RecognitionManager is ERC1155, AccessControl {
    bytes32 public constant BADGE_ADMIN_ROLE = keccak256("BADGE_ADMIN_ROLE");

    uint256 private _badgeIdCounter;

    enum BadgeType {
        CertificateEarner,
        TrustedMember,
        ActiveParticipant,
        HighReputation,
        CrossChainUser,
        OrganizationPartner
    }

    struct Badge {
        uint256 id;
        BadgeType badgeType;
        string name;
        string description;
        string imageURI;
        uint256 requiredTrustScore;
        uint256 maxSupply;
        uint256 currentSupply;
        bool isActive;
    }

    mapping(uint256 => Badge) public badges;
    mapping(address => mapping(uint256 => uint256)) public userBadges;
    mapping(address => uint256[]) public userBadgeList;

    ITrustScore public trustScore;
    IVerificationLogger public verificationLogger;

    event BadgeCreated(
        uint256 indexed badgeId,
        BadgeType badgeType,
        string name
    );
    event BadgeAwarded(uint256 indexed badgeId, address indexed recipient);
    event BadgeRevoked(uint256 indexed badgeId, address indexed user);

    constructor(
        address _trustScore,
        address _verificationLogger
    ) ERC1155("https://api.educert.org/badge/{id}.json") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BADGE_ADMIN_ROLE, msg.sender);

        trustScore = ITrustScore(_trustScore);
        verificationLogger = IVerificationLogger(_verificationLogger);

        _createDefaultBadges();
    }

    function createBadge(
        BadgeType badgeType,
        string memory name,
        string memory description,
        string memory imageURI,
        uint256 requiredTrustScore,
        uint256 maxSupply
    ) external onlyRole(BADGE_ADMIN_ROLE) returns (uint256) {
        _badgeIdCounter++;
        uint256 badgeId = _badgeIdCounter;

        badges[badgeId] = Badge({
            id: badgeId,
            badgeType: badgeType,
            name: name,
            description: description,
            imageURI: imageURI,
            requiredTrustScore: requiredTrustScore,
            maxSupply: maxSupply,
            currentSupply: 0,
            isActive: true
        });

        emit BadgeCreated(badgeId, badgeType, name);
        return badgeId;
    }

    function awardBadge(
        uint256 badgeId,
        address recipient
    ) external onlyRole(BADGE_ADMIN_ROLE) {
        require(badges[badgeId].isActive, "Badge not active");
        require(
            badges[badgeId].currentSupply < badges[badgeId].maxSupply ||
                badges[badgeId].maxSupply == 0,
            "Max supply reached"
        );
        require(userBadges[recipient][badgeId] == 0, "Badge already awarded");

        uint256 userTrustScore = trustScore.getTrustScore(recipient);
        require(
            userTrustScore >= badges[badgeId].requiredTrustScore,
            "Insufficient trust score"
        );

        badges[badgeId].currentSupply++;
        userBadges[recipient][badgeId] = 1;
        userBadgeList[recipient].push(badgeId);

        _mint(recipient, badgeId, 1, "");

        // Update trust score for earning badge
        trustScore.updateScore(recipient, 5, "Badge awarded");

        verificationLogger.logEvent(
            "BADGE_AWARDED",
            recipient,
            keccak256(abi.encodePacked(badgeId, badges[badgeId].name))
        );

        emit BadgeAwarded(badgeId, recipient);
    }

    function autoAwardBasedOnCertificates(address user) external {
        uint256 userTrustScore = trustScore.getTrustScore(user);

        // Auto-award Certificate Earner badge
        if (userTrustScore >= 10 && userBadges[user][1] == 0) {
            _awardBadgeInternal(1, user);
        }

        // Auto-award Trusted Member badge for high trust score
        if (userTrustScore >= 50 && userBadges[user][2] == 0) {
            _awardBadgeInternal(2, user);
        }

        // Auto-award High Reputation badge
        if (userTrustScore >= 100 && userBadges[user][4] == 0) {
            _awardBadgeInternal(4, user);
        }
    }

    function _awardBadgeInternal(uint256 badgeId, address recipient) private {
        if (
            badges[badgeId].isActive &&
            userBadges[recipient][badgeId] == 0 &&
            (badges[badgeId].currentSupply < badges[badgeId].maxSupply ||
                badges[badgeId].maxSupply == 0)
        ) {
            badges[badgeId].currentSupply++;
            userBadges[recipient][badgeId] = 1;
            userBadgeList[recipient].push(badgeId);

            _mint(recipient, badgeId, 1, "");

            trustScore.updateScore(recipient, 2, "Auto badge awarded");

            verificationLogger.logEvent(
                "BADGE_AUTO_AWARDED",
                recipient,
                keccak256(abi.encodePacked(badgeId))
            );

            emit BadgeAwarded(badgeId, recipient);
        }
    }

    function revokeBadge(
        uint256 badgeId,
        address user,
        string memory reason
    ) external onlyRole(BADGE_ADMIN_ROLE) {
        require(userBadges[user][badgeId] > 0, "Badge not owned");

        userBadges[user][badgeId] = 0;
        badges[badgeId].currentSupply--;

        _burn(user, badgeId, 1);

        // Remove from user's badge list
        _removeFromBadgeList(user, badgeId);

        trustScore.updateScore(user, -2, "Badge revoked");

        verificationLogger.logEvent(
            "BADGE_REVOKED",
            user,
            keccak256(abi.encodePacked(badgeId, reason))
        );

        emit BadgeRevoked(badgeId, user);
    }

    function getUserBadges(
        address user
    ) external view returns (uint256[] memory) {
        return userBadgeList[user];
    }

    function hasBadge(
        address user,
        uint256 badgeId
    ) external view returns (bool) {
        return userBadges[user][badgeId] > 0;
    }

    function _createDefaultBadges() private {
        // Certificate Earner Badge
        _badgeIdCounter++;
        badges[1] = Badge({
            id: 1,
            badgeType: BadgeType.CertificateEarner,
            name: "Certificate Earner",
            description: "Earned first certificate",
            imageURI: "certificate-earner.png",
            requiredTrustScore: 10,
            maxSupply: 0,
            currentSupply: 0,
            isActive: true
        });

        // Trusted Member Badge
        _badgeIdCounter++;
        badges[2] = Badge({
            id: 2,
            badgeType: BadgeType.TrustedMember,
            name: "Trusted Member",
            description: "Established trust in the community",
            imageURI: "trusted-member.png",
            requiredTrustScore: 50,
            maxSupply: 0,
            currentSupply: 0,
            isActive: true
        });

        // High Reputation Badge
        _badgeIdCounter++;
        badges[4] = Badge({
            id: 4,
            badgeType: BadgeType.HighReputation,
            name: "High Reputation",
            description: "Achieved high reputation score",
            imageURI: "high-reputation.png",
            requiredTrustScore: 100,
            maxSupply: 0,
            currentSupply: 0,
            isActive: true
        });
    }

    function _removeFromBadgeList(address user, uint256 badgeId) private {
        uint256[] storage badges_list = userBadgeList[user];
        for (uint256 i = 0; i < badges_list.length; i++) {
            if (badges_list[i] == badgeId) {
                badges_list[i] = badges_list[badges_list.length - 1];
                badges_list.pop();
                break;
            }
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
