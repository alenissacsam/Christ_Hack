// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IVerificationLogger {
    function logVerification(address user, string memory vType, bool success, string memory details) external;
}

contract OrganizationRegistry is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    enum OrgStatus { PENDING, VERIFIED, SUSPENDED, REJECTED }
    enum OrgType { GOVERNMENT, EDUCATIONAL, CORPORATE, NGO, HEALTHCARE, FINANCIAL }
    
    struct Organization {
        string name;
        OrgType orgType;
        address admin;
        OrgStatus status;
        string ipfsProfileUri;
        string[] allowedCertTypes;
        uint256 registrationTime;
        uint256 approvalTime;
        string country;
        string registrationNumber;
        bool canIssueGlobalCerts;
    }
    
    uint256 private _organizationIdCounter;
    mapping(uint256 => Organization) public organizations;
    mapping(address => uint256) public addressToOrgId;
    mapping(string => bool) public validCertificateTypes;
    
    IVerificationLogger public verificationLogger;
    
    event OrganizationRegistered(uint256 indexed orgId, address indexed admin, string name, uint256 timestamp);
    event OrganizationApproved(uint256 indexed orgId, address indexed approver, uint256 timestamp);
    
    constructor(address _verificationLogger) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        verificationLogger = IVerificationLogger(_verificationLogger);
        
        // Initialize valid certificate types
        validCertificateTypes["DEGREE"] = true;
        validCertificateTypes["EMPLOYMENT"] = true;
        validCertificateTypes["INCOME"] = true;
        validCertificateTypes["IDENTITY"] = true;
        validCertificateTypes["SUBSIDY_ELIGIBILITY"] = true;
    }
    
    function registerOrganization(
        string memory _name,
        OrgType _orgType,
        string memory _ipfsProfileUri,
        string[] memory _allowedCertTypes,
        string memory _country,
        string memory _registrationNumber
    ) external nonReentrant returns (uint256) {
        require(addressToOrgId[msg.sender] == 0, "Organization already registered");
        require(bytes(_name).length > 0, "Organization name required");
        
        for (uint i = 0; i < _allowedCertTypes.length; i++) {
            require(validCertificateTypes[_allowedCertTypes[i]], "Invalid certificate type");
        }
        
        _organizationIdCounter += 1;
        uint256 orgId = _organizationIdCounter;
        
        organizations[orgId] = Organization({
            name: _name,
            orgType: _orgType,
            admin: msg.sender,
            status: OrgStatus.PENDING,
            ipfsProfileUri: _ipfsProfileUri,
            allowedCertTypes: _allowedCertTypes,
            registrationTime: block.timestamp,
            approvalTime: 0,
            country: _country,
            registrationNumber: _registrationNumber,
            canIssueGlobalCerts: false
        });
        
        addressToOrgId[msg.sender] = orgId;
        
        verificationLogger.logVerification(msg.sender, "ORG_REGISTRATION", true, _name);
        emit OrganizationRegistered(orgId, msg.sender, _name, block.timestamp);
        
        return orgId;
    }
    
    function approveOrganization(uint256 _orgId, bool _canIssueGlobal) external onlyRole(ADMIN_ROLE) {
        require(_orgId <= _organizationIdCounter && _orgId > 0, "Invalid organization ID");
        require(organizations[_orgId].status == OrgStatus.PENDING, "Organization not pending");
        
        organizations[_orgId].status = OrgStatus.VERIFIED;
        organizations[_orgId].approvalTime = block.timestamp;
        organizations[_orgId].canIssueGlobalCerts = _canIssueGlobal;
        
        verificationLogger.logVerification(organizations[_orgId].admin, "ORG_APPROVAL", true, "Organization approved");
        emit OrganizationApproved(_orgId, msg.sender, block.timestamp);
    }
    
    function suspendOrganization(uint256 _orgId) external onlyRole(ADMIN_ROLE) {
        require(_orgId <= _organizationIdCounter && _orgId > 0, "Invalid organization ID");
        organizations[_orgId].status = OrgStatus.SUSPENDED;
        verificationLogger.logVerification(organizations[_orgId].admin, "ORG_SUSPENDED", true, "Organization suspended");
    }
    
    function getOrganization(uint256 _orgId) external view returns (Organization memory) {
        require(_orgId <= _organizationIdCounter && _orgId > 0, "Invalid organization ID");
        return organizations[_orgId];
    }
    
    function getOrganizationByAddress(address _orgAddress) external view returns (Organization memory) {
        uint256 orgId = addressToOrgId[_orgAddress];
        require(orgId > 0, "Organization not found");
        return organizations[orgId];
    }
    
    function isOrganizationVerified(address _orgAddress) external view returns (bool) {
        uint256 orgId = addressToOrgId[_orgAddress];
        if (orgId == 0) return false;
        return organizations[orgId].status == OrgStatus.VERIFIED;
    }
    
    function canIssueType(address _orgAddress, string memory _certType) external view returns (bool) {
        uint256 orgId = addressToOrgId[_orgAddress];
        if (orgId == 0) return false;
        if (organizations[orgId].status != OrgStatus.VERIFIED) return false;
        
        string[] memory allowedTypes = organizations[orgId].allowedCertTypes;
        for (uint i = 0; i < allowedTypes.length; i++) {
            if (keccak256(bytes(allowedTypes[i])) == keccak256(bytes(_certType))) {
                return true;
            }
        }
        return false;
    }
    
    function getTotalOrganizations() external view returns (uint256) {
        return _organizationIdCounter;
    }
}
