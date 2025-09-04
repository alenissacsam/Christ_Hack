// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title AuditLogger
/// @notice On-chain audit log for all actions across the identity and certification system.
/// Provides append-only logs, indexed by actor/target and action type for easy querying.
contract AuditLogger is AccessControl {
    bytes32 public constant LOGGER_ROLE = keccak256("LOGGER_ROLE");

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

    struct AuditLog {
        address actor; // Who performed the action
        address target; // Who was affected (user/org)
        ActionType actionType;
        bytes32 dataHash; // Hash of relevant data
        uint256 timestamp;
        bool success;
        string additionalInfo; // Optional context
    }

    AuditLog[] private _auditTrail; // Append-only

    // Fast lookup indexes
    mapping(address => uint256[]) private _addressHistory; // indexes for an address (actor or target)
    mapping(ActionType => uint256[]) private _actionTypeHistory; // indexes for an action type

    event ActionLogged(
        address indexed actor,
        address indexed target,
        ActionType actionType,
        bool success,
        uint256 indexed index,
        uint256 timestamp
    );

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(LOGGER_ROLE, admin);
    }

    /// @notice Append a new log entry
    function logAction(
        address _actor,
        address _target,
        ActionType _actionType,
        bytes32 _dataHash,
        bool _success,
        string memory _additionalInfo
    ) external onlyRole(LOGGER_ROLE) {
        uint256 idx = _auditTrail.length;
        _auditTrail.push(
            AuditLog({
                actor: _actor,
                target: _target,
                actionType: _actionType,
                dataHash: _dataHash,
                timestamp: block.timestamp,
                success: _success,
                additionalInfo: _additionalInfo
            })
        );

        // Index by both actor and target; avoid duplicate if same address
        _addressHistory[_actor].push(idx);
        if (_target != _actor) {
            _addressHistory[_target].push(idx);
        }
        _actionTypeHistory[_actionType].push(idx);

        emit ActionLogged(_actor, _target, _actionType, _success, idx, block.timestamp);
    }

    // Views

    function getTotalAuditCount() external view returns (uint256) {
        return _auditTrail.length;
    }

    function getAuditLog(uint256 index) external view returns (AuditLog memory) {
        require(index < _auditTrail.length, "index OOB");
        return _auditTrail[index];
    }

    function getUserAuditHistory(address who) external view returns (uint256[] memory) {
        return _addressHistory[who];
    }

    function getActionHistory(ActionType _actionType) external view returns (uint256[] memory) {
        return _actionTypeHistory[_actionType];
    }

    /// @notice Fetch a slice of logs for pagination UIs
    function logsInRange(uint256 start, uint256 count) external view returns (AuditLog[] memory out) {
        uint256 total = _auditTrail.length;
        if (start >= total) return new AuditLog[](0);
        uint256 end = start + count;
        if (end > total) end = total;
        uint256 n = end - start;
        out = new AuditLog[](n);
        for (uint256 i = 0; i < n; i++) {
            out[i] = _auditTrail[start + i];
        }
    }
}
