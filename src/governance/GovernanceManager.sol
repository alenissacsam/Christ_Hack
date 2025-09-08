// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ITrustScore {
    function getTrustScore(address user) external view returns (uint256);
}

interface IVerificationLogger {
    function logEvent(
        string memory eventType,
        address user,
        bytes32 dataHash
    ) external;
}

contract GovernanceManager is AccessControl, ReentrancyGuard {
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    enum ProposalState {
        Pending,
        Active,
        Succeeded,
        Defeated,
        Executed,
        Cancelled
    }

    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        string metadataURI;
        bytes callData;
        address target;
        uint256 value;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        ProposalState state;
        bool executed;
    }

    struct Vote {
        bool hasVoted;
        uint8 support; // 0=against, 1=for, 2=abstain
        uint256 weight;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Vote)) public votes;
    mapping(address => uint256[]) public userProposals;

    uint256 public proposalCounter;
    uint256 public votingDelay = 1 days;
    uint256 public votingPeriod = 7 days;
    uint256 public proposalThreshold = 10; // Minimum trust score to propose
    uint256 public quorum = 100; // Minimum total votes needed
    uint256 public timelockDelay = 2 days;

    ITrustScore public trustScore;
    IVerificationLogger public verificationLogger;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 support,
        uint256 weight
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    constructor(address _trustScore, address _verificationLogger) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNOR_ROLE, msg.sender);

        trustScore = ITrustScore(_trustScore);
        verificationLogger = IVerificationLogger(_verificationLogger);
    }

    function createProposal(
        string memory title,
        string memory description,
        string memory metadataURI,
        address target,
        uint256 value,
        bytes memory callData
    ) external nonReentrant returns (uint256) {
        require(
            trustScore.getTrustScore(msg.sender) >= proposalThreshold,
            "Insufficient trust score"
        );
        require(bytes(title).length > 0, "Title required");
        require(
            target != address(0) || callData.length == 0,
            "Invalid call data"
        );

        proposalCounter++;
        uint256 proposalId = proposalCounter;

        uint256 startTime = block.timestamp + votingDelay;
        uint256 endTime = startTime + votingPeriod;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            title: title,
            description: description,
            metadataURI: metadataURI,
            callData: callData,
            target: target,
            value: value,
            startTime: startTime,
            endTime: endTime,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            state: ProposalState.Pending,
            executed: false
        });

        userProposals[msg.sender].push(proposalId);

        verificationLogger.logEvent(
            "PROPOSAL_CREATED",
            msg.sender,
            keccak256(abi.encodePacked(proposalId, title))
        );

        emit ProposalCreated(proposalId, msg.sender, title);

        return proposalId;
    }

    function castVote(uint256 proposalId, uint8 support) external nonReentrant {
        require(support <= 2, "Invalid support value");
        require(!votes[proposalId][msg.sender].hasVoted, "Already voted");

        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");

        uint256 weight = trustScore.getTrustScore(msg.sender);
        require(weight > 0, "No voting power");

        votes[proposalId][msg.sender] = Vote({
            hasVoted: true,
            support: support,
            weight: weight
        });

        if (support == 0) {
            proposal.againstVotes += weight;
        } else if (support == 1) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }

        verificationLogger.logEvent(
            "VOTE_CAST",
            msg.sender,
            keccak256(abi.encodePacked(proposalId, support, weight))
        );

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function updateProposalState(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");

        if (
            proposal.state == ProposalState.Pending &&
            block.timestamp >= proposal.startTime
        ) {
            proposal.state = ProposalState.Active;
        } else if (
            proposal.state == ProposalState.Active &&
            block.timestamp > proposal.endTime
        ) {
            uint256 totalVotes = proposal.forVotes +
                proposal.againstVotes +
                proposal.abstainVotes;
            if (
                totalVotes >= quorum &&
                proposal.forVotes > proposal.againstVotes
            ) {
                proposal.state = ProposalState.Succeeded;
            } else {
                proposal.state = ProposalState.Defeated;
            }
        }
    }

    function executeProposal(
        uint256 proposalId
    ) external onlyRole(GOVERNOR_ROLE) nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(
            proposal.state == ProposalState.Succeeded,
            "Proposal not succeeded"
        );
        require(!proposal.executed, "Already executed");
        require(
            block.timestamp >= proposal.endTime + timelockDelay,
            "Timelock not expired"
        );

        proposal.executed = true;
        proposal.state = ProposalState.Executed;

        if (proposal.callData.length > 0) {
            (bool success, ) = proposal.target.call{value: proposal.value}(
                proposal.callData
            );
            require(success, "Execution failed");
        }

        verificationLogger.logEvent(
            "PROPOSAL_EXECUTED",
            proposal.proposer,
            keccak256(abi.encodePacked(proposalId))
        );

        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(
        uint256 proposalId
    ) external onlyRole(GOVERNOR_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(
            proposal.state != ProposalState.Executed,
            "Cannot cancel executed proposal"
        );

        proposal.state = ProposalState.Cancelled;

        emit ProposalCancelled(proposalId);
    }

    function getProposal(
        uint256 proposalId
    ) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getUserProposals(
        address user
    ) external view returns (uint256[] memory) {
        return userProposals[user];
    }

    function hasVoted(
        uint256 proposalId,
        address voter
    ) external view returns (bool) {
        return votes[proposalId][voter].hasVoted;
    }

    function getVote(
        uint256 proposalId,
        address voter
    ) external view returns (bool hasvoted, uint8 support, uint256 weight) {
        Vote memory vote = votes[proposalId][voter];
        return (vote.hasVoted, vote.support, vote.weight);
    }
}
