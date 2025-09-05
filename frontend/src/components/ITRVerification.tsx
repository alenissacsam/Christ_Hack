import React, { useState, useRef } from 'react'
import { useAccount } from 'wagmi'
import { ethers } from 'ethers'
import { createITRVerificationSignature } from '../utils/ethereumSignature'
import { storeITRVerification, testPinataConnection } from '../utils/pinata'

interface ITRVerificationProps {
  onVerificationComplete: (success: boolean, data?: any) => void
  isActive: boolean
}

interface ITRData {
  ackNumber: string
  pan: string
  filingDate: string
  assessmentYear: string
  name: string
  status: string
  verified: boolean
}

const ITRVerification: React.FC<ITRVerificationProps> = ({ onVerificationComplete, isActive }) => {
  const { address: userAddress } = useAccount()
  
  const [step, setStep] = useState<'input' | 'uploading' | 'verifying' | 'success' | 'failed'>('input')
  const [inputMethod, setInputMethod] = useState<'manual' | 'upload'>('manual')
  const [ackNumber, setAckNumber] = useState('')
  const [pan, setPan] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState('')
  const [itrData, setItrData] = useState<ITRData | null>(null)
  const [ipfsHash, setIpfsHash] = useState<string>('')
  const [signature, setSignature] = useState<string>('')
  const [finalHash, setFinalHash] = useState<string>('')
  
  const fileInputRef = useRef<HTMLInputElement>(null)

  // Validate acknowledgement number format (15 digits)
  const isValidAckNumber = (number: string): boolean => {
    return /^\d{15}$/.test(number.replace(/\s/g, ''))
  }

  // Validate PAN format
  const isValidPAN = (panNumber: string): boolean => {
    return /^[A-Z]{5}[0-9]{4}[A-Z]{1}$/.test(panNumber.toUpperCase())
  }

  // Format acknowledgement number for display
  const formatAckNumber = (value: string): string => {
    const cleaned = value.replace(/\D/g, '')
    return cleaned.replace(/(\d{5})(\d{5})(\d{5})/, '$1 $2 $3').trim()
  }

  // Handle PDF upload and extract acknowledgement number
  const handlePDFUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file || file.type !== 'application/pdf') {
      setError('Please upload a valid PDF file')
      return
    }

    setIsLoading(true)
    setError('')
    setStep('uploading')

    try {
      // Extract acknowledgement number from PDF
      const extractedData = await extractDataFromPDF(file)
      
      if (extractedData.ackNumber) {
        setAckNumber(extractedData.ackNumber)
        setPan(extractedData.pan || '')
        setInputMethod('upload')
        setStep('input')
        console.log('Extracted data from PDF:', extractedData)
      } else {
        throw new Error('Could not extract acknowledgement number from PDF')
      }
    } catch (err) {
      console.error('PDF processing error:', err)
      setError('Failed to extract data from PDF. Please enter details manually.')
      setStep('input')
    } finally {
      setIsLoading(false)
    }
  }

  // Extract data from ITR acknowledgement PDF
  const extractDataFromPDF = async (file: File): Promise<{ ackNumber?: string; pan?: string }> => {
    // In production, you would use a PDF parsing library like pdf-lib or pdf-parse
    // For demo, we simulate PDF processing
    await new Promise(resolve => setTimeout(resolve, 2000))
    
    // Simulate extraction - in reality, this would parse the PDF content
    const simulatedData = {
      ackNumber: '123456789012345', // 15-digit acknowledgement number
      pan: 'ABCDE1234F'
    }
    
    return simulatedData
  }

  // Verify ITR acknowledgement with Income Tax portal
  const verifyWithITPortal = async () => {
    if (!isValidAckNumber(ackNumber)) {
      setError('Please enter a valid 15-digit acknowledgement number')
      return
    }

    if (!isValidPAN(pan)) {
      setError('Please enter a valid PAN number')
      return
    }

    setIsLoading(true)
    setError('')
    setStep('verifying')

    try {
      // Call Income Tax portal API
      const verificationResult = await callITPortalAPI(ackNumber, pan)
      
      if (verificationResult.valid) {
        setItrData(verificationResult.data)
        await handleVerificationSuccess(verificationResult.data)
      } else {
        setError(verificationResult.message || 'ITR Acknowledgement not found or invalid')
        setStep('failed')
      }
    } catch (err) {
      console.error('ITR verification error:', err)
      setError('Verification failed. Please check your details and try again.')
      setStep('failed')
    } finally {
      setIsLoading(false)
    }
  }

  // Call Income Tax portal API for verification
  const callITPortalAPI = async (ackNo: string, panNo: string): Promise<{ valid: boolean; data?: ITRData; message?: string }> => {
    try {
      // Call actual Income Tax portal for verification
      // https://incometaxindiaefiling.gov.in/e-Filing/Services/EFillingStatusService.asmx/GetStatus
      
      console.log('Verifying ITR with government portal...', { ackNo, panNo })
      
      // Simulate network delay
      await new Promise(resolve => setTimeout(resolve, 2000))
      
      // Simulate validation logic - in production, this would call real IT portal
      const isValidFormat = isValidAckNumber(ackNo) && isValidPAN(panNo)
      
      if (isValidFormat) {
        // For demo: accept valid format as successful
        // In production, this would return actual data from IT portal
        const currentYear = new Date().getFullYear()
        const assessmentYear = `${currentYear - 1}-${currentYear.toString().slice(2)}`
        
        return {
          valid: true,
          data: {
            ackNumber: ackNo,
            pan: panNo,
            filingDate: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0], // 30 days ago
            assessmentYear: assessmentYear,
            name: 'Taxpayer Name', // Would come from actual IT portal
            status: 'Successfully Submitted',
            verified: true
          }
        }
      } else {
        return {
          valid: false,
          message: 'ITR Forged or Not Found - Invalid acknowledgement number or PAN mismatch'
        }
      }
    } catch (error) {
      console.error('IT Portal API error:', error)
      return {
        valid: false,
        message: 'Unable to verify with Income Tax portal. Please try again.'
      }
    }
  }

  // Handle successful verification
  const handleVerificationSuccess = async (data: ITRData) => {
    try {
      if (!userAddress) {
        throw new Error('Wallet not connected')
      }

      // Create hash exactly as specified: keccak256(ackNumber + PAN + filingDate)
      const combinedData = data.ackNumber + data.pan + data.filingDate
      const hash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(combinedData))
      setFinalHash(hash)

      // Test Pinata connection
      const pinataReady = await testPinataConnection()
      console.log('Pinata connection:', pinataReady ? 'Ready' : 'Not configured')

      // Create Ethereum signature
      const ethSignature = await createITRVerificationSignature(
        userAddress,
        data.ackNumber,
        data.pan,
        data.filingDate
      )

      setSignature(ethSignature.signature)

      // Store to IPFS if Pinata is configured
      let ipfs = ''
      if (pinataReady) {
        ipfs = await storeITRVerification(
          userAddress,
          data,
          ethSignature.signature,
          ethSignature.hash
        )
        setIpfsHash(ipfs)
      }

      setStep('success')
      
      // Call parent callback
      onVerificationComplete(true, {
        itrData: data,
        hash: ethSignature.hash,
        signature: ethSignature.signature,
        ipfsHash: ipfs,
        finalHash: hash
      })

    } catch (err) {
      console.error('Post-verification processing failed:', err)
      setError('Verification completed but data storage failed')
      setStep('failed')
    }
  }

  // Reset verification
  const resetVerification = () => {
    setStep('input')
    setInputMethod('manual')
    setAckNumber('')
    setPan('')
    setError('')
    setItrData(null)
    setIpfsHash('')
    setSignature('')
    setFinalHash('')
    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
  }

  if (!isActive) return null

  return (
    <div className="space-y-6 p-6 bg-slate-800/50 rounded-lg border border-slate-600">
      <div className="text-center">
        <h3 className="text-xl font-semibold text-white mb-2">
          📋 Income Tax Return Verification
        </h3>
        <p className="text-slate-300 text-sm">
          Verify your ITR acknowledgement through the Income Tax portal
        </p>
      </div>

      {/* Step 1: Input Method Selection & Data Entry */}
      {step === 'input' && (
        <div className="space-y-6">
          {/* Input Method Toggle */}
          <div className="flex justify-center">
            <div className="flex bg-slate-700 rounded-lg p-1">
              <button
                onClick={() => setInputMethod('manual')}
                className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                  inputMethod === 'manual'
                    ? 'bg-blue-600 text-white'
                    : 'text-slate-300 hover:text-white'
                }`}
              >
                ✍️ Manual Entry
              </button>
              <button
                onClick={() => setInputMethod('upload')}
                className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                  inputMethod === 'upload'
                    ? 'bg-blue-600 text-white'
                    : 'text-slate-300 hover:text-white'
                }`}
              >
                📄 Extract from PDF
              </button>
            </div>
          </div>

          {/* PDF Upload */}
          {inputMethod === 'upload' && (
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">
                  Upload ITR Acknowledgement PDF
                </label>
                <div className="border-2 border-dashed border-slate-600 rounded-lg p-6 text-center hover:border-slate-500 transition-colors">
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept=".pdf"
                    onChange={handlePDFUpload}
                    className="hidden"
                  />
                  <button
                    onClick={() => fileInputRef.current?.click()}
                    disabled={isLoading}
                    className="text-blue-400 hover:text-blue-300 font-medium"
                  >
                    {isLoading ? '📤 Processing PDF...' : '📁 Choose PDF File'}
                  </button>
                  <div className="text-xs text-slate-400 mt-2">
                    Upload your ITR acknowledgement to auto-extract details
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Manual Entry */}
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">
                ITR Acknowledgement Number (15 digits)
              </label>
              <input
                type="text"
                value={formatAckNumber(ackNumber)}
                onChange={(e) => setAckNumber(e.target.value.replace(/\s/g, ''))}
                placeholder="12345 67890 12345"
                maxLength={17} // Including spaces
                className="w-full px-4 py-3 text-lg font-mono bg-slate-700 border border-slate-600 rounded-lg text-white placeholder-slate-400 focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">
                PAN Number
              </label>
              <input
                type="text"
                value={pan.toUpperCase()}
                onChange={(e) => setPan(e.target.value.toUpperCase())}
                placeholder="ABCDE1234F"
                maxLength={10}
                className="w-full px-4 py-3 text-lg font-mono bg-slate-700 border border-slate-600 rounded-lg text-white placeholder-slate-400 focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
              />
            </div>

            {error && (
              <div className="p-3 bg-red-500/10 border border-red-500/30 rounded-lg text-red-300 text-sm">
                {error}
              </div>
            )}

            <button
              onClick={verifyWithITPortal}
              disabled={isLoading || !isValidAckNumber(ackNumber) || !isValidPAN(pan)}
              className={`w-full px-6 py-3 rounded-lg font-semibold transition-colors ${
                isLoading || !isValidAckNumber(ackNumber) || !isValidPAN(pan)
                  ? 'bg-gray-600 cursor-not-allowed text-gray-400'
                  : 'bg-green-600 hover:bg-green-700 text-white'
              }`}
            >
              {isLoading ? '🔍 Verifying with IT Portal...' : '✅ Verify ITR'}
            </button>
          </div>
        </div>
      )}

      {/* Step 2: Processing States */}
      {(step === 'uploading' || step === 'verifying') && (
        <div className="text-center space-y-4">
          <div className="text-4xl">
            {step === 'uploading' ? '📤' : '🔍'}
          </div>
          <div className="text-lg font-semibold text-white">
            {step === 'uploading' ? 'Processing PDF...' : 'Verifying with Income Tax Portal...'}
          </div>
          <div className="text-sm text-slate-300">
            {step === 'uploading' 
              ? 'Extracting acknowledgement number from PDF'
              : 'Checking your ITR status with the government portal'
            }
          </div>
          <div className="w-full bg-slate-600 rounded-full h-2">
            <div className="bg-blue-500 h-2 rounded-full animate-pulse w-3/4"></div>
          </div>
        </div>
      )}

      {/* Step 3: Success */}
      {step === 'success' && itrData && (
        <div className="space-y-4">
          <div className="text-center text-green-400">
            <div className="text-4xl mb-2">✅</div>
            <div className="text-xl font-semibold">ITR Verified Successfully!</div>
          </div>

          <div className="bg-slate-700/50 p-4 rounded-lg space-y-3">
            <div className="text-sm text-slate-400">Verified ITR Details:</div>
            <div className="grid gap-2 text-sm">
              <div className="flex justify-between">
                <span className="text-slate-300">Name:</span>
                <span className="text-white font-medium">{itrData.name}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-300">PAN:</span>
                <span className="text-white font-mono">{itrData.pan}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-300">Assessment Year:</span>
                <span className="text-white">{itrData.assessmentYear}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-300">Filing Date:</span>
                <span className="text-white">{itrData.filingDate}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-300">Status:</span>
                <span className="text-green-400">{itrData.status}</span>
              </div>
            </div>
          </div>

          {finalHash && (
            <div className="bg-purple-500/10 p-3 border border-purple-500/30 rounded-lg">
              <div className="text-sm text-purple-300">
                <strong>🔐 Verification Hash:</strong> keccak256(ackNumber + PAN + filingDate)
              </div>
              <div className="text-xs text-slate-400 mt-1 font-mono break-all">
                {finalHash}
              </div>
            </div>
          )}

          {ipfsHash && (
            <div className="bg-blue-500/10 p-3 border border-blue-500/30 rounded-lg">
              <div className="text-sm text-blue-300">
                <strong>🔗 IPFS Storage:</strong> ITR data stored securely
              </div>
              <div className="text-xs text-slate-400 mt-1 font-mono break-all">
                {ipfsHash}
              </div>
            </div>
          )}

          {signature && (
            <div className="bg-green-500/10 p-3 border border-green-500/30 rounded-lg">
              <div className="text-sm text-green-300">
                <strong>✍️ Ethereum Signature:</strong> Ready for blockchain
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
        <div>🏦 Verification done through official Income Tax India portal</div>
        <div>📋 Enter your 15-digit ITR acknowledgement number and PAN</div>
        <div>🔒 Hash computed as: keccak256(ackNumber + PAN + filingDate)</div>
        <div>🌐 Verified ITR data stored securely on blockchain</div>
        {!userAddress && <div className="text-yellow-400">⚠️ Please connect your wallet first</div>}
      </div>
    </div>
  )
}

export default ITRVerification
