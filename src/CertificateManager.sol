// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IOrganizationRegistry {
    function isOrganizationVerified(address _orgAddress) external view returns (bool);
    function canIssueType(address _orgAddress, string memory _certType) external view returns (bool);
}

interface IUserIdentityRegistry {
    function getVerificationLevels(address _user) external view returns (bool, bool, bool, uint256, bool);
}

interface IVerificationLogger {
    function logVerification(address user, string memory vType, bool success, string memory details) external;
}

contract CertificateManager is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct Certificate {
        uint256 id;
        address issuer;
        address recipient;
        string certificateType;
        string ipfsDocumentUri;
        uint256 issueDate;
        uint256 expiryDate;
        bool isActive;
        bool isGlobal;
        bytes32 certificateHash;
    }

    uint256 private _certificateIdCounter;
    mapping(uint256 => Certificate) public certificates;
    mapping(address => uint256[]) public userCertificates;

    IOrganizationRegistry public organizationRegistry;
    IUserIdentityRegistry public userRegistry;
    IVerificationLogger public verificationLogger;

    event CertificateIssued(
        uint256 indexed certId, address indexed issuer, address indexed recipient, string certType, uint256 timestamp
    );
    event CertificateRevoked(uint256 indexed certId, address indexed revoker, uint256 timestamp);

    constructor(address _organizationRegistry, address _userRegistry, address _verificationLogger) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        organizationRegistry = IOrganizationRegistry(_organizationRegistry);
        userRegistry = IUserIdentityRegistry(_userRegistry);
        verificationLogger = IVerificationLogger(_verificationLogger);
    }

    function issueCertificate(
        address _recipient,
        string memory _certificateType,
        string memory _ipfsDocumentUri,
        uint256 _expiryDate,
        bool _isGlobal
    ) external nonReentrant returns (uint256) {
        require(organizationRegistry.isOrganizationVerified(msg.sender), "Organization not verified");
        require(organizationRegistry.canIssueType(msg.sender, _certificateType), "Cannot issue this certificate type");
        require(_checkRecipientEligibility(_recipient, _certificateType), "Recipient not eligible");

        _certificateIdCounter += 1;
        uint256 certId = _certificateIdCounter;

        bytes32 certHash =
            keccak256(abi.encodePacked(certId, msg.sender, _recipient, _certificateType, block.timestamp));

        certificates[certId] = Certificate({
            id: certId,
            issuer: msg.sender,
            recipient: _recipient,
            certificateType: _certificateType,
            ipfsDocumentUri: _ipfsDocumentUri,
            issueDate: block.timestamp,
            expiryDate: _expiryDate,
            isActive: true,
            isGlobal: _isGlobal,
            certificateHash: certHash
        });

        userCertificates[_recipient].push(certId);

        verificationLogger.logVerification(_recipient, "CERTIFICATE_ISSUED", true, _certificateType);
        emit CertificateIssued(certId, msg.sender, _recipient, _certificateType, block.timestamp);

        return certId;
    }

    function revokeCertificate(uint256 _certId) external nonReentrant {
        require(_certId <= _certificateIdCounter && _certId > 0, "Invalid certificate ID");
        require(certificates[_certId].isActive, "Certificate already revoked");
        require(
            certificates[_certId].issuer == msg.sender || hasRole(ADMIN_ROLE, msg.sender), "Not authorized to revoke"
        );

        certificates[_certId].isActive = false;

        verificationLogger.logVerification(
            certificates[_certId].recipient, "CERTIFICATE_REVOKED", true, "Certificate revoked"
        );
        emit CertificateRevoked(_certId, msg.sender, block.timestamp);
    }

    function getCertificate(uint256 _certId) external view returns (Certificate memory) {
        require(_certId <= _certificateIdCounter && _certId > 0, "Invalid certificate ID");
        return certificates[_certId];
    }

    function getUserCertificates(address _user) external view returns (uint256[] memory) {
        return userCertificates[_user];
    }

    function getActiveCertificates(address _user) external view returns (Certificate[] memory) {
        uint256[] memory certIds = userCertificates[_user];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < certIds.length; i++) {
            if (
                certificates[certIds[i]].isActive
                    && (certificates[certIds[i]].expiryDate == 0 || certificates[certIds[i]].expiryDate > block.timestamp)
            ) {
                activeCount++;
            }
        }

        Certificate[] memory activeCerts = new Certificate[](activeCount);
        uint256 index = 0;

        for (uint256 i = 0; i < certIds.length; i++) {
            if (
                certificates[certIds[i]].isActive
                    && (certificates[certIds[i]].expiryDate == 0 || certificates[certIds[i]].expiryDate > block.timestamp)
            ) {
                activeCerts[index] = certificates[certIds[i]];
                index++;
            }
        }

        return activeCerts;
    }

    function verifyCertificate(uint256 _certId) external view returns (bool isValid, Certificate memory cert) {
        if (_certId > _certificateIdCounter || _certId == 0) {
            return (false, Certificate(0, address(0), address(0), "", "", 0, 0, false, false, bytes32(0)));
        }

        Certificate memory certificate = certificates[_certId];
        bool valid = certificate.isActive && (certificate.expiryDate == 0 || certificate.expiryDate > block.timestamp);

        return (valid, certificate);
    }

    function getTotalCertificates() external view returns (uint256) {
        return _certificateIdCounter;
    }

    function _checkRecipientEligibility(address _recipient, string memory _certificateType)
        internal
        view
        returns (bool)
    {
        (bool faceVerified, bool aadhaarVerified, bool incomeVerified,, bool hasGlobalId) =
            userRegistry.getVerificationLevels(_recipient);

        if (keccak256(bytes(_certificateType)) == keccak256(bytes("IDENTITY"))) {
            return faceVerified;
        }

        if (
            keccak256(bytes(_certificateType)) == keccak256(bytes("EMPLOYMENT"))
                || keccak256(bytes(_certificateType)) == keccak256(bytes("DEGREE"))
        ) {
            return faceVerified && aadhaarVerified;
        }

        if (keccak256(bytes(_certificateType)) == keccak256(bytes("SUBSIDY_ELIGIBILITY"))) {
            return faceVerified && aadhaarVerified && incomeVerified;
        }

        return faceVerified;
    }
}
