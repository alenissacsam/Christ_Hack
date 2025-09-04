// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./UserRegistry.sol";

interface IAuditLoggerOrg {
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

contract OrganizationRegistry is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant ORG_ADMIN_ROLE = keccak256("ORG_ADMIN_ROLE"); // reserved for future use
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    UserRegistry public userRegistry;
    IAuditLoggerOrg public auditLogger;

    enum OrgStatus { PENDING, VERIFIED, SUSPENDED }

    struct Organization {
        string name;
        address admin; // owner/admin of this org
        OrgStatus status;
        string ipfsProfileUri;
        uint256 registrationTime;
        bool canIssueCertificates;
        bool exists;
    }

    struct Certificate {
        bytes32 orgId;
        address recipient;
        string certificateType; // e.g., DEGREE, EMPLOYMENT
        string ipfsDocumentUri; // IPFS document for certificate
        uint256 issueDate;
        bool isActive;
        UserRegistry.VerificationLevel minRequiredLevel; // Minimum user verification needed
    }

    mapping(bytes32 => Organization) public organizations;
    mapping(bytes32 => Certificate) public certificates; // certId -> cert
    mapping(address => bytes32[]) public userCertificates; // user -> [certIds]
    mapping(bytes32 => bytes32[]) public orgIssuedCertificates; // orgId -> [certIds]

    // simple nonce to ensure certId uniqueness
    uint256 private _certNonce;

    event OrganizationRegistered(bytes32 indexed orgId, string name, address admin);
    event OrganizationVerified(bytes32 indexed orgId, address verifier);
    event CertificateIssued(bytes32 indexed certId, bytes32 indexed orgId, address indexed recipient);
    event CertificateRevoked(bytes32 indexed certId, bytes32 indexed orgId, address indexed recipient);
    event AuditLoggerUpdated(address indexed logger);
    event UserRegistryUpdated(address indexed registry);

    constructor(address admin, address _userRegistry, address _auditLogger) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SUPER_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        userRegistry = UserRegistry(_userRegistry);
        auditLogger = IAuditLoggerOrg(_auditLogger);
        emit UserRegistryUpdated(_userRegistry);
        emit AuditLoggerUpdated(_auditLogger);
    }

    // Admin setters
    function setUserRegistry(address _userRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        userRegistry = UserRegistry(_userRegistry);
        emit UserRegistryUpdated(_userRegistry);
    }

    function setAuditLogger(address _auditLogger) external onlyRole(DEFAULT_ADMIN_ROLE) {
        auditLogger = IAuditLoggerOrg(_auditLogger);
        emit AuditLoggerUpdated(_auditLogger);
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    // Organization workflow
    function registerOrganization(string memory _name, string memory _ipfsUri)
        external
        whenNotPaused
        returns (bytes32 orgId)
    {
        require(bytes(_name).length > 0, "name required");
        // Derive orgId. Including chainid and a nonce/time makes collisions practically impossible.
        orgId = keccak256(abi.encodePacked(_name, msg.sender, block.chainid, block.timestamp, address(this)));
        require(!organizations[orgId].exists, "org exists");

        Organization storage od = organizations[orgId];
        od.name = _name;
        od.admin = msg.sender;
        od.status = OrgStatus.PENDING;
        od.ipfsProfileUri = _ipfsUri;
        od.registrationTime = block.timestamp;
        od.canIssueCertificates = false;
        od.exists = true;

        emit OrganizationRegistered(orgId, _name, msg.sender);
        _safeLog(IAuditLoggerOrg.ActionType.ORG_REGISTRATION, msg.sender, msg.sender, orgId, true, "org registered");
    }

    function verifyOrganization(bytes32 _orgId) external whenNotPaused onlyRole(SUPER_ADMIN_ROLE) {
        Organization storage od = organizations[_orgId];
        require(od.exists, "org !exists");
        require(od.status != OrgStatus.VERIFIED, "already verified");
        od.status = OrgStatus.VERIFIED;
        od.canIssueCertificates = true;
        emit OrganizationVerified(_orgId, msg.sender);
        _safeLog(IAuditLoggerOrg.ActionType.ORG_VERIFICATION, msg.sender, od.admin, _orgId, true, "org verified");
    }

    // Certificates (Option B: include orgId parameter)
    function issueCertificate(
        bytes32 _orgId,
        address _recipient,
        string memory _certType,
        string memory _ipfsUri,
        UserRegistry.VerificationLevel _minLevel
    ) external whenNotPaused nonReentrant returns (bytes32 certId) {
        Organization storage od = organizations[_orgId];
        require(od.exists, "org !exists");
        require(od.status == OrgStatus.VERIFIED && od.canIssueCertificates, "org !verified");
        require(msg.sender == od.admin, "not org admin");
        require(_recipient != address(0), "bad recipient");

        // Verify recipient meets minimum verification level
        UserRegistry.VerificationLevel userLevel = userRegistry.getUserVerificationLevel(_recipient);
        require(uint8(userLevel) >= uint8(_minLevel), "user level too low");

        // Create unique certId
        certId = keccak256(
            abi.encodePacked(_orgId, _recipient, _certType, _ipfsUri, block.timestamp, _certNonce++)
        );
        require(certificates[certId].issueDate == 0, "cert exists");

        Certificate storage c = certificates[certId];
        c.orgId = _orgId;
        c.recipient = _recipient;
        c.certificateType = _certType;
        c.ipfsDocumentUri = _ipfsUri;
        c.issueDate = block.timestamp;
        c.isActive = true;
        c.minRequiredLevel = _minLevel;

        userCertificates[_recipient].push(certId);
        orgIssuedCertificates[_orgId].push(certId);

        emit CertificateIssued(certId, _orgId, _recipient);
        _safeLog(
            IAuditLoggerOrg.ActionType.CERTIFICATE_ISSUED,
            msg.sender,
            _recipient,
            certId,
            true,
            "cert issued"
        );
    }

    function revokeCertificate(bytes32 _certId) external whenNotPaused nonReentrant {
        Certificate storage c = certificates[_certId];
        require(c.issueDate != 0, "cert !exists");
        Organization storage od = organizations[c.orgId];
        require(od.exists, "org !exists");
        require(msg.sender == od.admin, "not org admin");
        require(c.isActive, "already revoked");

        c.isActive = false;

        emit CertificateRevoked(_certId, c.orgId, c.recipient);
        _safeLog(IAuditLoggerOrg.ActionType.CERTIFICATE_REVOKED, msg.sender, c.recipient, _certId, true, "cert revoked");
    }

    // Views
    function getUserCertificates(address _user) external view returns (bytes32[] memory) {
        return userCertificates[_user];
    }

    function getOrganization(bytes32 _orgId) external view returns (Organization memory) {
        return organizations[_orgId];
    }

    function getCertificate(bytes32 _certId) external view returns (Certificate memory) {
        return certificates[_certId];
    }

    // Internal safe-logger that never reverts the main flow
    function _safeLog(
        IAuditLoggerOrg.ActionType _action,
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
