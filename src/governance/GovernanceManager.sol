// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface ITrustScore {
    function getTrustScore(address user) external view returns (uint256);
    function updateScore(address user, int256 delta, string memory reason) external;
}

interface IVerificationLogger {
    function logEvent(string memory eventType, address user, bytes32 dataHash) external;
}

interface IEconomicIncentives {
    function getStakeInfo(address user) external view returns (uint256 amount, uint256 stakedAt, bool isActive, uint256 lockExpiry, bool isSlashed, uint256 tier);
}

contract GovernanceManager is 
    Initializable,
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable 
{
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    enum ProposalState {
        Pending,
        Active,
        Succeeded,
        Defeated,
        Executed,
        Cancelled,
        Expired
    }

    enum ProposalType {
        Constitutional,    // Changes to core governance parameters
        Treasury,         // Treasury management
        Technical,        // Contract upgrades and technical changes
        Community        // Community initiatives
    }

    struct Proposal {
        uint256 id;
        address proposer;
        ProposalType proposalType;
        string title;
        string description;
        string metadataURI;
        bytes[] callDatas;
        address[] targets;
        uint256[] values;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        ProposalState state;
        bool executed;
        uint256 quorumRequired;
        uint256 approvalThreshold;
    }

    struct Vote {
        bool hasVoted;
        uint8 support; // 0=against, 1=for, 2=abstain
        uint256 weight;
        uint256 timestamp;
        string reason;
    }

    struct GovernanceConfig {
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 executionDelay;
        uint256 proposalThreshold;
        uint256 quorumNumerator;
        uint256 approvalNumerator;
        bool emergencyPauseEnabled;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Vote)) public votes;
    mapping(address => uint256[]) public userProposals;
    mapping(ProposalType => GovernanceConfig) public governanceConfigs;
    
    uint256 public proposalCounter;
    bool public systemPaused;
    
    ITrustScore public trustScore;
    IVerificationLogger public verificationLogger;
    IEconomicIncentives public economicIncentives;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, ProposalType proposalType, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 support, uint256 weight, string reason);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId, string reason);
    event ProposalStateChanged(uint256 indexed proposalId, ProposalState newState);
    event GovernanceConfigUpdated(ProposalType proposalType, string parameter, uint256 newValue);
    event SystemPaused(address indexed pauser, string reason);
    event SystemUnpaused(address indexed unpauser);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _trustScore, 
        address _verificationLogger,
        address _economicIncentives
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNOR_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        trustScore = ITrustScore(_trustScore);
        verificationLogger = IVerificationLogger(_verificationLogger);
        economicIncentives = IEconomicIncentives(_economicIncentives);

        _initializeGovernanceConfigs();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function createProposal(
        ProposalType proposalType,
        string memory title,
        string memory description,
        string memory metadataURI,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory callDatas
    ) external nonReentrant returns (uint256) {
        require(!systemPaused, "System is paused");
        require(bytes(title).length > 0, "Title required");
        require(targets.length == values.length && values.length == callDatas.length, "Arrays length mismatch");

        GovernanceConfig memory config = governanceConfigs[proposalType];
        uint256 proposerWeight = getVotingWeight(msg.sender);
        require(proposerWeight >= config.proposalThreshold, "Insufficient voting weight");

        proposalCounter++;
        uint256 proposalId = proposalCounter;
        uint256 startTime = block.timestamp + config.votingDelay;
        uint256 endTime = startTime + config.votingPeriod;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            proposalType: proposalType,
            title: title,
            description: description,
            metadataURI: metadataURI,
            callDatas: callDatas,
            targets: targets,
            values: values,
            startTime: startTime,
            endTime: endTime,
            executionTime: 0,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            state: ProposalState.Pending,
            executed: false,
            quorumRequired: config.quorumNumerator,
            approvalThreshold: config.approvalNumerator
        });

        userProposals[msg.sender].push(proposalId);

        // Update trust score for active participation
        trustScore.updateScore(msg.sender, 5, "Created governance proposal");

        verificationLogger.logEvent(
            "GOVERNANCE_PROPOSAL_CREATED",
            msg.sender,
            keccak256(abi.encodePacked(proposalId, title, uint256(proposalType)))
        );

        emit ProposalCreated(proposalId, msg.sender, proposalType, title);
        return proposalId;
    }

    function castVote(
        uint256 proposalId, 
        uint8 support, 
        string memory reason
    ) external nonReentrant {
        require(!systemPaused, "System is paused");
        require(support <= 2, "Invalid support value");
        require(!votes[proposalId][msg.sender].hasVoted, "Already voted");

        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(proposal.state == ProposalState.Active, "Proposal not active");

        uint256 weight = getVotingWeight(msg.sender);
        require(weight > 0, "No voting power");

        votes[proposalId][msg.sender] = Vote({
            hasVoted: true,
            support: support,
            weight: weight,
            timestamp: block.timestamp,
            reason: reason
        });

        if (support == 0) {
            proposal.againstVotes += weight;
        } else if (support == 1) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }

        // Update trust score for voting participation
        trustScore.updateScore(msg.sender, 1, "Participated in governance voting");

        verificationLogger.logEvent(
            "GOVERNANCE_VOTE_CAST",
            msg.sender,
            keccak256(abi.encodePacked(proposalId, support, weight))
        );

        emit VoteCast(proposalId, msg.sender, support, weight, reason);
    }

    function updateProposalState(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");

        ProposalState currentState = proposal.state;
        ProposalState newState = currentState;

        if (currentState == ProposalState.Pending && block.timestamp >= proposal.startTime) {
            newState = ProposalState.Active;
        } else if (currentState == ProposalState.Active && block.timestamp > proposal.endTime) {
            uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
            
            if (totalVotes >= proposal.quorumRequired) {
                if ((proposal.forVotes * 10000) >= (totalVotes * proposal.approvalThreshold)) {
                    newState = ProposalState.Succeeded;
                    proposal.executionTime = block.timestamp + governanceConfigs[proposal.proposalType].executionDelay;
                } else {
                    newState = ProposalState.Defeated;
                }
            } else {
                newState = ProposalState.Defeated;
            }
        } else if (currentState == ProposalState.Succeeded) {
            if (proposal.executionTime > 0 && block.timestamp > proposal.executionTime + 14 days) {
                newState = ProposalState.Expired;
            }
        }

        if (newState != currentState) {
            proposal.state = newState;
            emit ProposalStateChanged(proposalId, newState);
        }
    }

    function executeProposal(uint256 proposalId) external onlyRole(EXECUTOR_ROLE) nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Succeeded, "Proposal not succeeded");
        require(!proposal.executed, "Already executed");
        require(block.timestamp >= proposal.executionTime, "Execution delay not met");
        require(block.timestamp <= proposal.executionTime + 14 days, "Proposal expired");

        proposal.executed = true;
        proposal.state = ProposalState.Executed;

        // Execute all proposal actions
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            if (proposal.targets[i] != address(0)) {
                (bool success, bytes memory returnData) = proposal.targets[i].call{value: proposal.values[i]}(proposal.callDatas[i]);
                require(success, string(returnData));
            }
        }

        // Reward proposer for successful execution
        trustScore.updateScore(proposal.proposer, 10, "Successful proposal execution");

        verificationLogger.logEvent(
            "GOVERNANCE_PROPOSAL_EXECUTED",
            proposal.proposer,
            keccak256(abi.encodePacked(proposalId))
        );

        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId, string memory reason) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(
            msg.sender == proposal.proposer || hasRole(GOVERNOR_ROLE, msg.sender),
            "Not authorized to cancel"
        );
        require(
            proposal.state == ProposalState.Pending || proposal.state == ProposalState.Active,
            "Cannot cancel proposal in current state"
        );

        proposal.state = ProposalState.Cancelled;

        verificationLogger.logEvent(
            "GOVERNANCE_PROPOSAL_CANCELLED",
            proposal.proposer,
            keccak256(abi.encodePacked(proposalId, reason))
        );

        emit ProposalCancelled(proposalId, reason);
    }

    function emergencyPause(string memory reason) external onlyRole(GOVERNOR_ROLE) {
        require(!systemPaused, "Already paused");
        systemPaused = true;

        verificationLogger.logEvent(
            "GOVERNANCE_EMERGENCY_PAUSE",
            msg.sender,
            keccak256(bytes(reason))
        );

        emit SystemPaused(msg.sender, reason);
    }

    function emergencyUnpause() external onlyRole(GOVERNOR_ROLE) {
        require(systemPaused, "Not paused");
        systemPaused = false;

        verificationLogger.logEvent(
            "GOVERNANCE_EMERGENCY_UNPAUSE",
            msg.sender,
            bytes32(0)
        );

        emit SystemUnpaused(msg.sender);
    }

    function updateGovernanceConfig(
        ProposalType proposalType,
        string memory parameter,
        uint256 newValue
    ) external onlyRole(GOVERNOR_ROLE) {
        GovernanceConfig storage config = governanceConfigs[proposalType];
        bytes32 paramHash = keccak256(bytes(parameter));

        if (paramHash == keccak256("votingDelay")) {
            require(newValue >= 1 hours && newValue <= 7 days, "Invalid voting delay");
            config.votingDelay = newValue;
        } else if (paramHash == keccak256("votingPeriod")) {
            require(newValue >= 1 days && newValue <= 30 days, "Invalid voting period");
            config.votingPeriod = newValue;
        } else if (paramHash == keccak256("executionDelay")) {
            require(newValue >= 1 hours && newValue <= 30 days, "Invalid execution delay");
            config.executionDelay = newValue;
        } else if (paramHash == keccak256("proposalThreshold")) {
            require(newValue > 0 && newValue <= 1000, "Invalid proposal threshold");
            config.proposalThreshold = newValue;
        } else if (paramHash == keccak256("quorumNumerator")) {
            require(newValue >= 500 && newValue <= 10000, "Invalid quorum"); // 5%-100%
            config.quorumNumerator = newValue;
        } else if (paramHash == keccak256("approvalNumerator")) {
            require(newValue >= 5000 && newValue <= 10000, "Invalid approval threshold"); // 50%-100%
            config.approvalNumerator = newValue;
        } else {
            revert("Invalid parameter");
        }

        emit GovernanceConfigUpdated(proposalType, parameter, newValue);
    }

    function getVotingWeight(address user) public view returns (uint256) {
        uint256 trustScoreWeight = trustScore.getTrustScore(user);
        
        // Get staking multiplier
        (uint256 stakeAmount, , bool isActive, , , uint256 tier) = economicIncentives.getStakeInfo(user);
        uint256 stakingMultiplier = isActive ? (100 + (tier * 25)) : 100; // 25% bonus per tier
        
        // Base weight from trust score with staking multiplier
        uint256 weight = (trustScoreWeight * stakingMultiplier) / 100;
        
        // Minimum weight for registered users
        return weight < 10 ? 10 : weight;
    }

    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        ProposalType proposalType,
        string memory title,
        string memory description,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        ProposalState state
    ) {
        Proposal memory proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.proposalType,
            proposal.title,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.state
        );
    }

    function getUserProposals(address user) external view returns (uint256[] memory) {
        return userProposals[user];
    }

    function getVote(uint256 proposalId, address voter) external view returns (
        bool hasVoted,
        uint8 support,
        uint256 weight,
        uint256 timestamp,
        string memory reason
    ) {
        Vote memory vote = votes[proposalId][voter];
        return (vote.hasVoted, vote.support, vote.weight, vote.timestamp, vote.reason);
    }

    function canExecuteProposal(uint256 proposalId) external view returns (bool) {
        Proposal memory proposal = proposals[proposalId];
        return proposal.state == ProposalState.Succeeded &&
               !proposal.executed &&
               block.timestamp >= proposal.executionTime &&
               block.timestamp <= proposal.executionTime + 14 days;
    }

    function getGovernanceStats() external view returns (
        uint256 totalProposals,
        uint256 activeProposals,
        uint256 executedProposals,
        uint256 totalVoters
    ) {
        totalProposals = proposalCounter;
        
        uint256 active = 0;
        uint256 executed = 0;
        for (uint256 i = 1; i <= proposalCounter; i++) {
            if (proposals[i].state == ProposalState.Active) active++;
            if (proposals[i].state == ProposalState.Executed) executed++;
        }
        
        activeProposals = active;
        executedProposals = executed;
        // totalVoters would need additional tracking in production
        totalVoters = 0;
    }

    function _initializeGovernanceConfigs() private {
        // Constitutional proposals - highest requirements
        governanceConfigs[ProposalType.Constitutional] = GovernanceConfig({
            votingDelay: 3 days,
            votingPeriod: 7 days,
            executionDelay: 7 days,
            proposalThreshold: 100, // High trust score required
            quorumNumerator: 2000,  // 20% quorum
            approvalNumerator: 7500, // 75% approval
            emergencyPauseEnabled: false
        });

        // Treasury proposals - high requirements
        governanceConfigs[ProposalType.Treasury] = GovernanceConfig({
            votingDelay: 2 days,
            votingPeriod: 5 days,
            executionDelay: 3 days,
            proposalThreshold: 75,
            quorumNumerator: 1500,  // 15% quorum
            approvalNumerator: 6000, // 60% approval
            emergencyPauseEnabled: false
        });

        // Technical proposals - moderate requirements
        governanceConfigs[ProposalType.Technical] = GovernanceConfig({
            votingDelay: 1 days,
            votingPeriod: 5 days,
            executionDelay: 2 days,
            proposalThreshold: 50,
            quorumNumerator: 1000,  // 10% quorum
            approvalNumerator: 5500, // 55% approval
            emergencyPauseEnabled: true
        });

        // Community proposals - lowest requirements
        governanceConfigs[ProposalType.Community] = GovernanceConfig({
            votingDelay: 1 days,
            votingPeriod: 3 days,
            executionDelay: 1 days,
            proposalThreshold: 25,
            quorumNumerator: 500,   // 5% quorum
            approvalNumerator: 5000, // 50% approval
            emergencyPauseEnabled: false
        });
    }
}