// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IVerificationLogger {
    function logEvent(string memory eventType, address user, bytes32 dataHash) external;
}

interface IUserIdentityRegistry {
    function isRegistered(address user) external view returns (bool);
}

interface ITrustScore {
    function getTrustScore(address user) external view returns (uint256);
    function updateScore(address user, int256 delta, string memory reason) external;
}

contract CertificateManager is 
    Initializable,
    ERC721Upgradeable, 
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable 
{
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 private _certificateIdCounter;

    struct Certificate {
        uint256 id;
        address holder;
        address issuer;
        string certificateType;
        string metadataURI;
        uint256 issuedAt;
        uint256 expiresAt;
        bool isRevoked;
        bytes32 zkProofHash;
        uint256 requiredTrustScore;
    }

    mapping(uint256 => Certificate) public certificates;
    mapping(address => uint256[]) public holderCertificates;
    mapping(address => uint256[]) public issuerCertificates;
    mapping(address => bool) public lockedAccounts;
    
    IVerificationLogger public verificationLogger;
    IUserIdentityRegistry public userRegistry;
    ITrustScore public trustScore;
    
    uint256 public constant MIN_TRUST_SCORE_FOR_CERTIFICATE = 75;

    event CertificateIssued(uint256 indexed certificateId, address indexed holder, address indexed issuer, string certificateType);
    event CertificateRevoked(uint256 indexed certificateId, address indexed revoker, string reason);
    event CertificateMigrated(uint256 indexed certificateId, address indexed oldHolder, address indexed newHolder);
    event AccountLocked(address indexed account, string reason);
    event AccountUnlocked(address indexed account);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _verificationLogger,
        address _userRegistry,
        address _trustScore
    ) public initializer {
        __ERC721_init("Educational Certificates", "EDUCERT");
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        verificationLogger = IVerificationLogger(_verificationLogger);
        userRegistry = IUserIdentityRegistry(_userRegistry);
        trustScore = ITrustScore(_trustScore);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function issueCertificate(
        address holder,
        string memory certificateType,
        string memory metadataURI,
        uint256 validityPeriod,
        bytes32 zkProofHash,
        bytes32 identityCommitment,
        uint256 requiredTrustScore
    ) external onlyRole(ISSUER_ROLE) nonReentrant returns (uint256) {
        require(holder != address(0), "Invalid holder address");
        require(bytes(certificateType).length > 0, "Certificate type required");
        require(zkProofHash != bytes32(0), "ZK proof required");
        require(userRegistry.isRegistered(holder), "User not registered");
        require(!lockedAccounts[holder], "Account is locked");

        uint256 holderTrustScore = trustScore.getTrustScore(holder);
        require(holderTrustScore >= MIN_TRUST_SCORE_FOR_CERTIFICATE, "Insufficient trust score for certificate");
        require(holderTrustScore >= requiredTrustScore, "Insufficient trust score for this certificate type");

        require(_verifyZKProof(zkProofHash, holder, certificateType), "Invalid ZK proof");

        _certificateIdCounter++;
        uint256 certificateId = _certificateIdCounter;

        Certificate memory newCert = Certificate({
            id: certificateId,
            holder: holder,
            issuer: msg.sender,
            certificateType: certificateType,
            metadataURI: metadataURI,
            issuedAt: block.timestamp,
            expiresAt: block.timestamp + validityPeriod,
            isRevoked: false,
            zkProofHash: zkProofHash,
            requiredTrustScore: requiredTrustScore
        });

        certificates[certificateId] = newCert;
        holderCertificates[holder].push(certificateId);
        issuerCertificates[msg.sender].push(certificateId);

        _mint(holder, certificateId);

        trustScore.updateScore(holder, 15, "Educational certificate issued");

        verificationLogger.logEvent(
            "CERTIFICATE_ISSUED",
            holder,
            keccak256(abi.encodePacked(certificateId, certificateType))
        );

        emit CertificateIssued(certificateId, holder, msg.sender, certificateType);
        return certificateId;
    }

    function revokeCertificate(uint256 certificateId, string memory reason) external onlyRole(ISSUER_ROLE) {
        ownerOf(certificateId);
        require(!certificates[certificateId].isRevoked, "Certificate already revoked");
        require(
            certificates[certificateId].issuer == msg.sender || hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized to revoke"
        );

        certificates[certificateId].isRevoked = true;

        trustScore.updateScore(certificates[certificateId].holder, -10, "Certificate revoked");

        verificationLogger.logEvent(
            "CERTIFICATE_REVOKED",
            certificates[certificateId].holder,
            keccak256(abi.encodePacked(certificateId, reason))
        );

        emit CertificateRevoked(certificateId, msg.sender, reason);
    }

    function migrateCertificate(
        uint256 certificateId,
        address newHolder,
        bytes32 migrationProof
    ) external onlyRole(ADMIN_ROLE) nonReentrant {
        require(ownerOf(certificateId) != address(0), "Certificate does not exist");
        require(newHolder != address(0), "Invalid new holder");
        require(userRegistry.isRegistered(newHolder), "New holder not registered");
        require(_verifyMigrationProof(certificateId, newHolder, migrationProof), "Invalid migration proof");

        address oldHolder = certificates[certificateId].holder;
        certificates[certificateId].holder = newHolder;

        _removeFromHolderList(oldHolder, certificateId);
        holderCertificates[newHolder].push(certificateId);

        _transfer(oldHolder, newHolder, certificateId);

        verificationLogger.logEvent(
            "CERTIFICATE_MIGRATED",
            newHolder,
            keccak256(abi.encodePacked(certificateId, oldHolder, newHolder))
        );

        emit CertificateMigrated(certificateId, oldHolder, newHolder);
    }

    function lockAccount(address account, string memory reason) external onlyRole(ADMIN_ROLE) {
        lockedAccounts[account] = true;
        
        verificationLogger.logEvent(
            "ACCOUNT_LOCKED",
            account,
            keccak256(bytes(reason))
        );

        emit AccountLocked(account, reason);
    }

    function unlockAccount(address account) external onlyRole(ADMIN_ROLE) {
        lockedAccounts[account] = false;

        verificationLogger.logEvent("ACCOUNT_UNLOCKED", account, bytes32(0));
        emit AccountUnlocked(account);
    }

    function verifyCertificate(uint256 certificateId) external view returns (bool) {
        try this.ownerOf(certificateId) {
            // Token exists
        } catch {
            return false;
        }

        Certificate memory cert = certificates[certificateId];
        return !cert.isRevoked && block.timestamp <= cert.expiresAt;
    }

    function getCertificatesByHolder(address holder) external view returns (uint256[] memory) {
        return holderCertificates[holder];
    }

    function isAccountLocked(address account) external view returns (bool) {
        return lockedAccounts[account];
    }

    function _verifyZKProof(bytes32 proofHash, address holder, string memory certType) private pure returns (bool) {
        // Simplified ZK proof verification - in production use actual ZK verifier
        return keccak256(abi.encodePacked(holder, certType)) != bytes32(0);
    }

    function _verifyMigrationProof(uint256 certificateId, address newHolder, bytes32 migrationProof) private pure returns (bool) {
        // Simplified migration proof verification
        return keccak256(abi.encodePacked(certificateId, newHolder)) != bytes32(0);
    }

    function _removeFromHolderList(address holder, uint256 certificateId) private {
        uint256[] storage certs = holderCertificates[holder];
        for (uint256 i = 0; i < certs.length; i++) {
            if (certs[i] == certificateId) {
                certs[i] = certs[certs.length - 1];
                certs.pop();
                break;
            }
        }
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        // Allow minting and admin-controlled migration, but prevent regular transfers
        require(from == address(0) || hasRole(ADMIN_ROLE, auth), "Certificates are non-transferable");
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Upgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}