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

interface IEconomicIncentives {
    function slash(address user, string memory reason) external;
}

interface ITrustScore {
    function updateScore(
        address user,
        int256 delta,
        string memory reason
    ) external;
}

contract DisputeResolution is AccessControl, ReentrancyGuard {
    bytes32 public constant ARBITRATOR_ROLE = keccak256("ARBITRATOR_ROLE");
    bytes32 public constant DISPUTE_ADMIN_ROLE =
        keccak256("DISPUTE_ADMIN_ROLE");

    enum DisputeStatus {
        Pending,
        UnderReview,
        Resolved,
        Rejected,
        Appealed
    }

    enum DisputeType {
        CertificateValidity,
        OrganizationMisbehavior,
        FalseIdentity,
        TechnicalIssue,
        Other
    }

    struct Dispute {
        uint256 id;
        address challenger;
        address respondent;
        DisputeType disputeType;
        string title;
        string description;
        string evidenceURI;
        uint256 challengeBond;
        uint256 createdAt;
        uint256 reviewDeadline;
        DisputeStatus status;
        bool challengerWon;
        address[] arbitrators;
        mapping(address => bool) hasVoted;
        mapping(address => bool) votes; // true = challenger wins, false = respondent wins
        uint256 votesFor;
        uint256 votesAgainst;
    }

    mapping(uint256 => Dispute) public disputes;
    mapping(address => uint256[]) public userDisputes;
    mapping(address => bool) public isArbitrator;

    uint256 public disputeCounter;
    uint256 public challengeBondAmount = 50 * 10 ** 18; // 50 tokens
    uint256 public reviewPeriod = 7 days;
    uint256 public minArbitrators = 3;

    address[] public activeArbitrators;

    IVerificationLogger public verificationLogger;
    IEconomicIncentives public economicIncentives;
    ITrustScore public trustScore;

    event DisputeCreated(
        uint256 indexed disputeId,
        address indexed challenger,
        address indexed respondent,
        DisputeType disputeType
    );

    event DisputeResolved(
        uint256 indexed disputeId,
        bool challengerWon,
        address indexed resolver
    );

    event ArbitratorVoted(
        uint256 indexed disputeId,
        address indexed arbitrator,
        bool vote
    );

    constructor(
        address _verificationLogger,
        address _economicIncentives,
        address _trustScore
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISPUTE_ADMIN_ROLE, msg.sender);

        verificationLogger = IVerificationLogger(_verificationLogger);
        economicIncentives = IEconomicIncentives(_economicIncentives);
        trustScore = ITrustScore(_trustScore);
    }

    function createDispute(
        address respondent,
        DisputeType disputeType,
        string memory title,
        string memory description,
        string memory evidenceURI
    ) external payable nonReentrant returns (uint256) {
        require(
            msg.value >= challengeBondAmount,
            "Insufficient challenge bond"
        );
        require(
            respondent != address(0) && respondent != msg.sender,
            "Invalid respondent"
        );
        require(bytes(title).length > 0, "Title required");

        disputeCounter++;
        uint256 disputeId = disputeCounter;

        Dispute storage newDispute = disputes[disputeId];
        newDispute.id = disputeId;
        newDispute.challenger = msg.sender;
        newDispute.respondent = respondent;
        newDispute.disputeType = disputeType;
        newDispute.title = title;
        newDispute.description = description;
        newDispute.evidenceURI = evidenceURI;
        newDispute.challengeBond = msg.value;
        newDispute.createdAt = block.timestamp;
        newDispute.reviewDeadline = block.timestamp + reviewPeriod;
        newDispute.status = DisputeStatus.Pending;

        // Assign random arbitrators
        _assignArbitrators(disputeId);

        userDisputes[msg.sender].push(disputeId);
        userDisputes[respondent].push(disputeId);

        verificationLogger.logEvent(
            "DISPUTE_CREATED",
            msg.sender,
            keccak256(abi.encodePacked(disputeId, title))
        );

        emit DisputeCreated(disputeId, msg.sender, respondent, disputeType);

        return disputeId;
    }

    function voteOnDispute(
        uint256 disputeId,
        bool vote
    ) external onlyRole(ARBITRATOR_ROLE) {
        Dispute storage dispute = disputes[disputeId];
        require(
            dispute.status == DisputeStatus.UnderReview,
            "Dispute not under review"
        );
        require(
            block.timestamp <= dispute.reviewDeadline,
            "Review period expired"
        );
        require(!dispute.hasVoted[msg.sender], "Already voted");
        require(
            _isAssignedArbitrator(disputeId, msg.sender),
            "Not assigned arbitrator"
        );

        dispute.hasVoted[msg.sender] = true;
        dispute.votes[msg.sender] = vote;

        if (vote) {
            dispute.votesFor++;
        } else {
            dispute.votesAgainst++;
        }

        verificationLogger.logEvent(
            "ARBITRATOR_VOTED",
            msg.sender,
            keccak256(abi.encodePacked(disputeId, vote))
        );

        emit ArbitratorVoted(disputeId, msg.sender, vote);

        // Check if voting is complete
        if (dispute.votesFor + dispute.votesAgainst >= minArbitrators) {
            _resolveDispute(disputeId);
        }
    }

    function resolveDispute(uint256 disputeId) external {
        Dispute storage dispute = disputes[disputeId];
        require(
            dispute.status == DisputeStatus.UnderReview,
            "Dispute not under review"
        );
        require(
            block.timestamp > dispute.reviewDeadline ||
                dispute.votesFor + dispute.votesAgainst >= minArbitrators,
            "Cannot resolve yet"
        );

        _resolveDispute(disputeId);
    }

    function _resolveDispute(uint256 disputeId) private {
        Dispute storage dispute = disputes[disputeId];

        dispute.challengerWon = dispute.votesFor > dispute.votesAgainst;
        dispute.status = DisputeStatus.Resolved;

        if (dispute.challengerWon) {
            // Challenger wins - gets bond back and respondent is penalized
            payable(dispute.challenger).transfer(dispute.challengeBond);

            // Slash respondent and update trust scores
            economicIncentives.slash(dispute.respondent, "Lost dispute");
            trustScore.updateScore(dispute.challenger, 10, "Won dispute");
            trustScore.updateScore(dispute.respondent, -15, "Lost dispute");
        } else {
            // Respondent wins - challenger loses bond, respondent gets rewarded
            payable(dispute.respondent).transfer(dispute.challengeBond);

            trustScore.updateScore(dispute.challenger, -5, "Lost dispute");
            trustScore.updateScore(dispute.respondent, 5, "Won dispute");
        }

        verificationLogger.logEvent(
            "DISPUTE_RESOLVED",
            dispute.challengerWon ? dispute.challenger : dispute.respondent,
            keccak256(abi.encodePacked(disputeId, dispute.challengerWon))
        );

        emit DisputeResolved(disputeId, dispute.challengerWon, msg.sender);
    }

    function addArbitrator(
        address arbitrator
    ) external onlyRole(DISPUTE_ADMIN_ROLE) {
        require(!isArbitrator[arbitrator], "Already an arbitrator");

        isArbitrator[arbitrator] = true;
        activeArbitrators.push(arbitrator);
        _grantRole(ARBITRATOR_ROLE, arbitrator);

        verificationLogger.logEvent("ARBITRATOR_ADDED", arbitrator, bytes32(0));
    }

    function removeArbitrator(
        address arbitrator
    ) external onlyRole(DISPUTE_ADMIN_ROLE) {
        require(isArbitrator[arbitrator], "Not an arbitrator");

        isArbitrator[arbitrator] = false;
        _revokeRole(ARBITRATOR_ROLE, arbitrator);
        _removeFromArbitratorList(arbitrator);

        verificationLogger.logEvent(
            "ARBITRATOR_REMOVED",
            arbitrator,
            bytes32(0)
        );
    }

    function getDispute(
        uint256 disputeId
    )
        external
        view
        returns (
            uint256 id,
            address challenger,
            address respondent,
            DisputeType disputeType,
            string memory title,
            DisputeStatus status,
            bool challengerWon,
            uint256 votesFor,
            uint256 votesAgainst
        )
    {
        Dispute storage dispute = disputes[disputeId];
        return (
            dispute.id,
            dispute.challenger,
            dispute.respondent,
            dispute.disputeType,
            dispute.title,
            dispute.status,
            dispute.challengerWon,
            dispute.votesFor,
            dispute.votesAgainst
        );
    }

    function getUserDisputes(
        address user
    ) external view returns (uint256[] memory) {
        return userDisputes[user];
    }

    function getActiveArbitrators() external view returns (address[] memory) {
        return activeArbitrators;
    }

    function _assignArbitrators(uint256 disputeId) private {
        require(
            activeArbitrators.length >= minArbitrators,
            "Not enough arbitrators"
        );

        Dispute storage dispute = disputes[disputeId];

        // Simple random assignment (in production, use better randomness)
        uint256 seed = uint256(
            keccak256(abi.encodePacked(block.timestamp, disputeId))
        );

        for (uint256 i = 0; i < minArbitrators; i++) {
            uint256 index = (seed + i) % activeArbitrators.length;
            dispute.arbitrators.push(activeArbitrators[index]);
        }

        dispute.status = DisputeStatus.UnderReview;
    }

    function _isAssignedArbitrator(
        uint256 disputeId,
        address arbitrator
    ) private view returns (bool) {
        Dispute storage dispute = disputes[disputeId];
        for (uint256 i = 0; i < dispute.arbitrators.length; i++) {
            if (dispute.arbitrators[i] == arbitrator) {
                return true;
            }
        }
        return false;
    }

    function _removeFromArbitratorList(address arbitrator) private {
        for (uint256 i = 0; i < activeArbitrators.length; i++) {
            if (activeArbitrators[i] == arbitrator) {
                activeArbitrators[i] = activeArbitrators[
                    activeArbitrators.length - 1
                ];
                activeArbitrators.pop();
                break;
            }
        }
    }
}
