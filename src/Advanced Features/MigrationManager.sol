// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IVerificationLogger {
    function logEvent(string memory eventType, address user, bytes32 dataHash) external;
}

interface IContractRegistry {
    function getContractAddress(string memory name) external view returns (address);
    function registerContract(string memory name, address contractAddress, string memory version) external;
}

contract MigrationManager is 
    Initializable,
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable 
{
    bytes32 public constant MIGRATION_ADMIN_ROLE = keccak256("MIGRATION_ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    enum MigrationStatus {
        Planned,        // Migration planned but not started
        InProgress,     // Migration currently running
        Paused,         // Migration paused
        Completed,      // Migration completed successfully
        Failed,         // Migration failed
        Rollback        // Migration rolled back
    }

    enum DataType {
        UserIdentities,     // User identity data
        Certificates,       // Certificate data
        TrustScores,       // Trust score data
        Organizations,     // Organization data
        Badges,            // Achievement badges
        Governance,        // Governance data
        Economics,         // Economic/token data
        CrossChain,        // Cross-chain data
        All               // All data types
    }

    struct Migration {
        uint256 id;
        string name;
        string description;
        string fromVersion;
        string toVersion;
        DataType[] dataTypes;
        address[] contractsToMigrate;
        address migrationExecutor;
        uint256 plannedAt;
        uint256 startedAt;
        uint256 completedAt;
        MigrationStatus status;
        uint256 totalRecords;
        uint256 migratedRecords;
        uint256 failedRecords;
        bool hasRollbackPlan;
        bytes rollbackData;
        string errorMessage;
        bytes32 migrationHash;
    }

    struct BatchMigration {
        uint256 migrationId;
        uint256 batchNumber;
        uint256 recordCount;
        bytes32 dataHash;
        uint256 processedAt;
        bool isSuccessful;
        string errorDetails;
    }

    struct DataBackup {
        string contractName;
        string dataType;
        bytes data;
        bytes32 backupHash;
        uint256 backupTime;
        string version;
        bool isRestored;
    }

    struct StateSnapshot {
        uint256 snapshotId;
        string contractName;
        bytes contractState;
        bytes32 stateHash;
        uint256 blockNumber;
        uint256 timestamp;
        bool isActive;
    }

    mapping(uint256 => Migration) public migrations;
    mapping(uint256 => BatchMigration[]) public migrationBatches;
    mapping(bytes32 => DataBackup) public dataBackups;
    mapping(uint256 => StateSnapshot) public stateSnapshots;
    mapping(address => bool) public authorizedMigrationContracts;
    mapping(string => string) public contractVersions;

    uint256 public migrationCounter;
    uint256 public snapshotCounter;
    uint256[] public activeMigrations;
    
    IVerificationLogger public verificationLogger;
    IContractRegistry public contractRegistry;

    // Migration settings
    uint256 public maxBatchSize;
    uint256 public migrationTimeout;
    bool public emergencyPauseEnabled;
    uint256 public rollbackWindow; // Time window for rollback after migration

    event MigrationPlanned(uint256 indexed migrationId, string name, address executor);
    event MigrationStarted(uint256 indexed migrationId, uint256 totalRecords);
    event MigrationCompleted(uint256 indexed migrationId, uint256 migratedRecords);
    event MigrationFailed(uint256 indexed migrationId, string errorMessage);
    event MigrationPaused(uint256 indexed migrationId, address pausedBy);
    event MigrationResumed(uint256 indexed migrationId, address resumedBy);
    event BatchMigrated(uint256 indexed migrationId, uint256 batchNumber, uint256 recordCount);
    event DataBackedUp(string indexed contractName, string dataType, bytes32 backupHash);
    event DataRestored(string indexed contractName, bytes32 backupHash);
    event StateSnapshot(uint256 indexed snapshotId, string contractName, bytes32 stateHash);
    event RollbackExecuted(uint256 indexed migrationId, string reason);
    event EmergencyPause(address indexed admin, string reason);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _verificationLogger,
        address _contractRegistry
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MIGRATION_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        verificationLogger = IVerificationLogger(_verificationLogger);
        contractRegistry = IContractRegistry(_contractRegistry);

        maxBatchSize = 1000;
        migrationTimeout = 24 hours;
        emergencyPauseEnabled = false;
        rollbackWindow = 7 days;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function planMigration(
        string memory name,
        string memory description,
        string memory fromVersion,
        string memory toVersion,
        DataType[] memory dataTypes,
        address[] memory contractsToMigrate,
        uint256 estimatedRecords,
        bytes memory rollbackData
    ) external onlyRole(MIGRATION_ADMIN_ROLE) returns (uint256) {
        require(bytes(name).length > 0, "Migration name required");
        require(contractsToMigrate.length > 0, "Contracts to migrate required");

        migrationCounter++;
        uint256 migrationId = migrationCounter;

        migrations[migrationId] = Migration({
            id: migrationId,
            name: name,
            description: description,
            fromVersion: fromVersion,
            toVersion: toVersion,
            dataTypes: dataTypes,
            contractsToMigrate: contractsToMigrate,
            migrationExecutor: msg.sender,
            plannedAt: block.timestamp,
            startedAt: 0,
            completedAt: 0,
            status: MigrationStatus.Planned,
            totalRecords: estimatedRecords,
            migratedRecords: 0,
            failedRecords: 0,
            hasRollbackPlan: rollbackData.length > 0,
            rollbackData: rollbackData,
            errorMessage: "",
            migrationHash: keccak256(abi.encodePacked(name, contractsToMigrate, block.timestamp))
        });

        verificationLogger.logEvent(
            "MIGRATION_PLANNED",
            msg.sender,
            keccak256(abi.encodePacked(migrationId, name))
        );

        emit MigrationPlanned(migrationId, name, msg.sender);
        return migrationId;
    }

    function startMigration(uint256 migrationId) external onlyRole(MIGRATION_ADMIN_ROLE) nonReentrant {
        require(!emergencyPauseEnabled, "Emergency pause enabled");
        
        Migration storage migration = migrations[migrationId];
        require(migration.status == MigrationStatus.Planned || migration.status == MigrationStatus.Paused, "Invalid migration status");
        require(migration.migrationExecutor == msg.sender, "Not authorized executor");

        // Create state snapshots before migration
        for (uint256 i = 0; i < migration.contractsToMigrate.length; i++) {
            _createStateSnapshot(migration.contractsToMigrate[i]);
        }

        migration.status = MigrationStatus.InProgress;
        migration.startedAt = block.timestamp;

        activeMigrations.push(migrationId);

        verificationLogger.logEvent(
            "MIGRATION_STARTED",
            msg.sender,
            keccak256(abi.encodePacked(migrationId, migration.totalRecords))
        );

        emit MigrationStarted(migrationId, migration.totalRecords);
    }

    function executeBatchMigration(
        uint256 migrationId,
        uint256 batchNumber,
        bytes memory batchData,
        uint256 recordCount
    ) external onlyRole(MIGRATION_ADMIN_ROLE) {
        Migration storage migration = migrations[migrationId];
        require(migration.status == MigrationStatus.InProgress, "Migration not in progress");
        require(recordCount <= maxBatchSize, "Batch size too large");

        bytes32 dataHash = keccak256(batchData);
        bool isSuccessful = true;
        string memory errorDetails = "";

        try this._processBatchData(batchData, migration.dataTypes) {
            migration.migratedRecords += recordCount;
        } catch Error(string memory error) {
            migration.failedRecords += recordCount;
            isSuccessful = false;
            errorDetails = error;
        } catch {
            migration.failedRecords += recordCount;
            isSuccessful = false;
            errorDetails = "Unknown error during batch processing";
        }

        migrationBatches[migrationId].push(BatchMigration({
            migrationId: migrationId,
            batchNumber: batchNumber,
            recordCount: recordCount,
            dataHash: dataHash,
            processedAt: block.timestamp,
            isSuccessful: isSuccessful,
            errorDetails: errorDetails
        }));

        verificationLogger.logEvent(
            isSuccessful ? "BATCH_MIGRATION_SUCCESS" : "BATCH_MIGRATION_FAILED",
            msg.sender,
            keccak256(abi.encodePacked(migrationId, batchNumber, recordCount))
        );

        emit BatchMigrated(migrationId, batchNumber, recordCount);
    }

    function completeMigration(uint256 migrationId) external onlyRole(MIGRATION_ADMIN_ROLE) {
        Migration storage migration = migrations[migrationId];
        require(migration.status == MigrationStatus.InProgress, "Migration not in progress");
        require(migration.migrationExecutor == msg.sender, "Not authorized executor");

        migration.status = MigrationStatus.Completed;
        migration.completedAt = block.timestamp;

        // Remove from active migrations
        _removeFromActiveMigrations(migrationId);

        // Update contract versions
        for (uint256 i = 0; i < migration.contractsToMigrate.length; i++) {
            address contractAddr = migration.contractsToMigrate[i];
            string memory contractName = _getContractName(contractAddr);
            contractVersions[contractName] = migration.toVersion;
        }

        verificationLogger.logEvent(
            "MIGRATION_COMPLETED",
            msg.sender,
            keccak256(abi.encodePacked(migrationId, migration.migratedRecords))
        );

        emit MigrationCompleted(migrationId, migration.migratedRecords);
    }

    function pauseMigration(uint256 migrationId, string memory reason) external onlyRole(MIGRATION_ADMIN_ROLE) {
        Migration storage migration = migrations[migrationId];
        require(migration.status == MigrationStatus.InProgress, "Migration not in progress");

        migration.status = MigrationStatus.Paused;

        verificationLogger.logEvent(
            "MIGRATION_PAUSED",
            msg.sender,
            keccak256(abi.encodePacked(migrationId, reason))
        );

        emit MigrationPaused(migrationId, msg.sender);
    }

    function resumeMigration(uint256 migrationId) external onlyRole(MIGRATION_ADMIN_ROLE) {
        Migration storage migration = migrations[migrationId];
        require(migration.status == MigrationStatus.Paused, "Migration not paused");

        migration.status = MigrationStatus.InProgress;

        verificationLogger.logEvent(
            "MIGRATION_RESUMED",
            msg.sender,
            keccak256(abi.encodePacked(migrationId))
        );

        emit MigrationResumed(migrationId, msg.sender);
    }

    function rollbackMigration(uint256 migrationId, string memory reason) external onlyRole(MIGRATION_ADMIN_ROLE) nonReentrant {
        Migration storage migration = migrations[migrationId];
        require(
            migration.status == MigrationStatus.Completed || migration.status == MigrationStatus.Failed,
            "Migration not in rollback-eligible state"
        );
        require(migration.hasRollbackPlan, "No rollback plan available");
        require(
            block.timestamp <= migration.completedAt + rollbackWindow,
            "Rollback window expired"
        );

        migration.status = MigrationStatus.Rollback;

        // Execute rollback plan
        _executeRollbackPlan(migrationId, migration.rollbackData);

        // Restore state snapshots
        for (uint256 i = 0; i < migration.contractsToMigrate.length; i++) {
            _restoreStateSnapshot(migration.contractsToMigrate[i]);
        }

        verificationLogger.logEvent(
            "MIGRATION_ROLLBACK",
            msg.sender,
            keccak256(abi.encodePacked(migrationId, reason))
        );

        emit RollbackExecuted(migrationId, reason);
    }

    function backupData(
        string memory contractName,
        string memory dataType,
        bytes memory data
    ) external onlyRole(MIGRATION_ADMIN_ROLE) returns (bytes32) {
        bytes32 backupHash = keccak256(abi.encodePacked(contractName, dataType, data, block.timestamp));
        
        dataBackups[backupHash] = DataBackup({
            contractName: contractName,
            dataType: dataType,
            data: data,
            backupHash: backupHash,
            backupTime: block.timestamp,
            version: contractVersions[contractName],
            isRestored: false
        });

        verificationLogger.logEvent(
            "DATA_BACKED_UP",
            msg.sender,
            backupHash
        );

        emit DataBackedUp(contractName, dataType, backupHash);
        return backupHash;
    }

    function restoreData(bytes32 backupHash) external onlyRole(MIGRATION_ADMIN_ROLE) {
        DataBackup storage backup = dataBackups[backupHash];
        require(backup.backupHash == backupHash, "Backup not found");
        require(!backup.isRestored, "Backup already restored");

        backup.isRestored = true;

        // In production, this would restore the actual data
        // For now, we just mark it as restored

        verificationLogger.logEvent(
            "DATA_RESTORED",
            msg.sender,
            backupHash
        );

        emit DataRestored(backup.contractName, backupHash);
    }

    function createStateSnapshot(address contractAddress) external onlyRole(MIGRATION_ADMIN_ROLE) returns (uint256) {
        return _createStateSnapshot(contractAddress);
    }

    function emergencyPause(string memory reason) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emergencyPauseEnabled = true;

        // Pause all active migrations
        for (uint256 i = 0; i < activeMigrations.length; i++) {
            Migration storage migration = migrations[activeMigrations[i]];
            if (migration.status == MigrationStatus.InProgress) {
                migration.status = MigrationStatus.Paused;
            }
        }

        verificationLogger.logEvent(
            "EMERGENCY_PAUSE",
            msg.sender,
            keccak256(bytes(reason))
        );

        emit EmergencyPause(msg.sender, reason);
    }

    function emergencyResume() external onlyRole(DEFAULT_ADMIN_ROLE) {
        emergencyPauseEnabled = false;

        verificationLogger.logEvent("EMERGENCY_RESUME", msg.sender, bytes32(0));
    }

    function getMigration(uint256 migrationId) external view returns (
        string memory name,
        MigrationStatus status,
        uint256 totalRecords,
        uint256 migratedRecords,
        uint256 failedRecords,
        uint256 plannedAt,
        uint256 startedAt,
        uint256 completedAt
    ) {
        Migration memory migration = migrations[migrationId];
        return (
            migration.name,
            migration.status,
            migration.totalRecords,
            migration.migratedRecords,
            migration.failedRecords,
            migration.plannedAt,
            migration.startedAt,
            migration.completedAt
        );
    }

    function getMigrationBatches(uint256 migrationId) external view returns (uint256) {
        return migrationBatches[migrationId].length;
    }

    function getActiveMigrations() external view returns (uint256[] memory) {
        return activeMigrations;
    }

    function getMigrationStats() external view returns (
        uint256 totalMigrations,
        uint256 activeMigrationsCount,
        uint256 completedMigrations,
        uint256 failedMigrations,
        uint256 totalBackups
    ) {
        totalMigrations = migrationCounter;
        activeMigrationsCount = activeMigrations.length;
        
        uint256 completed = 0;
        uint256 failed = 0;
        for (uint256 i = 1; i <= migrationCounter; i++) {
            if (migrations[i].status == MigrationStatus.Completed) completed++;
            if (migrations[i].status == MigrationStatus.Failed) failed++;
        }
        
        completedMigrations = completed;
        failedMigrations = failed;
        
        // totalBackups would need additional tracking
        totalBackups = 0;
    }

    function canRollback(uint256 migrationId) external view returns (bool) {
        Migration memory migration = migrations[migrationId];
        return migration.hasRollbackPlan &&
               (migration.status == MigrationStatus.Completed || migration.status == MigrationStatus.Failed) &&
               block.timestamp <= migration.completedAt + rollbackWindow;
    }

    function _processBatchData(bytes memory batchData, DataType[] memory dataTypes) external {
        require(msg.sender == address(this), "Internal function only");
        
        // Simplified batch processing - in production would handle actual data migration
        require(batchData.length > 0, "Empty batch data");
        require(dataTypes.length > 0, "No data types specified");
        
        // Simulate processing delay and potential failure
        if (batchData.length > maxBatchSize * 100) {
            revert("Batch too large for processing");
        }
    }

    function _createStateSnapshot(address contractAddress) private returns (uint256) {
        snapshotCounter++;
        uint256 snapshotId = snapshotCounter;
        
        // In production, this would capture actual contract state
        bytes memory contractState = abi.encodePacked("snapshot", contractAddress, block.timestamp);
        bytes32 stateHash = keccak256(contractState);
        
        stateSnapshots[snapshotId] = StateSnapshot({
            snapshotId: snapshotId,
            contractName: _getContractName(contractAddress),
            contractState: contractState,
            stateHash: stateHash,
            blockNumber: block.number,
            timestamp: block.timestamp,
            isActive: true
        });

        emit StateSnapshot(snapshotId, _getContractName(contractAddress), stateHash);
        return snapshotId;
    }

    function _restoreStateSnapshot(address contractAddress) private {
        // Find latest snapshot for this contract
        string memory contractName = _getContractName(contractAddress);
        
        for (uint256 i = snapshotCounter; i > 0; i--) {
            if (keccak256(bytes(stateSnapshots[i].contractName)) == keccak256(bytes(contractName)) &&
                stateSnapshots[i].isActive) {
                
                // In production, this would restore actual contract state
                stateSnapshots[i].isActive = false;
                break;
            }
        }
    }

    function _executeRollbackPlan(uint256 migrationId, bytes memory rollbackData) private {
        // In production, this would execute the specific rollback plan
        // For now, we just log the rollback execution
        verificationLogger.logEvent(
            "ROLLBACK_PLAN_EXECUTED",
            msg.sender,
            keccak256(abi.encodePacked(migrationId, rollbackData))
        );
    }

    function _removeFromActiveMigrations(uint256 migrationId) private {
        for (uint256 i = 0; i < activeMigrations.length; i++) {
            if (activeMigrations[i] == migrationId) {
                activeMigrations[i] = activeMigrations[activeMigrations.length - 1];
                activeMigrations.pop();
                break;
            }
        }
    }

    function _getContractName(address contractAddress) private view returns (string memory) {
        // In production, this would query the contract registry
        // For now, return a simplified name
        return string(abi.encodePacked("Contract_", contractAddress));
    }

    function setMaxBatchSize(uint256 newBatchSize) external onlyRole(MIGRATION_ADMIN_ROLE) {
        require(newBatchSize > 0 && newBatchSize <= 10000, "Invalid batch size");
        maxBatchSize = newBatchSize;
    }

    function setMigrationTimeout(uint256 newTimeout) external onlyRole(MIGRATION_ADMIN_ROLE) {
        require(newTimeout >= 1 hours && newTimeout <= 168 hours, "Invalid timeout"); // 1 hour to 7 days
        migrationTimeout = newTimeout;
    }

    function setRollbackWindow(uint256 newWindow) external onlyRole(MIGRATION_ADMIN_ROLE) {
        require(newWindow >= 1 days && newWindow <= 30 days, "Invalid rollback window");
        rollbackWindow = newWindow;
    }

    function authorizeContract(address contractAddress, bool authorized) external onlyRole(DEFAULT_ADMIN_ROLE) {
        authorizedMigrationContracts[contractAddress] = authorized;
    }
}