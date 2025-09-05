import { ethers } from 'ethers'

// Backend private key should be stored securely in environment
// For demo purposes, using a placeholder key - in production, this should be handled server-side
const BACKEND_PRIVATE_KEY = import.meta.env?.VITE_BACKEND_PRIVATE_KEY || '0x' + '1'.repeat(64)

interface VerificationSignature {
  hash: `0x${string}`
  signature: `0x${string}`
  userAddress: string
  timestamp: number
}

/**
 * Create Ethereum signature exactly as backend does
 * Following the pattern: solidityKeccak256([address, bytes32]) then signMessage
 */
export async function createEthereumSignature(
  userAddress: string,
  dataHash: `0x${string}`
): Promise<VerificationSignature> {
  try {
    // Create backend wallet (in production, this should be server-side)
    const backendWallet = new ethers.Wallet(BACKEND_PRIVATE_KEY)
    
    // 1. Create hash exactly as in Solidity
    const message = ethers.utils.solidityKeccak256(
      ["address", "bytes32"],
      [userAddress, dataHash]
    )
    
    // 2. Make EIP-191 signature ("Ethereum Signed Message")
    const signature = await backendWallet.signMessage(ethers.utils.arrayify(message))
    
    return {
      hash: message as `0x${string}`,
      signature: signature as `0x${string}`,
      userAddress,
      timestamp: Date.now()
    }
  } catch (error) {
    console.error('Failed to create Ethereum signature:', error)
    throw new Error('Signature creation failed')
  }
}

/**
 * Verify Ethereum signature (for testing/validation)
 */
export function verifyEthereumSignature(
  signature: string,
  message: string,
  expectedSignerAddress: string
): boolean {
  try {
    const recoveredAddress = ethers.utils.verifyMessage(
      ethers.utils.arrayify(message),
      signature
    )
    return recoveredAddress.toLowerCase() === expectedSignerAddress.toLowerCase()
  } catch (error) {
    console.error('Signature verification failed:', error)
    return false
  }
}

/**
 * Create face verification signature
 */
export async function createFaceVerificationSignature(
  userAddress: string,
  faceHash: `0x${string}`,
  biometricData?: any
): Promise<VerificationSignature> {
  // Combine face hash with biometric data if available
  let finalHash = faceHash
  
  if (biometricData) {
    const combinedData = {
      faceHash,
      speechSimilarity: biometricData.speechSimilarity || 0,
      lipSyncScore: biometricData.lipSyncScore || 0,
      combinedScore: biometricData.combinedScore || 0,
      timestamp: biometricData.timestamp || Date.now()
    }
    
    // Hash the combined data
    const dataString = JSON.stringify(combinedData, Object.keys(combinedData).sort())
    finalHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(dataString)) as `0x${string}`
  }
  
  return createEthereumSignature(userAddress, finalHash)
}

/**
 * Create Aadhaar verification signature
 */
export async function createAadhaarVerificationSignature(
  userAddress: string,
  aadhaarNumber: string,
  otpVerified: boolean,
  verificationTimestamp: number
): Promise<VerificationSignature> {
  // Create standardized hash for Aadhaar verification
  const verificationData = {
    aadhaar: aadhaarNumber,
    verified: otpVerified,
    timestamp: verificationTimestamp,
    source: 'UIDAI_OTP'
  }
  
  const dataString = JSON.stringify(verificationData, Object.keys(verificationData).sort())
  const dataHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(dataString)) as `0x${string}`
  
  return createEthereumSignature(userAddress, dataHash)
}

/**
 * Create ITR verification signature
 */
export async function createITRVerificationSignature(
  userAddress: string,
  ackNumber: string,
  pan: string,
  filingDate: string
): Promise<VerificationSignature> {
  // Create hash exactly as specified: keccak256(ackNumber + PAN + filingDate)
  const combinedData = ackNumber + pan + filingDate
  const dataHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(combinedData)) as `0x${string}`
  
  return createEthereumSignature(userAddress, dataHash)
}

/**
 * Prepare signature data for smart contract submission
 */
export function prepareContractSignature(verificationSig: VerificationSignature): {
  hash: `0x${string}`
  signature: `0x${string}`
} {
  return {
    hash: verificationSig.hash,
    signature: verificationSig.signature
  }
}

/**
 * Extract backend wallet address (for verification purposes)
 */
export function getBackendWalletAddress(): string {
  const backendWallet = new ethers.Wallet(BACKEND_PRIVATE_KEY)
  return backendWallet.address
}

/**
 * Validate signature format
 */
export function isValidSignature(signature: string): boolean {
  try {
    return signature.startsWith('0x') && signature.length === 132 // 0x + 130 chars
  } catch {
    return false
  }
}
