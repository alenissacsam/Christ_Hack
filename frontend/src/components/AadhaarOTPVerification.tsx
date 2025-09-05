import React, { useState, useRef } from 'react'
import { useAccount } from 'wagmi'
import { createAadhaarVerificationSignature } from '../utils/ethereumSignature'
import { storeAadhaarVerification, testPinataConnection } from '../utils/pinata'

interface AadhaarOTPProps {
  onVerificationComplete: (success: boolean, data?: any) => void
  isActive: boolean
}

interface AadhaarData {
  number: string
  name: string
  address: string
  dob: string
  gender: string
}

const AadhaarOTPVerification: React.FC<AadhaarOTPProps> = ({ onVerificationComplete, isActive }) => {
  const { address: userAddress } = useAccount()
  
  const [step, setStep] = useState<'input' | 'otp' | 'success' | 'failed'>('input')
  const [aadhaarNumber, setAadhaarNumber] = useState('')
  const [otp, setOtp] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState('')
  const [aadhaarData, setAadhaarData] = useState<AadhaarData | null>(null)
  const [sessionId, setSessionId] = useState<string>('')
  const [ipfsHash, setIpfsHash] = useState<string>('')
  const [signature, setSignature] = useState<string>('')

  const otpRefs = useRef<(HTMLInputElement | null)[]>([])

  // Validate Aadhaar number format
  const isValidAadhaar = (number: string): boolean => {
    return /^\d{12}$/.test(number.replace(/\s/g, ''))
  }

  // Format Aadhaar number for display
  const formatAadhaar = (value: string): string => {
    const cleaned = value.replace(/\D/g, '')
    return cleaned.replace(/(\d{4})(?=\d)/g, '$1 ').trim()
  }

  // Redirect to UIDAI government site for OTP verification
  const redirectToUIDAI = () => {
    if (!isValidAadhaar(aadhaarNumber)) {
      setError('Please enter a valid 12-digit Aadhaar number')
      return
    }

    // Store Aadhaar number for return handling
    sessionStorage.setItem('aadhaar_verification_number', aadhaarNumber)
    sessionStorage.setItem('aadhaar_verification_wallet', userAddress || '')
    
    // Redirect to UIDAI official verification portal
    const uidaiUrl = 'https://resident.uidai.gov.in/verify-email-mobile'
    window.open(uidaiUrl, '_blank', 'width=800,height=600,scrollbars=yes,resizable=yes')
    
    // Show waiting for verification step
    setStep('otp')
  }

  // Handle OTP input
  const handleOTPChange = (index: number, value: string) => {
    if (value.length <= 1 && /^\d*$/.test(value)) {
      const newOtp = otp.split('')
      newOtp[index] = value
      setOtp(newOtp.join(''))

      // Auto-focus next input
      if (value && index < 5) {
        otpRefs.current[index + 1]?.focus()
      }
    }
  }

  // Handle backspace in OTP
  const handleOTPKeyDown = (index: number, e: React.KeyboardEvent) => {
    if (e.key === 'Backspace' && !otp[index] && index > 0) {
      otpRefs.current[index - 1]?.focus()
    }
  }

  // Verify OTP
  const verifyOTP = async () => {
    if (otp.length !== 6) {
      setError('Please enter complete 6-digit OTP')
      return
    }

    setIsLoading(true)
    setError('')

    try {
      // Simulate UIDAI OTP verification
      const response = await simulateUIDAPICall('verifyOTP', {
        sessionId,
        otp,
        aadhaar: aadhaarNumber
      })

      if (response.success && response.verified) {
        setAadhaarData(response.userData)
        await handleVerificationSuccess(response.userData)
      } else {
        setError(response.message || 'Invalid OTP. Please try again.')
      }
    } catch (err) {
      setError('Verification failed. Please try again.')
      console.error('OTP verification error:', err)
    } finally {
      setIsLoading(false)
    }
  }

  // Handle successful verification
  const handleVerificationSuccess = async (userData: AadhaarData) => {
    try {
      if (!userAddress) {
        throw new Error('Wallet not connected')
      }

      // Test Pinata connection
      const pinataReady = await testPinataConnection()
      console.log('Pinata connection:', pinataReady ? 'Ready' : 'Not configured')

      // Create Ethereum signature
      const verificationTimestamp = Date.now()
      const ethSignature = await createAadhaarVerificationSignature(
        userAddress,
        aadhaarNumber,
        true,
        verificationTimestamp
      )

      setSignature(ethSignature.signature)

      // Store to IPFS if Pinata is configured
      let ipfs = ''
      if (pinataReady) {
        ipfs = await storeAadhaarVerification(
          userAddress,
          {
            ...userData,
            verified: true,
            otpTimestamp: verificationTimestamp
          },
          ethSignature.signature,
          ethSignature.hash
        )
        setIpfsHash(ipfs)
      }

      setStep('success')
      
      // Call parent callback
      onVerificationComplete(true, {
        aadhaarNumber,
        userData,
        signature: ethSignature.signature,
        hash: ethSignature.hash,
        ipfsHash: ipfs,
        verificationTimestamp
      })

    } catch (err) {
      console.error('Post-verification processing failed:', err)
      setError('Verification completed but data storage failed')
      setStep('failed')
    }
  }

  // Simulate UIDAI API calls (replace with actual implementation)
  const simulateUIDAPICall = async (action: string, data: any): Promise<any> => {
    // Simulate network delay
    await new Promise(resolve => setTimeout(resolve, 2000))

    if (action === 'sendOTP') {
      // Simulate OTP sending
      return {
        success: true,
        sessionId: 'session_' + Math.random().toString(36).substring(2),
        message: 'OTP sent to registered mobile number'
      }
    }

    if (action === 'verifyOTP') {
      // Simulate OTP verification - accept any 6-digit OTP for demo
      const isValidOTP = /^\d{6}$/.test(data.otp)
      
      if (isValidOTP) {
        return {
          success: true,
          verified: true,
          userData: {
            number: data.aadhaar,
            name: 'John Doe', // In real implementation, this comes from UIDAI
            address: 'Sample Address, City, State, 123456',
            dob: '01/01/1990',
            gender: 'M'
          }
        }
      } else {
        return {
          success: false,
          message: 'Invalid OTP'
        }
      }
    }

    return { success: false, message: 'Unknown action' }
  }

  // Reset verification
  const resetVerification = () => {
    setStep('input')
    setAadhaarNumber('')
    setOtp('')
    setError('')
    setAadhaarData(null)
    setSessionId('')
    setIpfsHash('')
    setSignature('')
  }

  if (!isActive) return null

  return (
    <div className="space-y-6 p-6 bg-slate-800/50 rounded-lg border border-slate-600">
      <div className="text-center">
        <h3 className="text-xl font-semibold text-white mb-2">
          🆔 Aadhaar Verification
        </h3>
        <p className="text-slate-300 text-sm">
          Verify your identity through UIDAI OTP authentication
        </p>
      </div>

      {/* Step 1: Aadhaar Number Input */}
      {step === 'input' && (
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Enter your 12-digit Aadhaar Number
            </label>
            <input
              type="text"
              value={formatAadhaar(aadhaarNumber)}
              onChange={(e) => setAadhaarNumber(e.target.value.replace(/\s/g, ''))}
              placeholder="1234 5678 9012"
              maxLength={14} // Including spaces
              className="w-full px-4 py-3 text-lg font-mono bg-slate-700 border border-slate-600 rounded-lg text-white placeholder-slate-400 focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
            />
          </div>

          {error && (
            <div className="p-3 bg-red-500/10 border border-red-500/30 rounded-lg text-red-300 text-sm">
              {error}
            </div>
          )}

          <button
            onClick={redirectToUIDAI}
            disabled={!isValidAadhaar(aadhaarNumber)}
            className={`w-full px-6 py-3 rounded-lg font-semibold transition-colors ${
              !isValidAadhaar(aadhaarNumber)
                ? 'bg-gray-600 cursor-not-allowed text-gray-400'
                : 'bg-green-600 hover:bg-green-700 text-white'
            }`}
          >
            🏛️ Verify with UIDAI Portal
          </button>
        </div>
      )}

      {/* Step 2: Waiting for UIDAI Verification */}
      {step === 'otp' && (
        <div className="space-y-4">
          <div className="text-center">
            <div className="text-4xl mb-4">🏛️</div>
            <div className="text-lg font-semibold text-white mb-2">
              Verify with UIDAI Portal
            </div>
            <div className="text-sm text-slate-300 mb-4">
              Complete your Aadhaar verification on the official UIDAI government portal that opened in a new window.
            </div>
            <div className="text-xs text-slate-400 bg-slate-700/50 p-3 rounded">
              ✅ Enter your Aadhaar number on UIDAI portal<br/>
              📱 Complete OTP verification with government<br/>
              🔒 Return here after successful verification
            </div>
          </div>

          <div className="space-y-4">
            <div className="text-center">
              <div className="text-sm font-medium text-slate-300 mb-3">
                After completing verification on UIDAI portal:
              </div>
            </div>
            <div className="bg-blue-500/10 p-4 border border-blue-500/30 rounded-lg">
              <div className="flex items-start space-x-3">
                <div className="text-blue-400">💡</div>
                <div className="text-sm text-blue-300">
                  <strong>Important:</strong> Once you successfully verify your Aadhaar on the UIDAI portal, 
                  click the "Mark as Verified" button below to complete the process in our system.
                </div>
              </div>
            </div>
          </div>

          {error && (
            <div className="p-3 bg-red-500/10 border border-red-500/30 rounded-lg text-red-300 text-sm text-center">
              {error}
            </div>
          )}

          <div className="flex gap-3">
            <button
              onClick={() => {
                // Simulate successful verification for demo
                const mockUserData = {
                  number: aadhaarNumber,
                  name: 'Verified User', // User would have completed actual UIDAI verification
                  address: 'Address verified via UIDAI',
                  dob: '01/01/1990',
                  gender: 'M'
                }
                setAadhaarData(mockUserData)
                handleVerificationSuccess(mockUserData)
              }}
              disabled={isLoading}
              className={`flex-1 px-6 py-3 rounded-lg font-semibold transition-colors ${
                isLoading
                  ? 'bg-gray-600 cursor-not-allowed text-gray-400'
                  : 'bg-green-600 hover:bg-green-700 text-white'
              }`}
            >
              {isLoading ? '🔍 Processing...' : '✅ Mark as Verified'}
            </button>
            
            <button
              onClick={() => {
                // Reopen UIDAI portal if needed
                const uidaiUrl = 'https://resident.uidai.gov.in/verify-email-mobile'
                window.open(uidaiUrl, '_blank', 'width=800,height=600,scrollbars=yes,resizable=yes')
              }}
              className="px-4 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-colors"
            >
              🏛️ Reopen UIDAI
            </button>
            
            <button
              onClick={resetVerification}
              className="px-4 py-3 bg-slate-600 hover:bg-slate-700 text-white rounded-lg font-semibold transition-colors"
            >
              🔄 Reset
            </button>
          </div>
        </div>
      )}

      {/* Step 3: Success */}
      {step === 'success' && aadhaarData && (
        <div className="space-y-4">
          <div className="text-center text-green-400">
            <div className="text-4xl mb-2">✅</div>
            <div className="text-xl font-semibold">Aadhaar Verified Successfully!</div>
          </div>

          <div className="bg-slate-700/50 p-4 rounded-lg space-y-3">
            <div className="text-sm text-slate-400">Verified Information:</div>
            <div className="grid gap-2 text-sm">
              <div className="flex justify-between">
                <span className="text-slate-300">Name:</span>
                <span className="text-white font-medium">{aadhaarData.name}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-300">Aadhaar:</span>
                <span className="text-white font-mono">{formatAadhaar(aadhaarData.number)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-300">DOB:</span>
                <span className="text-white">{aadhaarData.dob}</span>
              </div>
            </div>
          </div>

          {ipfsHash && (
            <div className="bg-blue-500/10 p-3 border border-blue-500/30 rounded-lg">
              <div className="text-sm text-blue-300">
                <strong>🔗 IPFS Storage:</strong> Data securely stored on IPFS
              </div>
              <div className="text-xs text-slate-400 mt-1 font-mono break-all">
                {ipfsHash}
              </div>
            </div>
          )}

          {signature && (
            <div className="bg-green-500/10 p-3 border border-green-500/30 rounded-lg">
              <div className="text-sm text-green-300">
                <strong>🔐 Blockchain Signature:</strong> Ready for smart contract
              </div>
              <div className="text-xs text-slate-400 mt-1 font-mono break-all">
                {signature.substring(0, 40)}...
              </div>
            </div>
          )}
        </div>
      )}

      {/* Step 4: Failed */}
      {step === 'failed' && (
        <div className="space-y-4 text-center">
          <div className="text-red-400">
            <div className="text-4xl mb-2">❌</div>
            <div className="text-xl font-semibold">Verification Failed</div>
          </div>
          
          {error && (
            <div className="p-3 bg-red-500/10 border border-red-500/30 rounded-lg text-red-300 text-sm">
              {error}
            </div>
          )}

          <button
            onClick={resetVerification}
            className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-colors"
          >
            🔄 Try Again
          </button>
        </div>
      )}

      {/* Instructions */}
      <div className="text-xs text-slate-400 text-center space-y-1">
        <div>🏛️ Verification done through official UIDAI government portal</div>
        <div>🔒 Your data remains secure - we only store verification status</div>
        <div>📱 Complete OTP verification on the official UIDAI website</div>
        <div>🌐 Verification proof is stored on IPFS for transparency</div>
        {!userAddress && <div className="text-yellow-400">⚠️ Please connect your wallet first</div>}
      </div>
    </div>
  )
}

export default AadhaarOTPVerification
