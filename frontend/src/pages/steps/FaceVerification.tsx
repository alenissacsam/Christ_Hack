import { useRef, useState } from 'react'
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { useConfigStore } from '../../store/config'
import { abis } from '../../contracts/abis'
import { sha256Hex, fileToArrayBuffer } from '../../utils/hash'
import { toHexString } from '../../utils/hex'
import LipSyncVerification from '../../components/LipSyncVerification'
import { 
  createFaceVerificationSignature,
  prepareContractSignature
} from '../../utils/ethereumSignature'
import { storeFaceVerification, testPinataConnection } from '../../utils/pinata'
import { useAccount } from 'wagmi'

export default function FaceVerification({ onNext }: { onNext: () => void }) {
  const { address: userAddress } = useAccount()
  const videoRef = useRef<HTMLVideoElement>(null)
  const [hash, setHash] = useState<`0x${string}` | ''>('')
  const [proofHex, setProofHex] = useState<`0x${string}` | ''>('')
  const [biometricVerified, setBiometricVerified] = useState(false)
  const [biometricData, setBiometricData] = useState<any>(null)
  const [showBiometricChallenge, setShowBiometricChallenge] = useState(false)
  const [ethSignature, setEthSignature] = useState<string>('')
  const [ipfsHash, setIpfsHash] = useState<string>('')
  const address = useConfigStore((s) => s.addresses['UserIdentityRegistry'])
  const { writeContractAsync, data: txHash, isPending, error } = useWriteContract()
  const { isLoading: waiting, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })

  async function startCamera() {
    const stream = await navigator.mediaDevices.getUserMedia({ video: true })
    if (videoRef.current) {
      videoRef.current.srcObject = stream
      await videoRef.current.play()
    }
  }

  async function capture() {
    const v = videoRef.current
    if (!v) return
    const canvas = document.createElement('canvas')
    canvas.width = v.videoWidth
    canvas.height = v.videoHeight
    const ctx = canvas.getContext('2d')!
    ctx.drawImage(v, 0, 0)
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve))
    if (!blob) return
    const buf = await blob.arrayBuffer()
    const h = await sha256Hex(buf)
    setHash(h)
    // Show biometric challenge after face capture
    setShowBiometricChallenge(true)
  }

  async function handleBiometricComplete(success: boolean, data?: any) {
    setBiometricVerified(success)
    setBiometricData(data)
    
    if (success && data) {
      if (!userAddress) {
        alert('Please connect your wallet first')
        return
      }
      
      try {
        // Create Ethereum signature
        const signature = await createFaceVerificationSignature(
          userAddress,
          hash,
          data
        )
        setEthSignature(signature.signature)
        
        // Test Pinata and store if available
        const pinataReady = await testPinataConnection()
        if (pinataReady) {
          const ipfs = await storeFaceVerification(
            userAddress,
            {
              faceHash: hash,
              biometricScores: data,
              verificationTimestamp: data.timestamp || Date.now()
            },
            signature.signature,
            signature.hash
          )
          setIpfsHash(ipfs)
        }
        
        console.log('Face verification completed:', {
          userAddress,
          faceHash: hash,
          signature: signature.signature,
          ipfsHash
        })
        
      } catch (error) {
        console.error('Failed to generate verification signature:', error)
        alert('Failed to generate verification signature')
        setBiometricVerified(false)
      }
    } else if (data?.reason) {
      alert(`Biometric verification failed: ${data.reason}`)
    }
  }


  async function submit() {
    if (!address) return alert('Set UserIdentityRegistry address in Settings')
    if (!hash) return alert('Capture a frame to compute face hash')
    if (!biometricVerified) return alert('Complete biometric verification first')
    if (!ethSignature) return alert('Verification signature not generated')
    
    try {
      console.log('Submitting to smart contract:', {
        faceHash: hash,
        signature: ethSignature,
        userAddress,
        biometricData
      })
      
      // Use custom proof if provided, otherwise use generated signature
      const finalProof = proofHex || ethSignature as `0x${string}`
      
      const result = await writeContractAsync({
        address,
        abi: abis.UserIdentityRegistry as any,
        functionName: 'verifyFace',
        args: [hash, finalProof],
      })
      
      console.log('Smart contract submission complete:', {
        transactionHash: result,
        contractAddress: address,
        arguments: [hash, finalProof]
      })
      
    } catch (error) {
      console.error('Smart contract submission failed:', error)
      alert(`Transaction failed: ${error instanceof Error ? error.message : 'Unknown error'}`)
    }
  }

  return (
    <div className="space-y-6">
      {/* Face Verification */}
      <div className="glass p-4 rounded-lg border border-slate-200">
        <div className="font-semibold mb-3">👤 Selfie Face Check</div>
        <div className="grid md:grid-cols-2 gap-4">
          <div>
            <img src="/images/selfie-illustration.svg" alt="Selfie" className="w-28 mb-3 opacity-90" />
            <video ref={videoRef} className="w-full rounded-md bg-black/50" muted playsInline />
            <div className="flex gap-2 mt-2">
              <button className="px-3 py-2 rounded-md bg-white/10" onClick={startCamera}>Start Camera</button>
              <button className="px-3 py-2 rounded-md bg-white/10" onClick={capture}>Capture</button>
            </div>
          </div>
          <div>
            <div className="text-sm">Status:</div>
            <div className="text-xs bg-white/5 p-2 rounded-md space-y-1">
              <div>{hash ? '📸 Face captured ✓' : '❌ Face not captured'}</div>
              <div>{biometricVerified ? '🎥 Biometric verified ✓' : '❌ Biometric verification pending'}</div>
              <div>{ethSignature ? '🔒 Ethereum signature ✓' : '⏳ Awaiting signature'}</div>
              {ipfsHash && <div>🌐 IPFS stored ✓</div>}
            </div>
            <div className="mt-3">
              <details>
                <summary className="text-sm cursor-pointer text-white/80">Have a verification code? (optional)</summary>
                <div className="mt-2 grid gap-2">
                  <label className="block text-sm">
                    <div className="mb-1 text-white/70">Upload code file</div>
                    <input type="file" onChange={async (e)=>{
                      const f = e.target.files?.[0]; if (!f) return; const buf = await fileToArrayBuffer(f); setProofHex(toHexString(new Uint8Array(buf)))
                    }} />
                  </label>
                  <label className="block text-sm">
                    <div className="mb-1 text-white/70">Or paste code</div>
                    <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={proofHex} onChange={e=>setProofHex(e.target.value as any)} placeholder="paste code" />
                  </label>
                </div>
              </details>
            </div>
            <div className="flex items-center gap-3 mt-3">
              <button 
                className={`px-4 py-2 rounded-md ${hash && biometricVerified ? 'bg-brand-600 hover:bg-brand-700' : 'bg-gray-600 cursor-not-allowed'}`}
                onClick={submit} 
                disabled={isPending || !hash || !biometricVerified}
              >
                Submit
              </button>
              {isPending && <span className="text-xs">Submitting…</span>}
              {waiting && <span className="text-xs">Waiting…</span>}
              {isSuccess && <button className="text-xs underline" onClick={onNext}>Continue →</button>}
              {error && <span className="text-xs text-red-600">{error.message}</span>}
            </div>
          </div>
        </div>
        <div className="text-xs text-white/60 mt-3">Liveness hint: capture after moving your face; production implementations should add real liveness checks.</div>
      </div>

      {/* Biometric Verification - shows after face capture */}
      <LipSyncVerification 
        isActive={showBiometricChallenge}
        onVerificationComplete={handleBiometricComplete}
      />
    </div>
  )
}

