// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IVerificationLogger {
    function logVerification(address user, string memory vType, bool success, string memory details) external;
}

contract UserIdentityRegistry is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    enum VerificationStatus {
        NONE,
        PENDING,
        VERIFIED,
        REJECTED
    }

    struct UserProfile {
        bytes32 faceHash;
        bytes32 aadhaarHash;
        bytes32 incomeHash;
        VerificationStatus faceStatus;
        VerificationStatus aadhaarStatus;
        VerificationStatus incomeStatus;
        uint256 annualIncome;
        string ipfsProfileUri;
        uint256 creationTime;
        bool isActive;
        bytes32 globalId;
        bool hasGlobalAnchor;
    }

    mapping(address => UserProfile) public userProfiles;
    mapping(bytes32 => address) public faceHashToUser;
    mapping(bytes32 => address) public aadhaarHashToUser;
    mapping(bytes32 => address) public globalIdToUser;

    uint256 public totalUsers;
    IVerificationLogger public verificationLogger;

    event UserRegistered(address indexed user, uint256 timestamp);
    event FaceVerified(address indexed user, bytes32 faceHash, uint256 timestamp);
    event AadhaarVerified(address indexed user, bytes32 aadhaarHash, uint256 timestamp);
    event IncomeVerified(address indexed user, uint256 income, uint256 timestamp);

    constructor(address _verificationLogger) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        verificationLogger = IVerificationLogger(_verificationLogger);
    }

    function registerUser(string memory _ipfsProfileUri) external nonReentrant {
        require(!userProfiles[msg.sender].isActive, "User already registered");

        userProfiles[msg.sender] = UserProfile({
            faceHash: bytes32(0),
            aadhaarHash: bytes32(0),
            incomeHash: bytes32(0),
            faceStatus: VerificationStatus.NONE,
            aadhaarStatus: VerificationStatus.NONE,
            incomeStatus: VerificationStatus.NONE,
            annualIncome: 0,
            ipfsProfileUri: _ipfsProfileUri,
            creationTime: block.timestamp,
            isActive: true,
            globalId: bytes32(0),
            hasGlobalAnchor: false
        });

        totalUsers++;
        verificationLogger.logVerification(msg.sender, "USER_REGISTRATION", true, "User registered");
        emit UserRegistered(msg.sender, block.timestamp);
    }

    function verifyFace(bytes32 _faceHash, bytes memory _proof) external nonReentrant {
        require(userProfiles[msg.sender].isActive, "User not registered");
        require(faceHashToUser[_faceHash] == address(0), "Face hash already registered");
        require(_verifyFaceProof(_faceHash, _proof), "Invalid face proof");

        userProfiles[msg.sender].faceHash = _faceHash;
        userProfiles[msg.sender].faceStatus = VerificationStatus.VERIFIED;
        faceHashToUser[_faceHash] = msg.sender;

        verificationLogger.logVerification(msg.sender, "FACE_VERIFICATION", true, "Face verified");
        emit FaceVerified(msg.sender, _faceHash, block.timestamp);
    }

    function verifyAadhaar(bytes32 _aadhaarHash, bytes memory _proof) external nonReentrant {
        require(userProfiles[msg.sender].isActive, "User not registered");
        require(aadhaarHashToUser[_aadhaarHash] == address(0), "Aadhaar already registered");
        require(_verifyAadhaarProof(_aadhaarHash, _proof), "Invalid Aadhaar proof");

        userProfiles[msg.sender].aadhaarHash = _aadhaarHash;
        userProfiles[msg.sender].aadhaarStatus = VerificationStatus.VERIFIED;
        aadhaarHashToUser[_aadhaarHash] = msg.sender;

        verificationLogger.logVerification(msg.sender, "AADHAAR_VERIFICATION", true, "Aadhaar verified");
        emit AadhaarVerified(msg.sender, _aadhaarHash, block.timestamp);
    }

    function verifyIncome(bytes32 _incomeHash, bytes memory _proof, uint256 _annualIncome) external nonReentrant {
        require(userProfiles[msg.sender].isActive, "User not registered");
        require(userProfiles[msg.sender].aadhaarStatus == VerificationStatus.VERIFIED, "Aadhaar required first");
        require(_verifyIncomeProof(_incomeHash, _proof, _annualIncome), "Invalid income proof");

        userProfiles[msg.sender].incomeHash = _incomeHash;
        userProfiles[msg.sender].incomeStatus = VerificationStatus.VERIFIED;
        userProfiles[msg.sender].annualIncome = _annualIncome;

        verificationLogger.logVerification(msg.sender, "INCOME_VERIFICATION", true, "Income verified");
        emit IncomeVerified(msg.sender, _annualIncome, block.timestamp);
    }

    function createGlobalIdentity() external nonReentrant {
        require(userProfiles[msg.sender].faceStatus == VerificationStatus.VERIFIED, "Face verification required");
        require(userProfiles[msg.sender].aadhaarStatus == VerificationStatus.VERIFIED, "Aadhaar verification required");
        require(!userProfiles[msg.sender].hasGlobalAnchor, "Global ID already created");

        bytes32 globalId = keccak256(abi.encodePacked(msg.sender, block.timestamp));
        userProfiles[msg.sender].globalId = globalId;
        userProfiles[msg.sender].hasGlobalAnchor = true;
        globalIdToUser[globalId] = msg.sender;

        verificationLogger.logVerification(msg.sender, "GLOBAL_ID_CREATION", true, "Global identity created");
    }

    function getUserProfile(address _user) external view returns (UserProfile memory) {
        return userProfiles[_user];
    }

    function getVerificationLevels(address _user) external view returns (bool, bool, bool, uint256, bool) {
        UserProfile memory profile = userProfiles[_user];
        return (
            profile.faceStatus == VerificationStatus.VERIFIED,
            profile.aadhaarStatus == VerificationStatus.VERIFIED,
            profile.incomeStatus == VerificationStatus.VERIFIED,
            profile.annualIncome,
            profile.hasGlobalAnchor
        );
    }

    function isEligibleForSubsidy(address _user, string memory _subsidyType) external view returns (bool) {
        UserProfile memory profile = userProfiles[_user];
        if (
            profile.faceStatus != VerificationStatus.VERIFIED || profile.aadhaarStatus != VerificationStatus.VERIFIED
                || profile.incomeStatus != VerificationStatus.VERIFIED
        ) return false;

        if (keccak256(bytes(_subsidyType)) == keccak256(bytes("BPL_RATION"))) {
            return profile.annualIncome <= 200000;
        } else if (keccak256(bytes(_subsidyType)) == keccak256(bytes("LPG_SUBSIDY"))) {
            return profile.annualIncome <= 500000;
        }
        return false;
    }

    function _verifyFaceProof(bytes32 _faceHash, bytes memory _proof) internal pure returns (bool) {
        return keccak256(_proof) == _faceHash;
    }

    function _verifyAadhaarProof(bytes32 _aadhaarHash, bytes memory _proof) internal pure returns (bool) {
        return keccak256(_proof) == _aadhaarHash;
    }

    function _verifyIncomeProof(bytes32 _incomeHash, bytes memory _proof, uint256 _income)
        internal
        pure
        returns (bool)
    {
        return keccak256(abi.encodePacked(_proof, _income)) == _incomeHash;
    }
}
