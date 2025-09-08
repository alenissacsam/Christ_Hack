// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITrustScore {
    function getTrustScore(address user) external view returns (uint256);

    function updateScore(
        address user,
        int256 delta,
        string memory reason
    ) external;
}

interface IVerificationLogger {
    function logEvent(
        string memory eventType,
        address user,
        bytes32 dataHash
    ) external;
}

contract EconomicIncentives is AccessControl, ReentrancyGuard {
    bytes32 public constant REWARD_ADMIN_ROLE = keccak256("REWARD_ADMIN_ROLE");
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");

    struct Stake {
        uint256 amount;
        uint256 stakedAt;
        bool isActive;
    }

    struct RewardPool {
        uint256 totalRewards;
        uint256 distributedRewards;
        uint256 lastUpdateTime;
        bool isActive;
    }

    mapping(address => Stake) public stakes;
    mapping(address => uint256) public pendingRewards;
    mapping(address => uint256) public totalEarnedRewards;
    mapping(string => RewardPool) public rewardPools;

    IERC20 public stakingToken;
    ITrustScore public trustScore;
    IVerificationLogger public verificationLogger;

    uint256 public minimumStake = 100 * 10 ** 18; // 100 tokens
    uint256 public slashingPercentage = 20; // 20% slash on misbehavior
    uint256 public rewardRate = 10; // Base reward rate
    uint256 public totalStaked;

    address[] public stakers;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event Slashed(address indexed user, uint256 amount, string reason);
    event RewardDistributed(
        address indexed user,
        uint256 amount,
        string reason
    );

    constructor(
        address _stakingToken,
        address _trustScore,
        address _verificationLogger
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REWARD_ADMIN_ROLE, msg.sender);
        _grantRole(SLASHER_ROLE, msg.sender);

        stakingToken = IERC20(_stakingToken);
        trustScore = ITrustScore(_trustScore);
        verificationLogger = IVerificationLogger(_verificationLogger);

        _initializeRewardPools();
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount >= minimumStake, "Amount below minimum stake");
        require(
            stakingToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        if (!stakes[msg.sender].isActive) {
            stakers.push(msg.sender);
        }

        stakes[msg.sender].amount += amount;
        stakes[msg.sender].stakedAt = block.timestamp;
        stakes[msg.sender].isActive = true;

        totalStaked += amount;

        // Update trust score for staking
        trustScore.updateScore(msg.sender, 5, "Staked tokens");

        verificationLogger.logEvent(
            "TOKENS_STAKED",
            msg.sender,
            keccak256(abi.encodePacked(amount))
        );

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        require(stakes[msg.sender].isActive, "No active stake");
        require(
            stakes[msg.sender].amount >= amount,
            "Insufficient staked amount"
        );

        stakes[msg.sender].amount -= amount;
        totalStaked -= amount;

        if (stakes[msg.sender].amount == 0) {
            stakes[msg.sender].isActive = false;
            _removeStaker(msg.sender);
        }

        require(stakingToken.transfer(msg.sender, amount), "Transfer failed");

        verificationLogger.logEvent(
            "TOKENS_UNSTAKED",
            msg.sender,
            keccak256(abi.encodePacked(amount))
        );

        emit Unstaked(msg.sender, amount);
    }

    function distributeReward(
        address recipient,
        uint256 amount,
        string memory reason
    ) external onlyRole(REWARD_ADMIN_ROLE) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");

        pendingRewards[recipient] += amount;
        totalEarnedRewards[recipient] += amount;

        // Update trust score for earning rewards
        trustScore.updateScore(recipient, 1, "Reward earned");

        verificationLogger.logEvent(
            "REWARD_DISTRIBUTED",
            recipient,
            keccak256(abi.encodePacked(amount, reason))
        );

        emit RewardDistributed(recipient, amount, reason);
    }

    function claimRewards() external nonReentrant {
        uint256 reward = pendingRewards[msg.sender];
        require(reward > 0, "No pending rewards");

        pendingRewards[msg.sender] = 0;

        // Mint or transfer rewards
        require(
            stakingToken.transfer(msg.sender, reward),
            "Reward transfer failed"
        );

        verificationLogger.logEvent(
            "REWARDS_CLAIMED",
            msg.sender,
            keccak256(abi.encodePacked(reward))
        );

        emit RewardClaimed(msg.sender, reward);
    }

    function slash(
        address user,
        string memory reason
    ) external onlyRole(SLASHER_ROLE) {
        require(stakes[user].isActive, "User not staked");

        uint256 slashAmount = (stakes[user].amount * slashingPercentage) / 100;
        stakes[user].amount -= slashAmount;
        totalStaked -= slashAmount;

        if (stakes[user].amount == 0) {
            stakes[user].isActive = false;
            _removeStaker(user);
        }

        // Update trust score negatively for being slashed
        trustScore.updateScore(user, -20, "Slashed for misbehavior");

        verificationLogger.logEvent(
            "USER_SLASHED",
            user,
            keccak256(abi.encodePacked(slashAmount, reason))
        );

        emit Slashed(user, slashAmount, reason);
    }

    function calculateReward(
        address user,
        string memory poolType
    ) external view returns (uint256) {
        if (!stakes[user].isActive) return 0;

        uint256 userTrustScore = trustScore.getTrustScore(user);
        uint256 baseReward = rewardRate;

        // Multiply reward by trust score (higher trust = higher rewards)
        uint256 trustMultiplier = userTrustScore / 10; // Every 10 trust points = 1x multiplier
        if (trustMultiplier == 0) trustMultiplier = 1;

        return baseReward * trustMultiplier;
    }

    function getStakeInfo(
        address user
    ) external view returns (uint256 amount, uint256 stakedAt, bool isActive) {
        Stake memory userStake = stakes[user];
        return (userStake.amount, userStake.stakedAt, userStake.isActive);
    }

    function getPendingRewards(address user) external view returns (uint256) {
        return pendingRewards[user];
    }

    function getTotalStaked() external view returns (uint256) {
        return totalStaked;
    }

    function getActiveStakers() external view returns (address[] memory) {
        return stakers;
    }

    function _initializeRewardPools() private {
        rewardPools["CERTIFICATE_REWARD"] = RewardPool({
            totalRewards: 1000000 * 10 ** 18,
            distributedRewards: 0,
            lastUpdateTime: block.timestamp,
            isActive: true
        });

        rewardPools["GOVERNANCE_REWARD"] = RewardPool({
            totalRewards: 500000 * 10 ** 18,
            distributedRewards: 0,
            lastUpdateTime: block.timestamp,
            isActive: true
        });
    }

    function _removeStaker(address staker) private {
        for (uint256 i = 0; i < stakers.length; i++) {
            if (stakers[i] == staker) {
                stakers[i] = stakers[stakers.length - 1];
                stakers.pop();
                break;
            }
        }
    }
}
