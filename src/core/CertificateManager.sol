// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface IVerificationLogger {
    function logEvent(
        string memory eventType,
        address user,
        bytes32 dataHash
    ) external;
}

interface IUserIdentityRegistry {
    function registerIdentity(
        address user,
        bytes32 identityCommitment
    ) external;

    function isRegistered(address user) external view returns (bool);
}

interface ITrustScore {
    function getTrustScore(address user) external view returns (uint256);

    function updateScore(
        address user,
        int256 delta,
        string memory reason
    ) external;
}

contract CertificateManager is ERC721, AccessControl, ReentrancyGuard {
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

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

    IVerificationLogger public verificationLogger;
    IUserIdentityRegistry public userRegistry;
    ITrustScore public trustScore;

    uint256 public constant MIN_TRUST_SCORE_FOR_CERTIFICATE = 75; // Requires face + aadhaar verification

    event CertificateIssued(
        uint256 indexed certificateId,
        address indexed holder,
        address indexed issuer,
        string certificateType
    );

    event CertificateRevoked(
        uint256 indexed certificateId,
        address indexed revoker,
        string reason
    );

    constructor(
        address _verificationLogger,
        address _userRegistry,
        address _trustScore
    ) ERC721("Educational Certificates", "EDUCERT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        verificationLogger = IVerificationLogger(_verificationLogger);
        userRegistry = IUserIdentityRegistry(_userRegistry);
        trustScore = ITrustScore(_trustScore);
    }

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

        uint256 holderTrustScore = trustScore.getTrustScore(holder);
        require(
            holderTrustScore >= MIN_TRUST_SCORE_FOR_CERTIFICATE,
            "Insufficient trust score for certificate"
        );
        require(
            holderTrustScore >= requiredTrustScore,
            "Insufficient trust score for this certificate type"
        );

        // Verify ZK proof
        require(
            _verifyZKProof(zkProofHash, holder, certificateType),
            "Invalid ZK proof"
        );

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

        // Update trust score for earning certificate
        trustScore.updateScore(holder, 15, "Educational certificate issued");

        // Log event
        verificationLogger.logEvent(
            "CERTIFICATE_ISSUED",
            holder,
            keccak256(abi.encodePacked(certificateId, certificateType))
        );

        emit CertificateIssued(
            certificateId,
            holder,
            msg.sender,
            certificateType
        );

        return certificateId;
    }

    function revokeCertificate(
        uint256 certificateId,
        string memory reason
    ) external onlyRole(ISSUER_ROLE) {
        ownerOf(certificateId);
        require(
            !certificates[certificateId].isRevoked,
            "Certificate already revoked"
        );
        require(
            certificates[certificateId].issuer == msg.sender ||
                hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized to revoke"
        );

        certificates[certificateId].isRevoked = true;

        // Update trust score negatively
        trustScore.updateScore(
            certificates[certificateId].holder,
            -10,
            "Certificate revoked"
        );

        // Log event
        verificationLogger.logEvent(
            "CERTIFICATE_REVOKED",
            certificates[certificateId].holder,
            keccak256(abi.encodePacked(certificateId, reason))
        );

        emit CertificateRevoked(certificateId, msg.sender, reason);
    }

    function verifyCertificate(
        uint256 certificateId
    ) external view returns (bool) {
        try this.ownerOf(certificateId) {
            // Token exists, proceed with other checks.
        } catch {
            // ownerOf reverts with ERC721NonexistentToken if the token does not exist.
            // We catch this and return false as intended.
            return false;
        }
        Certificate memory cert = certificates[certificateId];
        return !cert.isRevoked && block.timestamp <= cert.expiresAt;
    }

    function getCertificatesByHolder(
        address holder
    ) external view returns (uint256[] memory) {
        return holderCertificates[holder];
    }

    function _verifyZKProof(
        bytes32 proofHash,
        address holder,
        string memory certType
    ) private pure returns (bool) {
        // Simplified ZK proof verification - in production use actual ZK verifier
        return keccak256(abi.encodePacked(holder, certType)) != bytes32(0);
    }

    /**
     * @dev See {ERC721-_update}.
     *
     * We override this function to prevent transfers of certificates. We only
     * allow minting (when `from` is the zero address). This is the correct
     * way to make tokens non-transferable in OpenZeppelin v5+.
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);
        require(from == address(0), "Certificates are non-transferable");
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
