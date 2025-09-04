// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IUserIdentityRegistry {
    function getUserProfile(address _user)
        external
        view
        returns (bytes32, bytes32, bytes32, uint8, uint8, uint8, uint256, string memory, uint256, bool, bytes32, bool);
}

interface IVerificationLogger {
    function logVerification(address user, string memory vType, bool success, string memory details) external;
}

contract GlobalCredentialAnchor is AccessControl, ReentrancyGuard {
    bytes32 public constant ANCHOR_ADMIN_ROLE = keccak256("ANCHOR_ADMIN_ROLE");

    enum CredentialStatus {
        ACTIVE,
        REVOKED,
        EXPIRED,
        SUSPENDED
    }
    enum RecognitionLevel {
        LOCAL,
        REGIONAL,
        GLOBAL
    }

    struct GlobalCredential {
        uint256 id;
        bytes32 credentialHash;
        address holder;
        address issuer;
        string credentialType;
        string originChain;
        RecognitionLevel recognitionLevel;
        CredentialStatus status;
        uint256 issueDate;
        uint256 expiryDate;
        string ipfsMetadataUri;
        bytes32 globalIdentityId;
    }

    uint256 private _credentialIdCounter;
    mapping(uint256 => GlobalCredential) public globalCredentials;
    mapping(bytes32 => uint256) public hashToCredentialId;
    mapping(address => uint256[]) public holderCredentials;

    IUserIdentityRegistry public userRegistry;
    IVerificationLogger public verificationLogger;

    event CredentialAnchored(
        uint256 indexed credentialId, bytes32 indexed credentialHash, address indexed holder, uint256 timestamp
    );
    event CredentialRevoked(uint256 indexed credentialId, address indexed revoker, uint256 timestamp);

    constructor(address _userRegistry, address _verificationLogger) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ANCHOR_ADMIN_ROLE, msg.sender);

        userRegistry = IUserIdentityRegistry(_userRegistry);
        verificationLogger = IVerificationLogger(_verificationLogger);
    }

    function anchorCredential(
        bytes32 _credentialHash,
        string memory _credentialType,
        string memory _originChain,
        RecognitionLevel _recognitionLevel,
        uint256 _expiryDate,
        string memory _ipfsMetadataUri
    ) external nonReentrant returns (uint256) {
        require(_credentialHash != bytes32(0), "Invalid credential hash");
        require(hashToCredentialId[_credentialHash] == 0, "Credential already anchored");

        _credentialIdCounter += 1;
        uint256 credentialId = _credentialIdCounter;

        (,,,,,,,,,, bytes32 globalIdentityId,) = userRegistry.getUserProfile(msg.sender);

        globalCredentials[credentialId] = GlobalCredential({
            id: credentialId,
            credentialHash: _credentialHash,
            holder: msg.sender,
            issuer: msg.sender,
            credentialType: _credentialType,
            originChain: _originChain,
            recognitionLevel: _recognitionLevel,
            status: CredentialStatus.ACTIVE,
            issueDate: block.timestamp,
            expiryDate: _expiryDate,
            ipfsMetadataUri: _ipfsMetadataUri,
            globalIdentityId: globalIdentityId
        });

        hashToCredentialId[_credentialHash] = credentialId;
        holderCredentials[msg.sender].push(credentialId);

        verificationLogger.logVerification(msg.sender, "CREDENTIAL_ANCHORED", true, _credentialType);
        emit CredentialAnchored(credentialId, _credentialHash, msg.sender, block.timestamp);

        return credentialId;
    }

    function revokeCredential(uint256 _credentialId) external nonReentrant {
        require(_credentialId <= _credentialIdCounter && _credentialId > 0, "Invalid credential ID");
        require(
            globalCredentials[_credentialId].holder == msg.sender || hasRole(ANCHOR_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );

        globalCredentials[_credentialId].status = CredentialStatus.REVOKED;

        verificationLogger.logVerification(
            globalCredentials[_credentialId].holder, "CREDENTIAL_REVOKED", true, "Global credential revoked"
        );
        emit CredentialRevoked(_credentialId, msg.sender, block.timestamp);
    }

    function getCredential(uint256 _credentialId) external view returns (GlobalCredential memory) {
        require(_credentialId <= _credentialIdCounter && _credentialId > 0, "Invalid credential ID");
        return globalCredentials[_credentialId];
    }

    function getHolderCredentials(address _holder) external view returns (uint256[] memory) {
        return holderCredentials[_holder];
    }

    function getActiveCredentials(address _holder) external view returns (GlobalCredential[] memory) {
        uint256[] memory credentialIds = holderCredentials[_holder];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < credentialIds.length; i++) {
            GlobalCredential memory cred = globalCredentials[credentialIds[i]];
            if (cred.status == CredentialStatus.ACTIVE && (cred.expiryDate == 0 || cred.expiryDate > block.timestamp)) {
                activeCount++;
            }
        }

        GlobalCredential[] memory activeCreds = new GlobalCredential[](activeCount);
        uint256 index = 0;

        for (uint256 i = 0; i < credentialIds.length; i++) {
            GlobalCredential memory cred = globalCredentials[credentialIds[i]];
            if (cred.status == CredentialStatus.ACTIVE && (cred.expiryDate == 0 || cred.expiryDate > block.timestamp)) {
                activeCreds[index] = cred;
                index++;
            }
        }

        return activeCreds;
    }

    function getTotalCredentials() external view returns (uint256) {
        return _credentialIdCounter;
    }
}
