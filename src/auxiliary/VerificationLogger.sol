// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract VerificationLogger is AccessControl {
    bytes32 public constant LOGGER_ROLE = keccak256("LOGGER_ROLE");

    struct LogEntry {
        uint256 id;
        string eventType;
        address user;
        address contractAddress;
        bytes32 dataHash;
        uint256 timestamp;
        uint256 blockNumber;
    }

    mapping(uint256 => LogEntry) public logs;
    mapping(address => uint256[]) public userLogs;
    mapping(string => uint256[]) public eventTypeLogs;

    uint256 public logCounter;

    event EventLogged(
        uint256 indexed logId,
        string indexed eventType,
        address indexed user,
        address contractAddress,
        bytes32 dataHash
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LOGGER_ROLE, msg.sender);
    }

    function logEvent(
        string memory eventType,
        address user,
        bytes32 dataHash
    ) external onlyRole(LOGGER_ROLE) {
        logCounter++;

        LogEntry memory newLog = LogEntry({
            id: logCounter,
            eventType: eventType,
            user: user,
            contractAddress: msg.sender,
            dataHash: dataHash,
            timestamp: block.timestamp,
            blockNumber: block.number
        });

        logs[logCounter] = newLog;
        userLogs[user].push(logCounter);
        eventTypeLogs[eventType].push(logCounter);

        emit EventLogged(logCounter, eventType, user, msg.sender, dataHash);
    }

    function getUserLogs(
        address user
    ) external view returns (uint256[] memory) {
        return userLogs[user];
    }

    function getEventTypeLogs(
        string memory eventType
    ) external view returns (uint256[] memory) {
        return eventTypeLogs[eventType];
    }

    function getLogsInRange(
        uint256 fromId,
        uint256 toId
    ) external view returns (LogEntry[] memory) {
        require(fromId <= toId && toId <= logCounter, "Invalid range");

        uint256 length = toId - fromId + 1;
        LogEntry[] memory result = new LogEntry[](length);

        for (uint256 i = 0; i < length; i++) {
            result[i] = logs[fromId + i];
        }

        return result;
    }

    function getLogsByTimeRange(
        uint256 fromTime,
        uint256 toTime
    ) external view returns (LogEntry[] memory) {
        require(fromTime <= toTime, "Invalid time range");

        // Count logs in time range
        uint256 count = 0;
        for (uint256 i = 1; i <= logCounter; i++) {
            if (logs[i].timestamp >= fromTime && logs[i].timestamp <= toTime) {
                count++;
            }
        }

        // Populate result
        LogEntry[] memory result = new LogEntry[](count);
        uint256 index = 0;
        for (uint256 i = 1; i <= logCounter; i++) {
            if (logs[i].timestamp >= fromTime && logs[i].timestamp <= toTime) {
                result[index] = logs[i];
                index++;
            }
        }

        return result;
    }

    function getTotalLogs() external view returns (uint256) {
        return logCounter;
    }
}
