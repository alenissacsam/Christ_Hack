// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IVerificationLogger {
    function logEvent(string memory eventType, address user, bytes32 dataHash) external;
}

interface ICertificateManager {
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
}

interface ITrustScore {
    function getTrustScore(address user) external view returns (uint256);
    function updateScore(address user, int256 delta, string memory reason) external;
}

contract OrganizationRegistry is 
    Initializable,
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable 
{
    bytes32 public constant ORG_ADMIN_ROLE = keccak256("ORG_ADMIN_ROLE");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    enum OrganizationType {
        University,
        College,
        School,
        TrainingInstitute,
        CertificationBody,
        GovernmentEntity,
        CorporateTraining,
        OnlinePlatform
    }

    enum OrganizationStatus {
        Pending,        // Awaiting verification
        Active,         // Verified and active
        Suspended,      // Temporarily suspended
        Deactivated,    // Permanently deactivated
        UnderReview     // Being reviewed for issues
    }

    enum AccreditationType {
        National,       // Nationally accredited
        Regional,       // Regionally accredited  
        International,  // Internationally recognized
        Professional,   // Professional body accredited
        Government,     // Government approved
        Internal        // Internal certification
    }

    struct Organization {
        address orgAddress;
        string name;
        OrganizationType orgType;
        OrganizationStatus status;
        string country;
        string state;
        string city;
        string registrationNumber;
        string website;
        string email;
        string metadataURI;
        uint256 registeredAt;
        uint256 lastUpdated;
        bool canIssueCertificates;
        bytes32 kycHash;
        uint256 trustScore;
        uint256 certificatesIssued;
        uint256 certificatesRevoked;
        AccreditationType[] accreditations;
    }

    struct OrganizationStats {
        uint256 totalOrganizations;
        uint256 activeOrganizations;
        uint256 pendingOrganizations;
        uint256 suspendedOrganizations;
        mapping(OrganizationType => uint256) typeCount;
        mapping(string => uint256) countryCount;
    }

    mapping(address => Organization) public organizations;
    mapping(string => address) public registrationToAddress;
    mapping(string => address) public nameToAddress;
    mapping(bytes32 => bool) public usedKycHashes;
    
    address[] public allOrganizations;
    address[] public activeOrganizations;
    address[] public pendingOrganizations;
    
    OrganizationStats public stats;
    
    ICertificateManager public certificateManager;
    IVerificationLogger public verificationLogger;
    ITrustScore public trustScore;

    uint256 public constant MIN_ORG_TRUST_SCORE = 25;
    uint256 public constant REVIEW_PERIOD = 30 days;

    event OrganizationRegistered(address indexed orgAddress, string name, OrganizationType orgType);
    event OrganizationApproved(address indexed orgAddress, string name);
    event OrganizationSuspended(address indexed orgAddress, string reason);
    event OrganizationReactivated(address indexed orgAddress);
    event IssuerRoleGranted(address indexed orgAddress, string name);
    event IssuerRoleRevoked(address indexed orgAddress, string reason);
    event OrganizationUpdated(address indexed orgAddress, string field);
    event AccreditationAdded(address indexed orgAddress, AccreditationType accreditationType);
    event AccreditationRevoked(address indexed orgAddress, AccreditationType accreditationType);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _certificateManager, 
        address _verificationLogger,
        address _trustScore
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORG_ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        certificateManager = ICertificateManager(_certificateManager);
        verificationLogger = IVerificationLogger(_verificationLogger);
        trustScore = ITrustScore(_trustScore);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function registerOrganization(
        string memory name,
        OrganizationType orgType,
        string memory country,
        string memory state,
        string memory city,
        string memory registrationNumber,
        string memory website,
        string memory email,
        string memory metadataURI,
        bytes32 kycHash
    ) external nonReentrant {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(registrationNumber).length > 0, "Registration number required");
        require(organizations[msg.sender].orgAddress == address(0), "Organization already registered");
        require(registrationToAddress[registrationNumber] == address(0), "Registration number already used");
        require(nameToAddress[name] == address(0), "Organization name already used");
        require(!usedKycHashes[kycHash], "KYC hash already used");

        organizations[msg.sender] = Organization({
            orgAddress: msg.sender,
            name: name,
            orgType: orgType,
            status: OrganizationStatus.Pending,
            country: country,
            state: state,
            city: city,
            registrationNumber: registrationNumber,
            website: website,
            email: email,
            metadataURI: metadataURI,
            registeredAt: block.timestamp,
            lastUpdated: block.timestamp,
            canIssueCertificates: false,
            kycHash: kycHash,
            trustScore: 0,
            certificatesIssued: 0,
            certificatesRevoked: 0,
            accreditations: new AccreditationType[](0)
        });

        registrationToAddress[registrationNumber] = msg.sender;
        nameToAddress[name] = msg.sender;
        usedKycHashes[kycHash] = true;
        
        allOrganizations.push(msg.sender);
        pendingOrganizations.push(msg.sender);

        // Update statistics
        stats.totalOrganizations++;
        stats.pendingOrganizations++;
        stats.typeCount[orgType]++;
        stats.countryCount[country]++;

        verificationLogger.logEvent(
            "ORGANIZATION_REGISTERED",
            msg.sender,
            keccak256(abi.encodePacked(name, registrationNumber, uint256(orgType)))
        );

        emit OrganizationRegistered(msg.sender, name, orgType);
    }

    function approveOrganization(address orgAddress) external onlyRole(VERIFIER_ROLE) {
        Organization storage org = organizations[orgAddress];
        require(org.orgAddress != address(0), "Organization not found");
        require(org.status == OrganizationStatus.Pending, "Organization not pending");

        org.status = OrganizationStatus.Active;
        org.lastUpdated = block.timestamp;
        org.trustScore = MIN_ORG_TRUST_SCORE; // Initial trust score

        // Move from pending to active lists
        _removeFromPendingList(orgAddress);
        activeOrganizations.push(orgAddress);

        // Update statistics
        stats.activeOrganizations++;
        stats.pendingOrganizations--;

        // Update trust score
        trustScore.updateScore(orgAddress, int256(MIN_ORG_TRUST_SCORE), "Organization approved");

        verificationLogger.logEvent(
            "ORGANIZATION_APPROVED",
            orgAddress,
            keccak256(abi.encodePacked(org.name))
        );

        emit OrganizationApproved(orgAddress, org.name);
    }

    function grantIssuerRole(address orgAddress) external onlyRole(ORG_ADMIN_ROLE) {
        Organization storage org = organizations[orgAddress];
        require(org.status == OrganizationStatus.Active, "Organization not active");
        require(!org.canIssueCertificates, "Already has issuer role");
        require(org.trustScore >= MIN_ORG_TRUST_SCORE, "Insufficient trust score");

        org.canIssueCertificates = true;
        org.lastUpdated = block.timestamp;

        // Grant role in CertificateManager
        certificateManager.grantRole(ISSUER_ROLE, orgAddress);

        // Increase trust score
        trustScore.updateScore(orgAddress, 25, "Granted certificate issuer role");

        verificationLogger.logEvent(
            "ISSUER_ROLE_GRANTED",
            orgAddress,
            keccak256(abi.encodePacked(org.name))
        );

        emit IssuerRoleGranted(orgAddress, org.name);
    }

    function revokeIssuerRole(address orgAddress, string memory reason) external onlyRole(ORG_ADMIN_ROLE) {
        Organization storage org = organizations[orgAddress];
        require(org.canIssueCertificates, "Organization cannot issue certificates");

        org.canIssueCertificates = false;
        org.lastUpdated = block.timestamp;

        // Revoke role in CertificateManager
        certificateManager.revokeRole(ISSUER_ROLE, orgAddress);

        // Decrease trust score
        trustScore.updateScore(orgAddress, -25, "Revoked certificate issuer role");

        verificationLogger.logEvent(
            "ISSUER_ROLE_REVOKED",
            orgAddress,
            keccak256(abi.encodePacked(org.name, reason))
        );

        emit IssuerRoleRevoked(orgAddress, reason);
    }

    function suspendOrganization(address orgAddress, string memory reason) external onlyRole(VERIFIER_ROLE) {
        Organization storage org = organizations[orgAddress];
        require(org.status == OrganizationStatus.Active, "Organization not active");

        org.status = OrganizationStatus.Suspended;
        org.lastUpdated = block.timestamp;

        // Automatically revoke issuer role if suspended
        if (org.canIssueCertificates) {
            org.canIssueCertificates = false;
            certificateManager.revokeRole(ISSUER_ROLE, orgAddress);
        }

        // Move from active list
        _removeFromActiveList(orgAddress);

        // Update statistics
        stats.activeOrganizations--;
        stats.suspendedOrganizations++;

        // Decrease trust score significantly
        trustScore.updateScore(orgAddress, -50, "Organization suspended");

        verificationLogger.logEvent(
            "ORGANIZATION_SUSPENDED",
            orgAddress,
            keccak256(abi.encodePacked(org.name, reason))
        );

        emit OrganizationSuspended(orgAddress, reason);
    }

    function reactivateOrganization(address orgAddress) external onlyRole(VERIFIER_ROLE) {
        Organization storage org = organizations[orgAddress];
        require(org.status == OrganizationStatus.Suspended, "Organization not suspended");

        org.status = OrganizationStatus.Active;
        org.lastUpdated = block.timestamp;

        // Add back to active list
        activeOrganizations.push(orgAddress);

        // Update statistics
        stats.activeOrganizations++;
        stats.suspendedOrganizations--;

        // Restore some trust score
        trustScore.updateScore(orgAddress, 25, "Organization reactivated");

        verificationLogger.logEvent(
            "ORGANIZATION_REACTIVATED",
            orgAddress,
            keccak256(abi.encodePacked(org.name))
        );

        emit OrganizationReactivated(orgAddress);
    }

    function addAccreditation(
        address orgAddress, 
        AccreditationType accreditationType
    ) external onlyRole(VERIFIER_ROLE) {
        Organization storage org = organizations[orgAddress];
        require(org.orgAddress != address(0), "Organization not found");

        // Check if accreditation already exists
        for (uint256 i = 0; i < org.accreditations.length; i++) {
            require(org.accreditations[i] != accreditationType, "Accreditation already exists");
        }

        org.accreditations.push(accreditationType);
        org.lastUpdated = block.timestamp;

        // Increase trust score based on accreditation type
        int256 scoreIncrease = _getAccreditationScore(accreditationType);
        trustScore.updateScore(orgAddress, scoreIncrease, "Accreditation added");

        verificationLogger.logEvent(
            "ACCREDITATION_ADDED",
            orgAddress,
            keccak256(abi.encodePacked(org.name, uint256(accreditationType)))
        );

        emit AccreditationAdded(orgAddress, accreditationType);
    }

    function revokeAccreditation(
        address orgAddress, 
        AccreditationType accreditationType
    ) external onlyRole(VERIFIER_ROLE) {
        Organization storage org = organizations[orgAddress];
        require(org.orgAddress != address(0), "Organization not found");

        // Find and remove accreditation
        bool found = false;
        for (uint256 i = 0; i < org.accreditations.length; i++) {
            if (org.accreditations[i] == accreditationType) {
                org.accreditations[i] = org.accreditations[org.accreditations.length - 1];
                org.accreditations.pop();
                found = true;
                break;
            }
        }
        require(found, "Accreditation not found");

        org.lastUpdated = block.timestamp;

        // Decrease trust score
        int256 scoreDecrease = -_getAccreditationScore(accreditationType);
        trustScore.updateScore(orgAddress, scoreDecrease, "Accreditation revoked");

        verificationLogger.logEvent(
            "ACCREDITATION_REVOKED",
            orgAddress,
            keccak256(abi.encodePacked(org.name, uint256(accreditationType)))
        );

        emit AccreditationRevoked(orgAddress, accreditationType);
    }

    function updateOrganizationInfo(
        string memory website,
        string memory email,
        string memory metadataURI
    ) external {
        Organization storage org = organizations[msg.sender];
        require(org.orgAddress != address(0), "Organization not registered");

        org.website = website;
        org.email = email;
        org.metadataURI = metadataURI;
        org.lastUpdated = block.timestamp;

        verificationLogger.logEvent(
            "ORGANIZATION_INFO_UPDATED",
            msg.sender,
            keccak256(abi.encodePacked(website, email))
        );

        emit OrganizationUpdated(msg.sender, "info");
    }

    function updateCertificateStats(
        address orgAddress, 
        bool isRevocation
    ) external onlyRole(ISSUER_ROLE) {
        Organization storage org = organizations[orgAddress];
        require(org.orgAddress != address(0), "Organization not found");

        if (isRevocation) {
            org.certificatesRevoked++;
            // Penalty for revocation
            trustScore.updateScore(orgAddress, -2, "Certificate revoked");
        } else {
            org.certificatesIssued++;
            // Small reward for issuing certificates
            trustScore.updateScore(orgAddress, 1, "Certificate issued");
        }

        org.lastUpdated = block.timestamp;
    }

    function isActiveOrganization(address orgAddress) external view returns (bool) {
        return organizations[orgAddress].status == OrganizationStatus.Active;
    }

    function canIssue(address orgAddress) external view returns (bool) {
        Organization memory org = organizations[orgAddress];
        return org.status == OrganizationStatus.Active && org.canIssueCertificates;
    }

    function getOrganizationInfo(address orgAddress) external view returns (
        string memory name,
        OrganizationType orgType,
        OrganizationStatus status,
        string memory country,
        string memory registrationNumber,
        uint256 trustScore,
        bool canIssueCertificates,
        AccreditationType[] memory accreditations
    ) {
        Organization memory org = organizations[orgAddress];
        return (
            org.name,
            org.orgType,
            org.status,
            org.country,
            org.registrationNumber,
            org.trustScore,
            org.canIssueCertificates,
            org.accreditations
        );
    }

    function getOrganizationStats(address orgAddress) external view returns (
        uint256 certificatesIssued,
        uint256 certificatesRevoked,
        uint256 registeredAt,
        uint256 lastUpdated
    ) {
        Organization memory org = organizations[orgAddress];
        return (
            org.certificatesIssued,
            org.certificatesRevoked,
            org.registeredAt,
            org.lastUpdated
        );
    }

    function getActiveOrganizations() external view returns (address[] memory) {
        return activeOrganizations;
    }

    function getPendingOrganizations() external view returns (address[] memory) {
        return pendingOrganizations;
    }

    function getOrganizationsByType(OrganizationType orgType) external view returns (address[] memory) {
        uint256 count = 0;
        // Count matching organizations
        for (uint256 i = 0; i < allOrganizations.length; i++) {
            if (organizations[allOrganizations[i]].orgType == orgType) {
                count++;
            }
        }

        // Collect matching organizations
        address[] memory result = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allOrganizations.length; i++) {
            if (organizations[allOrganizations[i]].orgType == orgType) {
                result[index] = allOrganizations[i];
                index++;
            }
        }

        return result;
    }

    function getOrganizationsByCountry(string memory country) external view returns (address[] memory) {
        uint256 count = 0;
        bytes32 countryHash = keccak256(bytes(country));
        
        // Count matching organizations
        for (uint256 i = 0; i < allOrganizations.length; i++) {
            if (keccak256(bytes(organizations[allOrganizations[i]].country)) == countryHash) {
                count++;
            }
        }

        // Collect matching organizations
        address[] memory result = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allOrganizations.length; i++) {
            if (keccak256(bytes(organizations[allOrganizations[i]].country)) == countryHash) {
                result[index] = allOrganizations[i];
                index++;
            }
        }

        return result;
    }

    function getGlobalStats() external view returns (
        uint256 totalOrganizations,
        uint256 activeOrganizations,
        uint256 pendingOrganizations,
        uint256 suspendedOrganizations
    ) {
        return (
            stats.totalOrganizations,
            stats.activeOrganizations,
            stats.pendingOrganizations,
            stats.suspendedOrganizations
        );
    }

    function _getAccreditationScore(AccreditationType accType) private pure returns (int256) {
        if (accType == AccreditationType.International) return 50;
        if (accType == AccreditationType.National) return 40;
        if (accType == AccreditationType.Government) return 35;
        if (accType == AccreditationType.Professional) return 30;
        if (accType == AccreditationType.Regional) return 25;
        if (accType == AccreditationType.Internal) return 15;
        return 20; // Default
    }

    function _removeFromActiveList(address orgAddress) private {
        for (uint256 i = 0; i < activeOrganizations.length; i++) {
            if (activeOrganizations[i] == orgAddress) {
                activeOrganizations[i] = activeOrganizations[activeOrganizations.length - 1];
                activeOrganizations.pop();
                break;
            }
        }
    }

    function _removeFromPendingList(address orgAddress) private {
        for (uint256 i = 0; i < pendingOrganizations.length; i++) {
            if (pendingOrganizations[i] == orgAddress) {
                pendingOrganizations[i] = pendingOrganizations[pendingOrganizations.length - 1];
                pendingOrganizations.pop();
                break;
            }
        }
    }
}