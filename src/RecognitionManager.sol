// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

interface IGlobalCredentialAnchor {
    function getCredential(uint256 _credentialId) external view returns (
        uint256, bytes32, address, address, string memory, string memory,
        uint8, uint8, uint256, uint256, string memory, bytes32
    );
}

interface IVerificationLogger {
    function logVerification(address user, string memory vType, bool success, string memory details) external;
}

contract RecognitionManager is AccessControl {
    bytes32 public constant RECOGNITION_ADMIN_ROLE = keccak256("RECOGNITION_ADMIN_ROLE");
    
    struct RecognitionRecord {
        string country;
        address recognizer;
        uint256 recognitionDate;
        bool isActive;
        string recognitionDocument;
    }
    
    mapping(uint256 => RecognitionRecord[]) public credentialRecognitions;
    mapping(string => bool) public recognizedCountries;
    
    IGlobalCredentialAnchor public globalCredentialAnchor;
    IVerificationLogger public verificationLogger;
    
    event CountryRecognition(uint256 indexed credentialId, string country, address indexed recognizer, uint256 timestamp);
    event RecognitionRevoked(uint256 indexed credentialId, string country, address indexed revoker, uint256 timestamp);
    
    constructor(address _globalCredentialAnchor, address _verificationLogger) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RECOGNITION_ADMIN_ROLE, msg.sender);
        
        globalCredentialAnchor = IGlobalCredentialAnchor(_globalCredentialAnchor);
        verificationLogger = IVerificationLogger(_verificationLogger);
        
        recognizedCountries["IN"] = true;
        recognizedCountries["US"] = true;
        recognizedCountries["GB"] = true;
        recognizedCountries["EU"] = true;
        recognizedCountries["SG"] = true;
    }
    
    function addCountryRecognition(
        uint256 _credentialId,
        string memory _country,
        string memory _recognitionDocument
    ) external onlyRole(RECOGNITION_ADMIN_ROLE) {
        require(recognizedCountries[_country], "Country not supported");
        
        (, , address holder, , , , , uint8 status, , , , ) = globalCredentialAnchor.getCredential(_credentialId);
        require(status == 0, "Credential not active"); // 0 = ACTIVE
        
        RecognitionRecord memory newRecognition = RecognitionRecord({
            country: _country,
            recognizer: msg.sender,
            recognitionDate: block.timestamp,
            isActive: true,
            recognitionDocument: _recognitionDocument
        });
        
        credentialRecognitions[_credentialId].push(newRecognition);
        
        verificationLogger.logVerification(holder, "COUNTRY_RECOGNITION", true, _country);
        emit CountryRecognition(_credentialId, _country, msg.sender, block.timestamp);
    }
    
    function revokeCountryRecognition(uint256 _credentialId, string memory _country) external onlyRole(RECOGNITION_ADMIN_ROLE) {
        RecognitionRecord[] storage recognitions = credentialRecognitions[_credentialId];
        
        for (uint i = 0; i < recognitions.length; i++) {
            if (keccak256(bytes(recognitions[i].country)) == keccak256(bytes(_country)) && recognitions[i].isActive) {
                recognitions[i].isActive = false;
                
                (, , address holder, , , , , , , , , ) = globalCredentialAnchor.getCredential(_credentialId);
                verificationLogger.logVerification(holder, "RECOGNITION_REVOKED", true, _country);
                emit RecognitionRevoked(_credentialId, _country, msg.sender, block.timestamp);
                break;
            }
        }
    }
    
    function getCountryRecognitions(uint256 _credentialId) external view returns (RecognitionRecord[] memory) {
        return credentialRecognitions[_credentialId];
    }
    
    function isRecognizedInCountry(uint256 _credentialId, string memory _country) external view returns (bool) {
        RecognitionRecord[] memory recognitions = credentialRecognitions[_credentialId];
        
        for (uint i = 0; i < recognitions.length; i++) {
            if (keccak256(bytes(recognitions[i].country)) == keccak256(bytes(_country)) && recognitions[i].isActive) {
                return true;
            }
        }
        return false;
    }
    
    function addRecognizedCountry(string memory _countryCode) external onlyRole(RECOGNITION_ADMIN_ROLE) {
        recognizedCountries[_countryCode] = true;
    }
}
