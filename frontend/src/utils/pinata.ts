// Pinata IPFS integration for storing verification data
const PINATA_API_KEY = import.meta.env?.VITE_PINATA_API_KEY
const PINATA_SECRET_API_KEY = import.meta.env?.VITE_PINATA_SECRET_API_KEY
const PINATA_JWT = import.meta.env?.VITE_PINATA_JWT

interface PinataResponse {
  IpfsHash: string
  PinSize: number
  Timestamp: string
}

interface VerificationData {
  type: 'aadhaar' | 'itr' | 'face' | 'combined'
  userAddress: string
  timestamp: number
  data: any
  hash: string
  signature: string
}

/**
 * Upload JSON data to IPFS via Pinata
 */
export async function uploadToIPFS(data: any, filename?: string): Promise<string> {
  if (!PINATA_JWT && !PINATA_API_KEY) {
    throw new Error('Pinata credentials not configured')
  }

  try {
    const formData = new FormData()
    
    // Convert data to JSON blob
    const jsonBlob = new Blob([JSON.stringify(data, null, 2)], {
      type: 'application/json'
    })
    
    formData.append('file', jsonBlob, filename || 'verification-data.json')
    
    // Add metadata
    const metadata = JSON.stringify({
      name: filename || 'Verification Data',
      keyvalues: {
        type: data.type || 'verification',
        timestamp: data.timestamp || Date.now(),
        userAddress: data.userAddress || 'unknown'
      }
    })
    formData.append('pinataMetadata', metadata)
    
    // Add pin options
    const options = JSON.stringify({
      cidVersion: 0,
      customPinPolicy: {
        regions: [
          {
            id: 'FRA1',
            desiredReplicationCount: 1
          },
          {
            id: 'NYC1', 
            desiredReplicationCount: 1
          }
        ]
      }
    })
    formData.append('pinataOptions', options)

    const headers: HeadersInit = {}
    
    if (PINATA_JWT) {
      headers['Authorization'] = `Bearer ${PINATA_JWT}`
    } else {
      headers['pinata_api_key'] = PINATA_API_KEY!
      headers['pinata_secret_api_key'] = PINATA_SECRET_API_KEY!
    }

    const response = await fetch('https://api.pinata.cloud/pinning/pinFileToIPFS', {
      method: 'POST',
      headers,
      body: formData
    })

    if (!response.ok) {
      throw new Error(`Pinata upload failed: ${response.statusText}`)
    }

    const result: PinataResponse = await response.json()
    console.log('Successfully uploaded to IPFS:', result.IpfsHash)
    
    return result.IpfsHash
  } catch (error) {
    console.error('Failed to upload to IPFS:', error)
    throw error
  }
}

/**
 * Store Aadhaar verification data to IPFS
 */
export async function storeAadhaarVerification(
  userAddress: string,
  aadhaarData: {
    number: string
    name: string
    address: string
    dob: string
    verified: boolean
    otpTimestamp: number
  },
  signature: string,
  hash: string
): Promise<string> {
  const verificationData: VerificationData = {
    type: 'aadhaar',
    userAddress,
    timestamp: Date.now(),
    data: {
      ...aadhaarData,
      // Mask sensitive data
      maskedAadhaar: aadhaarData.number.replace(/\d(?=\d{4})/g, 'X'),
      verificationMethod: 'UIDAI_OTP'
    },
    hash,
    signature
  }
  
  const filename = `aadhaar-verification-${userAddress.slice(2, 8)}-${Date.now()}.json`
  return uploadToIPFS(verificationData, filename)
}

/**
 * Store ITR verification data to IPFS
 */
export async function storeITRVerification(
  userAddress: string,
  itrData: {
    ackNumber: string
    pan: string
    filingDate: string
    assessmentYear: string
    verified: boolean
  },
  signature: string,
  hash: string
): Promise<string> {
  const verificationData: VerificationData = {
    type: 'itr',
    userAddress,
    timestamp: Date.now(),
    data: {
      ...itrData,
      verificationMethod: 'INCOME_TAX_PORTAL'
    },
    hash,
    signature
  }
  
  const filename = `itr-verification-${userAddress.slice(2, 8)}-${Date.now()}.json`
  return uploadToIPFS(verificationData, filename)
}

/**
 * Store face verification data to IPFS
 */
export async function storeFaceVerification(
  userAddress: string,
  faceData: {
    faceHash: string
    biometricScores: any
    verificationTimestamp: number
  },
  signature: string,
  hash: string
): Promise<string> {
  const verificationData: VerificationData = {
    type: 'face',
    userAddress,
    timestamp: Date.now(),
    data: {
      ...faceData,
      verificationMethod: 'BIOMETRIC_LIPSYNC'
    },
    hash,
    signature
  }
  
  const filename = `face-verification-${userAddress.slice(2, 8)}-${Date.now()}.json`
  return uploadToIPFS(verificationData, filename)
}

/**
 * Store combined verification data to IPFS
 */
export async function storeCombinedVerification(
  userAddress: string,
  combinedData: {
    aadhaarHash: string
    faceHash: string
    itrHash: string
    completedSteps: string[]
    totalScore: number
  },
  signature: string,
  hash: string
): Promise<string> {
  const verificationData: VerificationData = {
    type: 'combined',
    userAddress,
    timestamp: Date.now(),
    data: {
      ...combinedData,
      verificationMethod: 'MULTI_STEP_KYC'
    },
    hash,
    signature
  }
  
  const filename = `combined-verification-${userAddress.slice(2, 8)}-${Date.now()}.json`
  return uploadToIPFS(verificationData, filename)
}

/**
 * Retrieve data from IPFS
 */
export async function retrieveFromIPFS(ipfsHash: string): Promise<any> {
  try {
    const response = await fetch(`https://gateway.pinata.cloud/ipfs/${ipfsHash}`)
    
    if (!response.ok) {
      throw new Error(`Failed to retrieve from IPFS: ${response.statusText}`)
    }
    
    return await response.json()
  } catch (error) {
    console.error('Failed to retrieve from IPFS:', error)
    throw error
  }
}

/**
 * Test Pinata connection
 */
export async function testPinataConnection(): Promise<boolean> {
  try {
    const headers: HeadersInit = {}
    
    if (PINATA_JWT) {
      headers['Authorization'] = `Bearer ${PINATA_JWT}`
    } else if (PINATA_API_KEY) {
      headers['pinata_api_key'] = PINATA_API_KEY
      headers['pinata_secret_api_key'] = PINATA_SECRET_API_KEY!
    } else {
      return false
    }

    const response = await fetch('https://api.pinata.cloud/data/testAuthentication', {
      method: 'GET',
      headers
    })

    return response.ok
  } catch (error) {
    console.error('Pinata connection test failed:', error)
    return false
  }
}

/**
 * Get IPFS gateway URL
 */
export function getIPFSUrl(hash: string): string {
  return `https://gateway.pinata.cloud/ipfs/${hash}`
}
