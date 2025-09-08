// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface IVerificationLogger {
    function logEvent(
        string memory eventType,
        address user,
        bytes32 dataHash
    ) external;
}

contract GlobalCredentialAnchor is AccessControl {
    bytes32 public constant ROOT_UPDATER_ROLE = keccak256("ROOT_UPDATER_ROLE");

    struct CredentialRoot {
        bytes32 root;
        uint256 timestamp;
        string sourceDescription;
        bool isActive;
    }

    mapping(string => CredentialRoot) public credentialRoots;
    mapping(bytes32 => bool) public validRoots;
    string[] public rootSources;

    IVerificationLogger public verificationLogger;

    event RootUpdated(string indexed source, bytes32 indexed root);
    event RootDeactivated(string indexed source, bytes32 indexed root);

    constructor(address _verificationLogger) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ROOT_UPDATER_ROLE, msg.sender);
        verificationLogger = IVerificationLogger(_verificationLogger);
    }

    function updateCredentialRoot(
        string memory source,
        bytes32 newRoot,
        string memory description
    ) external onlyRole(ROOT_UPDATER_ROLE) {
        require(bytes(source).length > 0, "Source cannot be empty");
        require(newRoot != bytes32(0), "Invalid root");

        // Deactivate old root if exists
        if (credentialRoots[source].isActive) {
            validRoots[credentialRoots[source].root] = false;
        } else {
            rootSources.push(source);
        }

        credentialRoots[source] = CredentialRoot({
            root: newRoot,
            timestamp: block.timestamp,
            sourceDescription: description,
            isActive: true
        });

        validRoots[newRoot] = true;

        verificationLogger.logEvent(
            "CREDENTIAL_ROOT_UPDATED",
            msg.sender,
            keccak256(abi.encodePacked(source, newRoot))
        );

        emit RootUpdated(source, newRoot);
    }

    function deactivateCredentialRoot(
        string memory source
    ) external onlyRole(ROOT_UPDATER_ROLE) {
        require(credentialRoots[source].isActive, "Root not active");

        bytes32 root = credentialRoots[source].root;
        credentialRoots[source].isActive = false;
        validRoots[root] = false;

        verificationLogger.logEvent(
            "CREDENTIAL_ROOT_DEACTIVATED",
            msg.sender,
            keccak256(abi.encodePacked(source, root))
        );

        emit RootDeactivated(source, root);
    }

    function verifyCredentialInclusion(
        bytes32 root,
        bytes32 leaf,
        bytes32[] calldata proof
    ) external view returns (bool) {
        require(validRoots[root], "Invalid or inactive root");
        return MerkleProof.verify(proof, root, leaf);
    }

    function verifyCredentialInclusionBySource(
        string memory source,
        bytes32 leaf,
        bytes32[] calldata proof
    ) external view returns (bool) {
        require(credentialRoots[source].isActive, "Source not active");
        bytes32 root = credentialRoots[source].root;
        return MerkleProof.verify(proof, root, leaf);
    }

    function getActiveRoot(
        string memory source
    ) external view returns (bytes32) {
        require(credentialRoots[source].isActive, "Source not active");
        return credentialRoots[source].root;
    }

    function getAllSources() external view returns (string[] memory) {
        return rootSources;
    }
}
