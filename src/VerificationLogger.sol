// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract VerificationLogger is AccessControl {
    bytes32 public constant LOGGER_ROLE = keccak256("LOGGER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    struct VerificationLog {
        uint256 id;
        address user;
        address actor;                  // Who performed the action (user, org, admin)
        string verificationType;        // "FACE_VERIFICATION", "CERTIFICATE_ISSUED", etc.
        bool success;
        uint256 timestamp;
        string details;                 // Additional context
        bytes32 dataHash;              // Hash of related data for integrity
    }
    
    struct SystemMetrics {
        uint256 totalVerifications;
        uint256 successfulVerifications;
        uint256 failedVerifications;
        uint256 totalUsers;
        mapping(string => uint256) verificationTypeCount;
    }
    
    // Storage
    uint256 private _logIdCounter;
    mapping(uint256 => VerificationLog) public logs;
    mapping(address => uint256[]) public userLogs;              // User address to log IDs
    mapping(string => uint256[]) public typeToLogs;             // Verification type to log IDs
    mapping(uint256 => uint256[]) public dailyLogs;             // Day timestamp to log IDs (for analytics)
    
    SystemMetrics public systemMetrics;
    
    // Events
    event LogEntry(
        uint256 indexed logId,
        address indexed user,
        address indexed actor,
        string verificationType,
        bool success,
        uint256 timestamp
    );
    
    event DailyReport(uint256 indexed dayTimestamp, uint256 totalLogs, uint256 successCount);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(LOGGER_ROLE, msg.sender);
    }
    
    // ==================== LOGGING FUNCTIONS ====================
    
    function logVerification(
        address _user,
        string memory _verificationType,
        bool _success,
        string memory _details
    ) external onlyRole(LOGGER_ROLE) {
        _logVerification(_user, msg.sender, _verificationType, _success, _details, bytes32(0));
    }
    
    function logVerificationWithData(
        address _user,
        string memory _verificationType,
        bool _success,
        string memory _details,
        bytes32 _dataHash
    ) external onlyRole(LOGGER_ROLE) {
        _logVerification(_user, msg.sender, _verificationType, _success, _details, _dataHash);
    }
    
    function logOrganizationAction(
        address _user,
        address _organization,
        string memory _actionType,
        bool _success,
        string memory _details,
        bytes32 _dataHash
    ) external onlyRole(LOGGER_ROLE) {
        _logVerification(_user, _organization, _actionType, _success, _details, _dataHash);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getLog(uint256 _logId) external view returns (VerificationLog memory) {
        require(_logId <= _logIdCounter && _logId > 0, "Invalid log ID");
        return logs[_logId];
    }
    
    function getUserLogs(address _user) external view returns (uint256[] memory) {
        return userLogs[_user];
    }
    
    function getUserLogsPaginated(address _user, uint256 _offset, uint256 _limit) 
        external view returns (VerificationLog[] memory) {
        uint256[] memory logIds = userLogs[_user];
        require(_offset < logIds.length, "Offset out of bounds");
        
        uint256 end = _offset + _limit;
        if (end > logIds.length) {
            end = logIds.length;
        }
        
        VerificationLog[] memory result = new VerificationLog[](end - _offset);
        for (uint256 i = _offset; i < end; i++) {
            result[i - _offset] = logs[logIds[i]];
        }
        
        return result;
    }
    
    function getLogsByType(string memory _verificationType) external view returns (uint256[] memory) {
        return typeToLogs[_verificationType];
    }
    
    function getLogsByTypeAndDateRange(
        string memory _verificationType,
        uint256 _startTime,
        uint256 _endTime
    ) external view returns (VerificationLog[] memory) {
        uint256[] memory typeLogIds = typeToLogs[_verificationType];
        uint256 count = 0;
        
        // Count matching logs
        for (uint256 i = 0; i < typeLogIds.length; i++) {
            VerificationLog memory log = logs[typeLogIds[i]];
            if (log.timestamp >= _startTime && log.timestamp <= _endTime) {
                count++;
            }
        }
        
        // Create result array
        VerificationLog[] memory result = new VerificationLog[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < typeLogIds.length; i++) {
            VerificationLog memory log = logs[typeLogIds[i]];
            if (log.timestamp >= _startTime && log.timestamp <= _endTime) {
                result[index] = log;
                index++;
            }
        }
        
        return result;
    }
    
    function getDailyLogs(uint256 _dayTimestamp) external view returns (uint256[] memory) {
        return dailyLogs[_dayTimestamp];
    }
    
    function getSystemMetrics() external view returns (
        uint256 totalVerifications,
        uint256 successfulVerifications,
        uint256 failedVerifications,
        uint256 totalUsers
    ) {
        return (
            systemMetrics.totalVerifications,
            systemMetrics.successfulVerifications,
            systemMetrics.failedVerifications,
            systemMetrics.totalUsers
        );
    }
    
    function getVerificationTypeCount(string memory _verificationType) external view returns (uint256) {
        return systemMetrics.verificationTypeCount[_verificationType];
    }
    
    function getTotalLogs() external view returns (uint256) {
        return _logIdCounter;
    }
    
    // Analytics functions
    function getSuccessRate() external view returns (uint256) {
        if (systemMetrics.totalVerifications == 0) return 0;
        return (systemMetrics.successfulVerifications * 100) / systemMetrics.totalVerifications;
    }
    
    function getDailyStats(uint256 _dayTimestamp) external view returns (
        uint256 totalLogs,
        uint256 successCount,
        uint256 failureCount
    ) {
        uint256[] memory dayLogIds = dailyLogs[_dayTimestamp];
        uint256 successes = 0;
        
        for (uint256 i = 0; i < dayLogIds.length; i++) {
            if (logs[dayLogIds[i]].success) {
                successes++;
            }
        }
        
        return (dayLogIds.length, successes, dayLogIds.length - successes);
    }
    
    function getUserVerificationHistory(address _user, string memory _verificationType) 
        external view returns (VerificationLog[] memory) {
        uint256[] memory userLogIds = userLogs[_user];
        uint256 count = 0;
        
        // Count matching logs
        for (uint256 i = 0; i < userLogIds.length; i++) {
            if (keccak256(bytes(logs[userLogIds[i]].verificationType)) == keccak256(bytes(_verificationType))) {
                count++;
            }
        }
        
        // Create result array
        VerificationLog[] memory result = new VerificationLog[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < userLogIds.length; i++) {
            if (keccak256(bytes(logs[userLogIds[i]].verificationType)) == keccak256(bytes(_verificationType))) {
                result[index] = logs[userLogIds[i]];
                index++;
            }
        }
        
        return result;
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function addLogger(address _logger) external onlyRole(ADMIN_ROLE) {
        _grantRole(LOGGER_ROLE, _logger);
    }
    
    function removeLogger(address _logger) external onlyRole(ADMIN_ROLE) {
        _revokeRole(LOGGER_ROLE, _logger);
    }
    
    function generateDailyReport(uint256 _dayTimestamp) external onlyRole(ADMIN_ROLE) {
        (uint256 totalLogs, uint256 successCount, ) = this.getDailyStats(_dayTimestamp);
        emit DailyReport(_dayTimestamp, totalLogs, successCount);
    }
    
    // Emergency function to clear old logs (for storage management)
    function archiveOldLogs(uint256 _beforeTimestamp) external onlyRole(ADMIN_ROLE) {
        // In production, this would move logs to IPFS or another storage solution
        // This is a placeholder for the archiving functionality
        emit LogEntry(0, address(0), msg.sender, "LOGS_ARCHIVED", true, block.timestamp);
    }
    
    // ==================== INTERNAL FUNCTIONS ====================
    
    function _logVerification(
        address _user,
        address _actor,
        string memory _verificationType,
        bool _success,
        string memory _details,
        bytes32 _dataHash
    ) internal {
        _logIdCounter += 1;
        uint256 logId = _logIdCounter;
        
        // Create log entry
        logs[logId] = VerificationLog({
            id: logId,
            user: _user,
            actor: _actor,
            verificationType: _verificationType,
            success: _success,
            timestamp: block.timestamp,
            details: _details,
            dataHash: _dataHash
        });
        
        // Update mappings
        userLogs[_user].push(logId);
        typeToLogs[_verificationType].push(logId);
        
        // Update daily logs (using day timestamp)
        uint256 dayTimestamp = (block.timestamp / 86400) * 86400; // Start of day
        dailyLogs[dayTimestamp].push(logId);
        
        // Update system metrics
        systemMetrics.totalVerifications++;
        if (_success) {
            systemMetrics.successfulVerifications++;
        } else {
            systemMetrics.failedVerifications++;
        }
        systemMetrics.verificationTypeCount[_verificationType]++;
        
        emit LogEntry(logId, _user, _actor, _verificationType, _success, block.timestamp);
    }
}
