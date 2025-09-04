import { Address } from 'viem'

export const USER_REGISTRY_ADDRESS = (import.meta.env.VITE_USER_REGISTRY_ADDRESS || '').trim() as Address
export const ORG_REGISTRY_ADDRESS = (import.meta.env.VITE_ORG_REGISTRY_ADDRESS || '').trim() as Address
export const AUDIT_LOGGER_ADDRESS = (import.meta.env.VITE_AUDIT_LOGGER_ADDRESS || '').trim() as Address

// Minimal ABIs required by the UI
export const userRegistryAbi = [
  {
    type: 'function',
    name: 'registerUser',
    stateMutability: 'nonpayable',
    inputs: [
      { name: '_faceHash', type: 'bytes32' },
      { name: '_ipfsUri', type: 'string' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'upgradeToLevel2',
    stateMutability: 'nonpayable',
    inputs: [ { name: '_nationalIdHash', type: 'bytes32' } ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'updateIpfsProfileUri',
    stateMutability: 'nonpayable',
    inputs: [ { name: '_newUri', type: 'string' } ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'reactivateUser',
    stateMutability: 'nonpayable',
    inputs: [ { name: '_user', type: 'address' } ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'getUserVerificationLevel',
    stateMutability: 'view',
    inputs: [ { name: '_user', type: 'address' } ],
    outputs: [ { name: '', type: 'uint8' } ],
  },
  {
    type: 'function',
    name: 'isActive',
    stateMutability: 'view',
    inputs: [ { name: '_user', type: 'address' } ],
    outputs: [ { name: '', type: 'bool' } ],
  },
] as const

export const orgRegistryAbi = [
  {
    type: 'function',
    name: 'registerOrganization',
    stateMutability: 'nonpayable',
    inputs: [ { name: '_name', type: 'string' }, { name: '_ipfsUri', type: 'string' } ],
    outputs: [ { name: 'orgId', type: 'bytes32' } ],
  },
  {
    type: 'function',
    name: 'verifyOrganization',
    stateMutability: 'nonpayable',
    inputs: [ { name: '_orgId', type: 'bytes32' } ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'suspendOrganization',
    stateMutability: 'nonpayable',
    inputs: [ { name: '_orgId', type: 'bytes32' } ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'resumeOrganization',
    stateMutability: 'nonpayable',
    inputs: [ { name: '_orgId', type: 'bytes32' } ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'setOrgIssuer',
    stateMutability: 'nonpayable',
    inputs: [ { name: '_orgId', type: 'bytes32' }, { name: 'issuer', type: 'address' }, { name: 'allowed', type: 'bool' } ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'isOrgIssuer',
    stateMutability: 'view',
    inputs: [ { name: '_orgId', type: 'bytes32' }, { name: 'who', type: 'address' } ],
    outputs: [ { name: '', type: 'bool' } ],
  },
  {
    type: 'function',
    name: 'updateOrganizationMetadata',
    stateMutability: 'nonpayable',
    inputs: [ { name: '_orgId', type: 'bytes32' }, { name: 'newUri', type: 'string' } ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'setOrgIssuanceEnabled',
    stateMutability: 'nonpayable',
    inputs: [ { name: '_orgId', type: 'bytes32' }, { name: 'enabled', type: 'bool' } ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'issueCertificate',
    stateMutability: 'nonpayable',
    inputs: [
      { name: '_orgId', type: 'bytes32' },
      { name: '_recipient', type: 'address' },
      { name: '_certType', type: 'string' },
      { name: '_ipfsUri', type: 'string' },
      { name: '_minLevel', type: 'uint8' },
    ],
    outputs: [ { name: 'certId', type: 'bytes32' } ],
  },
  {
    type: 'function',
    name: 'revokeCertificate',
    stateMutability: 'nonpayable',
    inputs: [ { name: '_certId', type: 'bytes32' }, { name: 'reason', type: 'string' } ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'getUserCertificates',
    stateMutability: 'view',
    inputs: [ { name: '_user', type: 'address' } ],
    outputs: [ { name: '', type: 'bytes32[]' } ],
  },
  {
    type: 'function',
    name: 'getOrgCertificates',
    stateMutability: 'view',
    inputs: [ { name: '_orgId', type: 'bytes32' } ],
    outputs: [ { name: '', type: 'bytes32[]' } ],
  },
  {
    type: 'function',
    name: 'isCertificateCurrentlyValid',
    stateMutability: 'view',
    inputs: [ { name: '_certId', type: 'bytes32' } ],
    outputs: [ { name: '', type: 'bool' } ],
  },
  {
    type: 'function',
    name: 'getCertificate',
    stateMutability: 'view',
    inputs: [ { name: '_certId', type: 'bytes32' } ],
    outputs: [ {
      name: '', type: 'tuple', components: [
        { name: 'orgId', type: 'bytes32' },
        { name: 'recipient', type: 'address' },
        { name: 'certificateType', type: 'string' },
        { name: 'ipfsDocumentUri', type: 'string' },
        { name: 'issueDate', type: 'uint256' },
        { name: 'isActive', type: 'bool' },
        { name: 'minRequiredLevel', type: 'uint8' },
        { name: 'revokedAt', type: 'uint256' },
        { name: 'revokeReason', type: 'string' },
      ]
    } ],
  },
] as const

export const auditLoggerAbi = [
  {
    type: 'function',
    name: 'getTotalAuditCount',
    stateMutability: 'view',
    inputs: [],
    outputs: [ { name: '', type: 'uint256' } ],
  },
  {
    type: 'function',
    name: 'getAuditLog',
    stateMutability: 'view',
    inputs: [ { name: 'index', type: 'uint256' } ],
    outputs: [ {
      name: '', type: 'tuple', components: [
        { name: 'actor', type: 'address' },
        { name: 'target', type: 'address' },
        { name: 'actionType', type: 'uint8' },
        { name: 'dataHash', type: 'bytes32' },
        { name: 'timestamp', type: 'uint256' },
        { name: 'success', type: 'bool' },
        { name: 'additionalInfo', type: 'string' },
      ]
    } ],
  },
  {
    type: 'function',
    name: 'logsInRange',
    stateMutability: 'view',
    inputs: [ { name: 'start', type: 'uint256' }, { name: 'count', type: 'uint256' } ],
    outputs: [ { name: 'out', type: 'tuple[]', components: [
      { name: 'actor', type: 'address' },
      { name: 'target', type: 'address' },
      { name: 'actionType', type: 'uint8' },
      { name: 'dataHash', type: 'bytes32' },
      { name: 'timestamp', type: 'uint256' },
      { name: 'success', type: 'bool' },
      { name: 'additionalInfo', type: 'string' },
    ] } ],
  },
] as const

