// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IVerificationLogger {
    function logEvent(
        string memory eventType,
        address user,
        bytes32 dataHash
    ) external;
}

interface ICertificateManager {
    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;
}

contract OrganizationRegistry is AccessControl, ReentrancyGuard {
    bytes32 public constant ORG_ADMIN_ROLE = keccak256("ORG_ADMIN_ROLE");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    enum OrganizationType {
        University,
        School,
        TrainingInstitute,
        CertificationBody,
        GovernmentEntity
    }

    struct Organization {
        address orgAddress;
        string name;
        OrganizationType orgType;
        string country;
        string registrationNumber;
        string metadataURI;
        uint256 registeredAt;
        bool isActive;
        bool canIssueCertificates;
        bytes32 kycHash;
    }

    mapping(address => Organization) public organizations;
    mapping(string => address) public registrationToAddress;
    address[] public activeOrganizations;

    ICertificateManager public certificateManager;
    IVerificationLogger public verificationLogger;

    event OrganizationRegistered(
        address indexed orgAddress,
        string name,
        OrganizationType orgType
    );

    event OrganizationApproved(address indexed orgAddress);
    event OrganizationSuspended(address indexed orgAddress, string reason);
    event IssuerRoleGranted(address indexed orgAddress);
    event IssuerRoleRevoked(address indexed orgAddress);

    constructor(address _certificateManager, address _verificationLogger) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORG_ADMIN_ROLE, msg.sender);

        certificateManager = ICertificateManager(_certificateManager);
        verificationLogger = IVerificationLogger(_verificationLogger);
    }

    function registerOrganization(
        string memory name,
        OrganizationType orgType,
        string memory country,
        string memory registrationNumber,
        string memory metadataURI,
        bytes32 kycHash
    ) external nonReentrant {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(
            bytes(registrationNumber).length > 0,
            "Registration number required"
        );
        require(
            !organizations[msg.sender].isActive,
            "Organization already registered"
        );
        require(
            registrationToAddress[registrationNumber] == address(0),
            "Registration number already used"
        );

        organizations[msg.sender] = Organization({
            orgAddress: msg.sender,
            name: name,
            orgType: orgType,
            country: country,
            registrationNumber: registrationNumber,
            metadataURI: metadataURI,
            registeredAt: block.timestamp,
            isActive: false, // Requires approval
            canIssueCertificates: false,
            kycHash: kycHash
        });

        registrationToAddress[registrationNumber] = msg.sender;

        verificationLogger.logEvent(
            "ORGANIZATION_REGISTERED",
            msg.sender,
            keccak256(abi.encodePacked(name, registrationNumber))
        );

        emit OrganizationRegistered(msg.sender, name, orgType);
    }

    function approveOrganization(
        address orgAddress
    ) external onlyRole(ORG_ADMIN_ROLE) {
        require(
            organizations[orgAddress].orgAddress != address(0),
            "Organization not found"
        );
        require(
            !organizations[orgAddress].isActive,
            "Organization already active"
        );

        organizations[orgAddress].isActive = true;
        activeOrganizations.push(orgAddress);

        verificationLogger.logEvent(
            "ORGANIZATION_APPROVED",
            orgAddress,
            keccak256(abi.encodePacked(organizations[orgAddress].name))
        );

        emit OrganizationApproved(orgAddress);
    }

    function grantIssuerRole(
        address orgAddress
    ) external onlyRole(ORG_ADMIN_ROLE) {
        require(organizations[orgAddress].isActive, "Organization not active");
        require(
            !organizations[orgAddress].canIssueCertificates,
            "Already has issuer role"
        );

        organizations[orgAddress].canIssueCertificates = true;

        // Grant role in CertificateManager
        certificateManager.grantRole(ISSUER_ROLE, orgAddress);

        verificationLogger.logEvent(
            "ISSUER_ROLE_GRANTED",
            orgAddress,
            bytes32(0)
        );

        emit IssuerRoleGranted(orgAddress);
    }

    function revokeIssuerRole(
        address orgAddress,
        string memory reason
    ) external onlyRole(ORG_ADMIN_ROLE) {
        require(
            organizations[orgAddress].canIssueCertificates,
            "Organization cannot issue certificates"
        );

        organizations[orgAddress].canIssueCertificates = false;

        // Revoke role in CertificateManager
        certificateManager.revokeRole(ISSUER_ROLE, orgAddress);

        verificationLogger.logEvent(
            "ISSUER_ROLE_REVOKED",
            orgAddress,
            keccak256(bytes(reason))
        );

        emit IssuerRoleRevoked(orgAddress);
    }

    function suspendOrganization(
        address orgAddress,
        string memory reason
    ) external onlyRole(ORG_ADMIN_ROLE) {
        require(organizations[orgAddress].isActive, "Organization not active");

        organizations[orgAddress].isActive = false;
        if (organizations[orgAddress].canIssueCertificates) {
            organizations[orgAddress].canIssueCertificates = false;
            certificateManager.revokeRole(ISSUER_ROLE, orgAddress);
        }

        // Remove from active list
        _removeFromActiveList(orgAddress);

        verificationLogger.logEvent(
            "ORGANIZATION_SUSPENDED",
            orgAddress,
            keccak256(bytes(reason))
        );

        emit OrganizationSuspended(orgAddress, reason);
    }

    function updateOrganization(
        string memory metadataURI,
        bytes32 newKycHash
    ) external {
        require(
            organizations[msg.sender].orgAddress != address(0),
            "Organization not registered"
        );

        organizations[msg.sender].metadataURI = metadataURI;
        organizations[msg.sender].kycHash = newKycHash;

        verificationLogger.logEvent(
            "ORGANIZATION_UPDATED",
            msg.sender,
            newKycHash
        );
    }

    function isActiveOrganization(
        address orgAddress
    ) external view returns (bool) {
        return organizations[orgAddress].isActive;
    }

    function canIssue(address orgAddress) external view returns (bool) {
        return
            organizations[orgAddress].isActive &&
            organizations[orgAddress].canIssueCertificates;
    }

    function getActiveOrganizations() external view returns (address[] memory) {
        return activeOrganizations;
    }

    function _removeFromActiveList(address orgAddress) private {
        for (uint256 i = 0; i < activeOrganizations.length; i++) {
            if (activeOrganizations[i] == orgAddress) {
                activeOrganizations[i] = activeOrganizations[
                    activeOrganizations.length - 1
                ];
                activeOrganizations.pop();
                break;
            }
        }
    }
}
