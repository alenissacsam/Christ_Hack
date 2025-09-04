// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface IAuditLogger {
    enum ActionType {
        USER_REGISTRATION,
        FACE_VERIFICATION,
        ID_VERIFICATION,
        ORG_REGISTRATION,
        ORG_VERIFICATION,
        CERTIFICATE_ISSUED,
        CERTIFICATE_REVOKED,
        VERIFICATION_FAILED
    }

    function logAction(
        address _actor,
        address _target,
        ActionType _actionType,
        bytes32 _dataHash,
        bool _success,
        string calldata _additionalInfo
    ) external;
}

contract UserRegistry is AccessControl, Pausable {
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    enum VerificationLevel {
        NONE,
        LEVEL1_FACE,
        LEVEL2_FULL
    }

    struct UserProfile {
        bytes32 faceHash; // Level 1 verification
        bytes32 nationalIdHash; // Level 2 verification
        VerificationLevel verLevel; // Current verification status
        uint256 registrationTime;
        string ipfsProfileUri; // Additional profile data
        bool isActive;
    }

    IAuditLogger public auditLogger;

    mapping(address => UserProfile) private _users;
    mapping(bytes32 => address) public faceHashToUser; // Prevent duplicate faces
    mapping(bytes32 => address) public idHashToUser; // Prevent duplicate IDs

    event UserRegistered(address indexed user, uint256 timestamp, string ipfsUri);
    event Level1Verified(address indexed user, bytes32 faceHash);
    event Level2Requested(address indexed user, bytes32 idHash);
    event Level2Verified(address indexed user, bytes32 idHash);
    event UserDeactivated(address indexed user, uint256 timestamp);
    event ProfileUpdated(address indexed user, string newIpfsUri);
    event AuditLoggerUpdated(address indexed logger);

    constructor(address admin, address _auditLogger) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(VERIFIER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        auditLogger = IAuditLogger(_auditLogger);
        emit AuditLoggerUpdated(_auditLogger);
    }

    // Admin controls
    function setAuditLogger(address _auditLogger) external onlyRole(DEFAULT_ADMIN_ROLE) {
        auditLogger = IAuditLogger(_auditLogger);
        emit AuditLoggerUpdated(_auditLogger);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // Core functions for registration and verification status updates
    function registerUser(bytes32 _faceHash, string memory _ipfsUri) external whenNotPaused {
        require(_faceHash != bytes32(0), "faceHash required");
        UserProfile storage up = _users[msg.sender];
        require(!up.isActive, "already active");
        // prevent duplicate face across different accounts
        address existing = faceHashToUser[_faceHash];
        require(existing == address(0) || existing == msg.sender, "face already used");

        up.faceHash = _faceHash;
        up.nationalIdHash = bytes32(0);
        up.verLevel = VerificationLevel.NONE;
        if (up.registrationTime == 0) {
            up.registrationTime = block.timestamp;
        }
        up.ipfsProfileUri = _ipfsUri;
        up.isActive = true;

        faceHashToUser[_faceHash] = msg.sender;

        emit UserRegistered(msg.sender, block.timestamp, _ipfsUri);
        _safeLog(
            IAuditLogger.ActionType.USER_REGISTRATION,
            msg.sender,
            msg.sender,
            keccak256(abi.encodePacked(_faceHash, _ipfsUri)),
            true,
            "user registered"
        );
    }

    function upgradeToLevel2(bytes32 _nationalIdHash) external whenNotPaused {
        require(_nationalIdHash != bytes32(0), "idHash required");
        UserProfile storage up = _users[msg.sender];
        require(up.isActive, "not active");
        require(up.verLevel == VerificationLevel.LEVEL1_FACE || up.verLevel == VerificationLevel.LEVEL2_FULL, "need L1");
        // If already L2, allow updating pending hash only if not yet set in mapping
        if (up.verLevel == VerificationLevel.LEVEL2_FULL) {
            require(up.nationalIdHash == _nationalIdHash, "already L2");
        }
        require(idHashToUser[_nationalIdHash] == address(0) || idHashToUser[_nationalIdHash] == msg.sender, "ID already used");

        up.nationalIdHash = _nationalIdHash;

        emit Level2Requested(msg.sender, _nationalIdHash);
        _safeLog(
            IAuditLogger.ActionType.ID_VERIFICATION,
            msg.sender,
            msg.sender,
            _nationalIdHash,
            false,
            "level2 requested"
        );
    }

    function verifyLevel1(address _user, bytes32 _faceHash) external whenNotPaused onlyRole(VERIFIER_ROLE) {
        UserProfile storage up = _users[_user];
        require(up.isActive, "user inactive");
        require(up.faceHash == _faceHash && _faceHash != bytes32(0), "face mismatch");
        require(up.verLevel == VerificationLevel.NONE, "already >= L1");

        up.verLevel = VerificationLevel.LEVEL1_FACE;

        emit Level1Verified(_user, _faceHash);
        _safeLog(
            IAuditLogger.ActionType.FACE_VERIFICATION,
            msg.sender,
            _user,
            _faceHash,
            true,
            "level1 verified"
        );
    }

    function verifyLevel2(address _user, bytes32 _idHash) external whenNotPaused onlyRole(VERIFIER_ROLE) {
        UserProfile storage up = _users[_user];
        require(up.isActive, "user inactive");
        require(up.verLevel == VerificationLevel.LEVEL1_FACE, "need L1");
        require(up.nationalIdHash == _idHash && _idHash != bytes32(0), "id mismatch");
        require(idHashToUser[_idHash] == address(0) || idHashToUser[_idHash] == _user, "ID in use");

        idHashToUser[_idHash] = _user;
        up.verLevel = VerificationLevel.LEVEL2_FULL;

        emit Level2Verified(_user, _idHash);
        _safeLog(
            IAuditLogger.ActionType.ID_VERIFICATION,
            msg.sender,
            _user,
            _idHash,
            true,
            "level2 verified"
        );
    }

    // Profile management
    function updateIpfsProfileUri(string calldata _newUri) external whenNotPaused {
        UserProfile storage up = _users[msg.sender];
        require(up.isActive, "not active");
        up.ipfsProfileUri = _newUri;
        emit ProfileUpdated(msg.sender, _newUri);
    }

    function deactivateUser(address _user) external whenNotPaused {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || _user == msg.sender, "not auth");
        UserProfile storage up = _users[_user];
        require(up.isActive, "already inactive");
        up.isActive = false;
        emit UserDeactivated(_user, block.timestamp);
        _safeLog(
            IAuditLogger.ActionType.VERIFICATION_FAILED,
            msg.sender,
            _user,
            bytes32(0),
            true,
            "user deactivated"
        );
    }

    // Views
    function getUserVerificationLevel(address _user) external view returns (VerificationLevel) {
        return _users[_user].verLevel;
    }

    function getUserProfile(address _user) external view returns (UserProfile memory) {
        return _users[_user];
    }

    function isActive(address _user) external view returns (bool) {
        return _users[_user].isActive;
    }

    function getUserByFaceHash(bytes32 _faceHash) external view returns (address) {
        return faceHashToUser[_faceHash];
    }

    function getUserByIdHash(bytes32 _idHash) external view returns (address) {
        return idHashToUser[_idHash];
    }

    // Internal safe-logger that never reverts the main flow
    function _safeLog(
        IAuditLogger.ActionType _action,
        address _actor,
        address _target,
        bytes32 _dataHash,
        bool _success,
        string memory _info
    ) internal {
        if (address(auditLogger) == address(0)) return;
        try auditLogger.logAction(_actor, _target, _action, _dataHash, _success, _info) {
            // ok
        } catch {
            // ignore logging failures
        }
    }
}
