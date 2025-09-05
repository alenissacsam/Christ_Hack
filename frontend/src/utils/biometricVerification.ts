import { sha256Hex } from './hash'

export interface BiometricVerificationData {
  faceHash: string
  videoHash: string
  audioHash: string
  phrase: string
  recognized: string
  speechSimilarity: number
  lipSyncScore: number
  combinedScore: number
  timestamp: number
  userAgent: string
  challenge: string
}

export interface VerificationSignature {
  hash: `0x${string}`
  data: BiometricVerificationData
  signature: `0x${string}`
  metadata: {
    version: string
    algorithm: string
    created: number
  }
}

/**
 * Generate a comprehensive verification signature for blockchain submission
 */
export async function generateBiometricSignature(
  faceHash: string,
  biometricData: any
): Promise<VerificationSignature> {
  // Create standardized verification payload
  const verificationData: BiometricVerificationData = {
    faceHash,
    videoHash: biometricData.videoHash || '',
    audioHash: biometricData.audioHash || '',
    phrase: biometricData.phrase || '',
    recognized: biometricData.recognized || '',
    speechSimilarity: biometricData.speechSimilarity || 0,
    lipSyncScore: biometricData.lipSyncScore || 0,
    combinedScore: biometricData.combinedScore || 0,
    timestamp: biometricData.timestamp || Date.now(),
    userAgent: navigator.userAgent,
    challenge: Math.random().toString(36).substring(2, 15)
  }
  
  // Generate data hash
  const dataString = JSON.stringify(verificationData, Object.keys(verificationData).sort())
  const dataHash = await sha256Hex(new TextEncoder().encode(dataString))
  
  // Generate signature hash (includes additional entropy)
  const signaturePayload = {
    dataHash,
    timestamp: Date.now(),
    nonce: Math.random().toString(36).substring(2, 15),
    version: '1.0'
  }
  
  const signatureString = JSON.stringify(signaturePayload)
  const signature = await sha256Hex(new TextEncoder().encode(signatureString))
  
  return {
    hash: dataHash,
    data: verificationData,
    signature: signature,
    metadata: {
      version: '1.0',
      algorithm: 'SHA-256',
      created: Date.now()
    }
  }
}

/**
 * Prepare verification data for smart contract submission
 */
export function prepareSmartContractArgs(verificationSig: VerificationSignature): {
  faceHash: `0x${string}`
  proofData: `0x${string}`
  metadata: `0x${string}`
} {
  // Encode proof data as hex
  const proofDataString = JSON.stringify({
    signature: verificationSig.signature,
    combinedScore: verificationSig.data.combinedScore,
    speechSimilarity: verificationSig.data.speechSimilarity,
    lipSyncScore: verificationSig.data.lipSyncScore,
    timestamp: verificationSig.data.timestamp
  })
  
  // Encode metadata as hex
  const metadataString = JSON.stringify({
    version: verificationSig.metadata.version,
    algorithm: verificationSig.metadata.algorithm,
    phrase: verificationSig.data.phrase,
    videoHash: verificationSig.data.videoHash,
    audioHash: verificationSig.data.audioHash
  })
  
  return {
    faceHash: verificationSig.data.faceHash as `0x${string}`,
    proofData: `0x${Buffer.from(proofDataString).toString('hex')}` as `0x${string}`,
    metadata: `0x${Buffer.from(metadataString).toString('hex')}` as `0x${string}`
  }
}

/**
 * Validate biometric verification data before submission
 */
export function validateBiometricData(data: any): boolean {
  const required = [
    'speechSimilarity',
    'lipSyncScore', 
    'combinedScore',
    'phrase',
    'recognized'
  ]
  
  // Check required fields
  for (const field of required) {
    if (data[field] === undefined || data[field] === null) {
      console.error(`Missing required field: ${field}`)
      return false
    }
  }
  
  // Check score thresholds
  if (data.combinedScore < 0.6) {
    console.error('Combined verification score too low:', data.combinedScore)
    return false
  }
  
  if (data.speechSimilarity < 0.5) {
    console.error('Speech similarity too low:', data.speechSimilarity)
    return false
  }
  
  if (data.lipSyncScore < 0.4) {
    console.error('Lip-sync score too low:', data.lipSyncScore)
    return false
  }
  
  return true
}

/**
 * Create verification log entry for debugging
 */
export function createVerificationLog(
  verificationSig: VerificationSignature,
  contractResult?: any
): Record<string, any> {
  return {
    timestamp: new Date().toISOString(),
    verification: {
      faceHash: verificationSig.data.faceHash,
      combinedScore: verificationSig.data.combinedScore,
      speechSimilarity: verificationSig.data.speechSimilarity,
      lipSyncScore: verificationSig.data.lipSyncScore,
      phrase: verificationSig.data.phrase,
      recognized: verificationSig.data.recognized
    },
    signature: verificationSig.signature,
    contractResult: contractResult || null,
    metadata: verificationSig.metadata
  }
}
