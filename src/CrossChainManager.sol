// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IGlobalCredentialAnchor {
    function getCredential(uint256 _credentialId)
        external
        view
        returns (
            uint256,
            bytes32,
            address,
            address,
            string memory,
            string memory,
            uint8,
            uint8,
            uint256,
            uint256,
            string memory,
            bytes32
        );
}

interface IVerificationLogger {
    function logVerification(address user, string memory vType, bool success, string memory details) external;
}

contract CrossChainManager is AccessControl, ReentrancyGuard {
    bytes32 public constant CROSS_CHAIN_ROLE = keccak256("CROSS_CHAIN_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct CrossChainAnchor {
        string targetChain;
        string targetContract;
        bytes32 anchorHash;
        uint256 anchorTimestamp;
        bool isActive;
    }

    mapping(uint256 => CrossChainAnchor[]) public credentialAnchors;
    mapping(string => bool) public supportedChains;

    IGlobalCredentialAnchor public globalCredentialAnchor;
    IVerificationLogger public verificationLogger;

    event CrossChainAnchorEvent(
        uint256 indexed credentialId, string targetChain, bytes32 anchorHash, uint256 timestamp
    );

    constructor(address _globalCredentialAnchor, address _verificationLogger) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(CROSS_CHAIN_ROLE, msg.sender);

        globalCredentialAnchor = IGlobalCredentialAnchor(_globalCredentialAnchor);
        verificationLogger = IVerificationLogger(_verificationLogger);

        supportedChains["ethereum"] = true;
        supportedChains["polygon"] = true;
        supportedChains["bsc"] = true;
    }

    function anchorCrossChain(
        uint256 _credentialId,
        string memory _targetChain,
        string memory _targetContract,
        bytes32 _anchorHash
    ) external nonReentrant {
        require(supportedChains[_targetChain], "Target chain not supported");

        (,, address holder,,,,,,,,,) = globalCredentialAnchor.getCredential(_credentialId);
        require(holder == msg.sender || hasRole(CROSS_CHAIN_ROLE, msg.sender), "Not authorized");

        CrossChainAnchor memory newAnchor = CrossChainAnchor({
            targetChain: _targetChain,
            targetContract: _targetContract,
            anchorHash: _anchorHash,
            anchorTimestamp: block.timestamp,
            isActive: true
        });

        credentialAnchors[_credentialId].push(newAnchor);

        verificationLogger.logVerification(holder, "CROSS_CHAIN_ANCHOR", true, _targetChain);
        emit CrossChainAnchorEvent(_credentialId, _targetChain, _anchorHash, block.timestamp);
    }

    function getCrossChainAnchors(uint256 _credentialId) external view returns (CrossChainAnchor[] memory) {
        return credentialAnchors[_credentialId];
    }

    function addSupportedChain(string memory _chainName) external onlyRole(ADMIN_ROLE) {
        supportedChains[_chainName] = true;
    }

    function addCrossChainRole(address _account) external onlyRole(ADMIN_ROLE) {
        _grantRole(CROSS_CHAIN_ROLE, _account);
    }
}
