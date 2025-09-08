// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ICertificateManager {
    function issueCertificate(
        address holder,
        string memory certificateType,
        string memory metadataURI,
        uint256 validityPeriod,
        bytes32 zkProofHash,
        bytes32 identityCommitment
    ) external returns (uint256);

    function revokeCertificate(
        uint256 certificateId,
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

contract CrossChainManager is AccessControl, ReentrancyGuard {
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant CROSS_CHAIN_ADMIN_ROLE =
        keccak256("CROSS_CHAIN_ADMIN_ROLE");

    struct CrossChainMessage {
        uint256 sourceChainId;
        uint256 targetChainId;
        bytes32 messageHash;
        address sender;
        bytes payload;
        uint256 timestamp;
        bool processed;
    }

    struct ChainConfig {
        bool isSupported;
        address certificateManager;
        string chainName;
        uint256 confirmationBlocks;
    }

    mapping(uint256 => ChainConfig) public supportedChains;
    mapping(bytes32 => CrossChainMessage) public messages;
    mapping(bytes32 => bool) public processedMessages;
    mapping(uint256 => uint256) public nonces;

    IVerificationLogger public verificationLogger;
    uint256 public currentChainId;

    event CrossChainMessageSent(
        bytes32 indexed messageHash,
        uint256 indexed targetChainId,
        address indexed sender
    );

    event CrossChainMessageReceived(
        bytes32 indexed messageHash,
        uint256 indexed sourceChainId,
        bool success
    );

    constructor(address _verificationLogger, uint256 _currentChainId) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RELAYER_ROLE, msg.sender);
        _grantRole(CROSS_CHAIN_ADMIN_ROLE, msg.sender);

        verificationLogger = IVerificationLogger(_verificationLogger);
        currentChainId = _currentChainId;
    }

    function addSupportedChain(
        uint256 chainId,
        address certificateManager,
        string memory chainName,
        uint256 confirmationBlocks
    ) external onlyRole(CROSS_CHAIN_ADMIN_ROLE) {
        supportedChains[chainId] = ChainConfig({
            isSupported: true,
            certificateManager: certificateManager,
            chainName: chainName,
            confirmationBlocks: confirmationBlocks
        });
    }

    function sendCrossChainMessage(
        uint256 targetChainId,
        bytes memory payload
    ) external nonReentrant returns (bytes32) {
        require(
            supportedChains[targetChainId].isSupported,
            "Target chain not supported"
        );

        nonces[targetChainId]++;
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                currentChainId,
                targetChainId,
                msg.sender,
                payload,
                nonces[targetChainId],
                block.timestamp
            )
        );

        messages[messageHash] = CrossChainMessage({
            sourceChainId: currentChainId,
            targetChainId: targetChainId,
            messageHash: messageHash,
            sender: msg.sender,
            payload: payload,
            timestamp: block.timestamp,
            processed: false
        });

        verificationLogger.logEvent(
            "CROSS_CHAIN_MESSAGE_SENT",
            msg.sender,
            messageHash
        );

        emit CrossChainMessageSent(messageHash, targetChainId, msg.sender);

        return messageHash;
    }

    function receiveCrossChainMessage(
        bytes32 messageHash,
        uint256 sourceChainId,
        address originalSender,
        bytes memory payload,
        bytes memory proof
    ) external onlyRole(RELAYER_ROLE) nonReentrant {
        require(
            supportedChains[sourceChainId].isSupported,
            "Source chain not supported"
        );
        require(!processedMessages[messageHash], "Message already processed");

        // Verify cross-chain proof (simplified)
        require(
            _verifyProof(
                messageHash,
                sourceChainId,
                originalSender,
                payload,
                proof
            ),
            "Invalid proof"
        );

        processedMessages[messageHash] = true;

        bool success = _processMessage(payload);

        verificationLogger.logEvent(
            success
                ? "CROSS_CHAIN_MESSAGE_PROCESSED"
                : "CROSS_CHAIN_MESSAGE_FAILED",
            originalSender,
            messageHash
        );

        emit CrossChainMessageReceived(messageHash, sourceChainId, success);
    }

    function _processMessage(bytes memory payload) private returns (bool) {
        try this._executeMessage(payload) {
            return true;
        } catch {
            return false;
        }
    }

    function _executeMessage(bytes memory payload) external {
        require(msg.sender == address(this), "Only self-call allowed");

        (string memory messageType, bytes memory data) = abi.decode(
            payload,
            (string, bytes)
        );

        if (keccak256(bytes(messageType)) == keccak256("CERTIFICATE_ISSUE")) {
            _handleCertificateIssue(data);
        } else if (
            keccak256(bytes(messageType)) == keccak256("CERTIFICATE_REVOKE")
        ) {
            _handleCertificateRevoke(data);
        }
    }

    function _handleCertificateIssue(bytes memory data) private {
        (
            address holder,
            string memory certificateType,
            string memory metadataURI,
            uint256 validityPeriod,
            bytes32 zkProofHash,
            bytes32 identityCommitment
        ) = abi.decode(
                data,
                (address, string, string, uint256, bytes32, bytes32)
            );

        ICertificateManager(supportedChains[currentChainId].certificateManager)
            .issueCertificate(
                holder,
                certificateType,
                metadataURI,
                validityPeriod,
                zkProofHash,
                identityCommitment
            );
    }

    function _handleCertificateRevoke(bytes memory data) private {
        (uint256 certificateId, string memory reason) = abi.decode(
            data,
            (uint256, string)
        );

        ICertificateManager(supportedChains[currentChainId].certificateManager)
            .revokeCertificate(certificateId, reason);
    }

    function _verifyProof(
        bytes32 messageHash,
        uint256 sourceChainId,
        address originalSender,
        bytes memory payload,
        bytes memory proof
    ) private pure returns (bool) {
        // Simplified proof verification
        // In production, this would verify actual cross-chain proofs
        return
            keccak256(
                abi.encodePacked(
                    messageHash,
                    sourceChainId,
                    originalSender,
                    payload
                )
            ) != bytes32(0);
    }
}
