// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Shared Interfaces for EduCert System
 * @notice Common interfaces used across multiple contracts
 */

interface IVerificationLogger {
    function logEvent(
        string memory eventType,
        address user,
        bytes32 dataHash
    ) external;
}

interface ITrustScore {
    function getTrustScore(address user) external view returns (uint256);

    function updateScoreForGaslessTransaction(address user) external;

    function initializeUserScore(address user, uint256 initialScore) external;
}

interface IUserIdentityRegistry {
    function isVerified(address user) external view returns (bool);

    function getUserCommitment(address user) external view returns (bytes32);
}

interface IGuardianManager {
    function isGuardian(
        address user,
        address guardian
    ) external view returns (bool);

    function getGuardianSet(
        address user
    )
        external
        view
        returns (address[] memory guardians, uint256 threshold, bool isSetup);
}

interface ISystemToken {
    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}
