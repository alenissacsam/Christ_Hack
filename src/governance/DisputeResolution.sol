// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IVerificationLogger {
    function logEvent(string memory eventType, address user, bytes32 dataHash) external;
}

interface IEconomicIncentives {
    function slash(address user, string memory reason) external;
}

interface ITrustScore {
    function getTrustScore(address user) external view returns (uint256);
    function updateScore(address user, int256 delta, string memory reason) external;
}

interface ISystemToken {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DisputeResolution is 
    Initializable,
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable 
{
    bytes32 public constant ARBITRATOR_ROLE = keccak256("ARBITRATOR_ROLE");
    bytes32 public constant DISPUTE_ADMIN_ROLE = keccak256("DISPUTE_ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    enum DisputeStatus {
        Pending,        // Just created, waiting for arbitrators
        UnderReview,    // Arbitrators assigned, review in progress
        VotingPhase,    // Evidence submitted, voting phase
        Resolved,       // Decision made
        Appealed,       // Decision appealed
        Executed,       // Resolution executed
        Rejected,       // Dispute rejected
        Expired         // Dispute expired
    }

    enum DisputeType {
        CertificateValidity,     // Challenge certificate authenticity
        OrganizationMisbehavior, // Report organization misconduct
        FalseIdentity,          // Challenge user identity
        TechnicalIssue,         // Technical system issues
        GovernanceDispute,      // Governance-related disputes
        TokenDispute,           // Token/economic disputes
        Other                   // Other disputes
    }

    struct Dispute {
        uint256 id;
        address challenger;
        address respondent;
        DisputeType disputeType;
        string title;
        string description;
        string evidenceURI;
        bytes32 evidenceHash;
        uint256 challengeBond;
        uint256 createdAt;
        uint256 reviewDeadline;
        uint256 votingDeadline;
        uint256 executionDeadline;
        DisputeStatus status;
        bool challengerWon;
        address[] assignedArbitrators;
        mapping(address => ArbitratorVote) votes;
        uint256 votesFor;      // Votes supporting challenger
        uint256 votesAgainst;  // Votes supporting respondent
        uint256 totalVotes;
        string resolutionReason;
        bytes32 resolutionHash;
    }

    struct ArbitratorVote {
        bool hasVoted;
        bool supportsChallenger; // true = challenger wins, false = respondent wins
        uint256 timestamp;
        string reasoning;
        uint256 confidence; // 1-100 scale
    }

    struct DisputeEvidence {
        address submitter;
        string evidenceType; // "document", "witness", "technical", "other"
        string evidenceURI;
        bytes32 evidenceHash;
        uint256 submittedAt;
        string description;
    }

    struct ArbitratorStats {
        uint256 totalCases;
        uint256 correctDecisions;
        uint256 reputation;
        bool isActive;
        uint256 joinedAt;
    }

    mapping(uint256 => Dispute) public disputes;
    mapping(uint256 => DisputeEvidence[]) public disputeEvidence;
    mapping(address => uint256[]) public userDisputes; // All disputes involving user
    mapping(address => uint256[]) public challengerDisputes; // Disputes user created
    mapping(address => uint256[]) public respondentDisputes; // Disputes against user
    mapping(address => ArbitratorStats) public arbitratorStats;
    mapping(address => bool) public isArbitrator;

    uint256 public disputeCounter;
    address[] public activeArbitrators;
    
    IVerificationLogger public verificationLogger;
    IEconomicIncentives public economicIncentives;
    ITrustScore public trustScore;
    ISystemToken public systemToken;

    // Dispute parameters
    uint256 public challengeBondAmount; // Required bond to create dispute
    uint256 public reviewPeriod; // Time for evidence submission
    uint256 public votingPeriod; // Time for arbitrator voting
    uint256 public executionPeriod; // Time to execute resolution
    uint256 public minArbitrators; // Minimum arbitrators per dispute
    uint256 public maxArbitrators; // Maximum arbitrators per dispute
    uint256 public requiredArbitratorTrustScore; // Minimum trust score for arbitrators

    event DisputeCreated(uint256 indexed disputeId, address indexed challenger, address indexed respondent, DisputeType disputeType);
    event EvidenceSubmitted(uint256 indexed disputeId, address indexed submitter, string evidenceType);
    event ArbitratorsAssigned(uint256 indexed disputeId, address[] arbitrators);
    event ArbitratorVoted(uint256 indexed disputeId, address indexed arbitrator, bool supportsChallenger, uint256 confidence);
    event DisputeResolved(uint256 indexed disputeId, bool challengerWon, string reason);
    event DisputeExecuted(uint256 indexed disputeId, address indexed executor);
    event DisputeAppealed(uint256 indexed disputeId, address indexed appellant);
    event ArbitratorAdded(address indexed arbitrator);
    event ArbitratorRemoved(address indexed arbitrator, string reason);
    event BondClaimed(uint256 indexed disputeId, address indexed claimer, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _verificationLogger,
        address _economicIncentives,
        address _trustScore,
        address _systemToken
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISPUTE_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        verificationLogger = IVerificationLogger(_verificationLogger);
        economicIncentives = IEconomicIncentives(_economicIncentives);
        trustScore = ITrustScore(_trustScore);
        systemToken = ISystemToken(_systemToken);

        // Default parameters
        challengeBondAmount = 100 * 10**18; // 100 tokens
        reviewPeriod = 7 days;
        votingPeriod = 5 days;
        executionPeriod = 3 days;
        minArbitrators = 3;
        maxArbitrators = 7;
        requiredArbitratorTrustScore = 100;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function createDispute(
        address respondent,
        DisputeType disputeType,
        string memory title,
        string memory description,
        string memory evidenceURI,
        bytes32 evidenceHash
    ) external nonReentrant returns (uint256) {
        require(respondent != address(0) && respondent != msg.sender, "Invalid respondent");
        require(bytes(title).length > 0, "Title required");
        require(bytes(description).length > 0, "Description required");
        require(systemToken.balanceOf(msg.sender) >= challengeBondAmount, "Insufficient balance for bond");

        // Transfer challenge bond to contract
        require(
            systemToken.transferFrom(msg.sender, address(this), challengeBondAmount),
            "Bond transfer failed"
        );

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
        newDispute.evidenceHash = evidenceHash;
        newDispute.challengeBond = challengeBondAmount;
        newDispute.createdAt = block.timestamp;
        newDispute.reviewDeadline = block.timestamp + reviewPeriod;
        newDispute.status = DisputeStatus.Pending;

        // Add initial evidence if provided
        if (bytes(evidenceURI).length > 0) {
            disputeEvidence[disputeId].push(DisputeEvidence({
                submitter: msg.sender,
                evidenceType: "initial",
                evidenceURI: evidenceURI,
                evidenceHash: evidenceHash,
                submittedAt: block.timestamp,
                description: "Initial dispute evidence"
            }));
        }

        userDisputes[msg.sender].push(disputeId);
        userDisputes[respondent].push(disputeId);
        challengerDisputes[msg.sender].push(disputeId);
        respondentDisputes[respondent].push(disputeId);

        // Assign arbitrators
        _assignArbitrators(disputeId);

        // Deduct trust score for creating dispute (to prevent spam)
        trustScore.updateScore(msg.sender, -5, "Created dispute");

        verificationLogger.logEvent(
            "DISPUTE_CREATED",
            msg.sender,
            keccak256(abi.encodePacked(disputeId, title, uint256(disputeType)))
        );

        emit DisputeCreated(disputeId, msg.sender, respondent, disputeType);
        return disputeId;
    }

    function submitEvidence(
        uint256 disputeId,
        string memory evidenceType,
        string memory evidenceURI,
        bytes32 evidenceHash,
        string memory description
    ) external {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.id != 0, "Dispute does not exist");
        require(
            msg.sender == dispute.challenger || 
            msg.sender == dispute.respondent ||
            _isAssignedArbitrator(disputeId, msg.sender),
            "Not authorized to submit evidence"
        );
        require(
            dispute.status == DisputeStatus.Pending || dispute.status == DisputeStatus.UnderReview,
            "Evidence submission period ended"
        );
        require(block.timestamp <= dispute.reviewDeadline, "Evidence deadline passed");

        disputeEvidence[disputeId].push(DisputeEvidence({
            submitter: msg.sender,
            evidenceType: evidenceType,
            evidenceURI: evidenceURI,
            evidenceHash: evidenceHash,
            submittedAt: block.timestamp,
            description: description
        }));

        verificationLogger.logEvent(
            "DISPUTE_EVIDENCE_SUBMITTED",
            msg.sender,
            keccak256(abi.encodePacked(disputeId, evidenceType, evidenceHash))
        );

        emit EvidenceSubmitted(disputeId, msg.sender, evidenceType);
    }

    function startVotingPhase(uint256 disputeId) external {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.id != 0, "Dispute does not exist");
        require(
            dispute.status == DisputeStatus.Pending || dispute.status == DisputeStatus.UnderReview,
            "Cannot start voting"
        );
        require(
            block.timestamp >= dispute.reviewDeadline || 
            hasRole(DISPUTE_ADMIN_ROLE, msg.sender),
            "Review period not ended"
        );

        dispute.status = DisputeStatus.VotingPhase;
        dispute.votingDeadline = block.timestamp + votingPeriod;

        verificationLogger.logEvent(
            "DISPUTE_VOTING_STARTED",
            msg.sender,
            keccak256(abi.encodePacked(disputeId))
        );
    }

    function voteOnDispute(
        uint256 disputeId,
        bool supportsChallenger,
        string memory reasoning,
        uint256 confidence
    ) external onlyRole(ARBITRATOR_ROLE) {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.VotingPhase, "Not in voting phase");
        require(block.timestamp <= dispute.votingDeadline, "Voting period expired");
        require(_isAssignedArbitrator(disputeId, msg.sender), "Not assigned arbitrator");
        require(!dispute.votes[msg.sender].hasVoted, "Already voted");
        require(confidence >= 1 && confidence <= 100, "Invalid confidence level");

        dispute.votes[msg.sender] = ArbitratorVote({
            hasVoted: true,
            supportsChallenger: supportsChallenger,
            timestamp: block.timestamp,
            reasoning: reasoning,
            confidence: confidence
        });

        dispute.totalVotes++;
        if (supportsChallenger) {
            dispute.votesFor++;
        } else {
            dispute.votesAgainst++;
        }

        // Update arbitrator stats
        arbitratorStats[msg.sender].totalCases++;

        verificationLogger.logEvent(
            "ARBITRATOR_VOTED",
            msg.sender,
            keccak256(abi.encodePacked(disputeId, supportsChallenger, confidence))
        );

        emit ArbitratorVoted(disputeId, msg.sender, supportsChallenger, confidence);

        // Check if enough votes to resolve
        if (dispute.totalVotes >= minArbitrators) {
            _checkAndResolveDispute(disputeId);
        }
    }

    function resolveDispute(uint256 disputeId, string memory reason) external onlyRole(DISPUTE_ADMIN_ROLE) {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.VotingPhase, "Not in voting phase");
        require(
            block.timestamp > dispute.votingDeadline || dispute.totalVotes >= minArbitrators,
            "Cannot resolve yet"
        );

        _resolveDispute(disputeId, reason);
    }

    function executeResolution(uint256 disputeId) external nonReentrant {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.Resolved, "Dispute not resolved");
        require(
            block.timestamp >= dispute.votingDeadline && 
            block.timestamp <= dispute.executionDeadline,
            "Execution window closed"
        );

        dispute.status = DisputeStatus.Executed;

        if (dispute.challengerWon) {
            // Challenger wins - gets bond back and compensation
            require(
                systemToken.transfer(dispute.challenger, dispute.challengeBond),
                "Challenger payment failed"
            );

            // Penalize respondent
            if (dispute.disputeType == DisputeType.OrganizationMisbehavior || 
                dispute.disputeType == DisputeType.FalseIdentity) {
                economicIncentives.slash(dispute.respondent, "Lost dispute");
            }

            // Update trust scores
            trustScore.updateScore(dispute.challenger, 15, "Won dispute");
            trustScore.updateScore(dispute.respondent, -20, "Lost dispute");
        } else {
            // Respondent wins - challenger loses bond, respondent gets compensation
            require(
                systemToken.transfer(dispute.respondent, dispute.challengeBond),
                "Respondent payment failed"
            );

            // Update trust scores
            trustScore.updateScore(dispute.challenger, -10, "Lost dispute");
            trustScore.updateScore(dispute.respondent, 10, "Won dispute");
        }

        // Update arbitrator reputations based on majority decision
        _updateArbitratorReputations(disputeId);

        verificationLogger.logEvent(
            "DISPUTE_EXECUTED",
            msg.sender,
            keccak256(abi.encodePacked(disputeId, dispute.challengerWon))
        );

        emit DisputeExecuted(disputeId, msg.sender);
    }

    function appealDispute(uint256 disputeId, string memory reason) external {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.Resolved, "Dispute not resolved");
        require(
            msg.sender == dispute.challenger || msg.sender == dispute.respondent,
            "Not authorized to appeal"
        );
        require(block.timestamp <= dispute.executionDeadline, "Appeal period expired");

        dispute.status = DisputeStatus.Appealed;
        // Reset for new round of arbitration
        dispute.totalVotes = 0;
        dispute.votesFor = 0;
        dispute.votesAgainst = 0;
        
        // Assign new arbitrators for appeal
        _assignArbitrators(disputeId);

        verificationLogger.logEvent(
            "DISPUTE_APPEALED",
            msg.sender,
            keccak256(abi.encodePacked(disputeId, reason))
        );

        emit DisputeAppealed(disputeId, msg.sender);
    }

    function addArbitrator(address arbitrator) external onlyRole(DISPUTE_ADMIN_ROLE) {
        require(!isArbitrator[arbitrator], "Already an arbitrator");
        require(trustScore.getTrustScore(arbitrator) >= requiredArbitratorTrustScore, "Insufficient trust score");

        isArbitrator[arbitrator] = true;
        activeArbitrators.push(arbitrator);
        
        arbitratorStats[arbitrator] = ArbitratorStats({
            totalCases: 0,
            correctDecisions: 0,
            reputation: 100, // Starting reputation
            isActive: true,
            joinedAt: block.timestamp
        });

        _grantRole(ARBITRATOR_ROLE, arbitrator);

        verificationLogger.logEvent(
            "ARBITRATOR_ADDED",
            arbitrator,
            bytes32(0)
        );

        emit ArbitratorAdded(arbitrator);
    }

    function removeArbitrator(address arbitrator, string memory reason) external onlyRole(DISPUTE_ADMIN_ROLE) {
        require(isArbitrator[arbitrator], "Not an arbitrator");

        isArbitrator[arbitrator] = false;
        arbitratorStats[arbitrator].isActive = false;
        
        _revokeRole(ARBITRATOR_ROLE, arbitrator);
        _removeFromArbitratorList(arbitrator);

        verificationLogger.logEvent(
            "ARBITRATOR_REMOVED",
            arbitrator,
            keccak256(bytes(reason))
        );

        emit ArbitratorRemoved(arbitrator, reason);
    }

    function updateDisputeParameters(
        uint256 _challengeBondAmount,
        uint256 _reviewPeriod,
        uint256 _votingPeriod,
        uint256 _minArbitrators
    ) external onlyRole(DISPUTE_ADMIN_ROLE) {
        require(_minArbitrators >= 3 && _minArbitrators <= 15, "Invalid arbitrator count");
        require(_reviewPeriod >= 1 days && _reviewPeriod <= 30 days, "Invalid review period");
        require(_votingPeriod >= 1 days && _votingPeriod <= 14 days, "Invalid voting period");

        challengeBondAmount = _challengeBondAmount;
        reviewPeriod = _reviewPeriod;
        votingPeriod = _votingPeriod;
        minArbitrators = _minArbitrators;
    }

    function getDispute(uint256 disputeId) external view returns (
        address challenger,
        address respondent,
        DisputeType disputeType,
        string memory title,
        DisputeStatus status,
        bool challengerWon,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 totalVotes,
        uint256 createdAt
    ) {
        Dispute storage dispute = disputes[disputeId];
        return (
            dispute.challenger,
            dispute.respondent,
            dispute.disputeType,
            dispute.title,
            dispute.status,
            dispute.challengerWon,
            dispute.votesFor,
            dispute.votesAgainst,
            dispute.totalVotes,
            dispute.createdAt
        );
    }

    function getDisputeEvidence(uint256 disputeId) external view returns (DisputeEvidence[] memory) {
        return disputeEvidence[disputeId];
    }

    function getUserDisputes(address user) external view returns (uint256[] memory) {
        return userDisputes[user];
    }

    function getActiveArbitrators() external view returns (address[] memory) {
        return activeArbitrators;
    }

    function getArbitratorStats(address arbitrator) external view returns (
        uint256 totalCases,
        uint256 correctDecisions,
        uint256 reputation,
        bool isActive
    ) {
        ArbitratorStats memory stats = arbitratorStats[arbitrator];
        return (stats.totalCases, stats.correctDecisions, stats.reputation, stats.isActive);
    }

    function _assignArbitrators(uint256 disputeId) private {
        require(activeArbitrators.length >= minArbitrators, "Not enough arbitrators");

        Dispute storage dispute = disputes[disputeId];
        
        // Use pseudo-randomness to select arbitrators
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, disputeId, dispute.challenger)));
        uint256 arbitratorCount = minArbitrators;
        
        // Increase arbitrator count for high-value disputes
        if (dispute.disputeType == DisputeType.GovernanceDispute || 
            dispute.disputeType == DisputeType.TokenDispute) {
            arbitratorCount = minArbitrators + 2;
        }

        for (uint256 i = 0; i < arbitratorCount && i < activeArbitrators.length; i++) {
            uint256 index = (seed + i) % activeArbitrators.length;
            dispute.assignedArbitrators.push(activeArbitrators[index]);
        }

        dispute.status = DisputeStatus.UnderReview;

        emit ArbitratorsAssigned(disputeId, dispute.assignedArbitrators);
    }

    function _isAssignedArbitrator(uint256 disputeId, address arbitrator) private view returns (bool) {
        Dispute storage dispute = disputes[disputeId];
        for (uint256 i = 0; i < dispute.assignedArbitrators.length; i++) {
            if (dispute.assignedArbitrators[i] == arbitrator) {
                return true;
            }
        }
        return false;
    }

    function _checkAndResolveDispute(uint256 disputeId) private {
        Dispute storage dispute = disputes[disputeId];
        
        if (dispute.totalVotes >= minArbitrators) {
            string memory reason = dispute.votesFor > dispute.votesAgainst ? 
                "Majority supports challenger" : 
                "Majority supports respondent";
            _resolveDispute(disputeId, reason);
        }
    }

    function _resolveDispute(uint256 disputeId, string memory reason) private {
        Dispute storage dispute = disputes[disputeId];
        
        dispute.challengerWon = dispute.votesFor > dispute.votesAgainst;
        dispute.status = DisputeStatus.Resolved;
        dispute.resolutionReason = reason;
        dispute.resolutionHash = keccak256(abi.encodePacked(reason, block.timestamp));
        dispute.executionDeadline = block.timestamp + executionPeriod;

        verificationLogger.logEvent(
            "DISPUTE_RESOLVED",
            dispute.challengerWon ? dispute.challenger : dispute.respondent,
            keccak256(abi.encodePacked(disputeId, dispute.challengerWon, reason))
        );

        emit DisputeResolved(disputeId, dispute.challengerWon, reason);
    }

    function _updateArbitratorReputations(uint256 disputeId) private {
        Dispute storage dispute = disputes[disputeId];
        bool majorityDecision = dispute.challengerWon;

        for (uint256 i = 0; i < dispute.assignedArbitrators.length; i++) {
            address arbitrator = dispute.assignedArbitrators[i];
            ArbitratorVote memory vote = dispute.votes[arbitrator];
            
            if (vote.hasVoted) {
                ArbitratorStats storage stats = arbitratorStats[arbitrator];
                
                if (vote.supportsChallenger == majorityDecision) {
                    // Correct decision
                    stats.correctDecisions++;
                    stats.reputation = stats.reputation + 5;
                    trustScore.updateScore(arbitrator, 3, "Correct arbitration decision");
                } else {
                    // Incorrect decision
                    if (stats.reputation > 5) stats.reputation -= 5;
                    trustScore.updateScore(arbitrator, -1, "Incorrect arbitration decision");
                }
            } else {
                // Didn't vote - penalty
                ArbitratorStats storage stats = arbitratorStats[arbitrator];
                if (stats.reputation > 10) stats.reputation -= 10;
                trustScore.updateScore(arbitrator, -5, "Failed to vote in arbitration");
            }
        }
    }

    function _removeFromArbitratorList(address arbitrator) private {
        for (uint256 i = 0; i < activeArbitrators.length; i++) {
            if (activeArbitrators[i] == arbitrator) {
                activeArbitrators[i] = activeArbitrators[activeArbitrators.length - 1];
                activeArbitrators.pop();
                break;
            }
        }
    }
}