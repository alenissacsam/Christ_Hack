import { useEffect, useRef, useState } from 'react'
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { useConfigStore } from '../../store/config'
import { abis } from '../../contracts/abis'
import { fileToArrayBuffer, sha256Hex } from '../../utils/hash'
import jsQR from 'jsqr'
import { toHexString } from '../../utils/hex'

export default function AadhaarVerification({ onNext, onBack }: { onNext: () => void; onBack: () => void }) {
  const [qrText, setQrText] = useState('')
  const [aadhaarNumber, setAadhaarNumber] = useState('')
  const [scanning, setScanning] = useState(false)
  const [scanStatus, setScanStatus] = useState<'idle'|'scanning'|'detected'|'error'>('idle')
  const videoRef = useRef<HTMLVideoElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const address = useConfigStore((s) => s.addresses['UserIdentityRegistry'])
  const { writeContractAsync, data: txHash, isPending, error } = useWriteContract()
  const { isLoading: waiting, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })

  async function onFile(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0]
    if (!f) return
    const img = new Image()
    img.onload = async () => {
      const canvas = document.createElement('canvas')
      canvas.width = img.width
      canvas.height = img.height
      const ctx = canvas.getContext('2d')!
      ctx.drawImage(img, 0, 0)
      const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
      const code = jsQR(imageData.data, imageData.width, imageData.height)
      if (code?.data) setQrText(code.data)
      else alert('Could not find QR. Please try another image or use camera scan.')
    }
    img.src = URL.createObjectURL(f)
  }

async function startScan() {
    if (!videoRef.current) return
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' } } })
      streamRef.current = stream
      videoRef.current.srcObject = stream
      ;(videoRef.current as any).playsInline = true
      await videoRef.current.play()
      setScanning(true)
      setScanStatus('scanning')

      const tick = () => {
        if (!scanning || !videoRef.current) return
        const video = videoRef.current
        const canvas = canvasRef.current
        if (!canvas) { requestAnimationFrame(tick); return }
        canvas.width = video.videoWidth
        canvas.height = video.videoHeight
        const ctx = canvas.getContext('2d')!
        ctx.clearRect(0, 0, canvas.width, canvas.height)
        const imageData = (() => {
          const tmp = document.createElement('canvas')
          tmp.width = video.videoWidth
          tmp.height = video.videoHeight
          const tctx = tmp.getContext('2d')!
          tctx.drawImage(video, 0, 0)
          return tctx.getImageData(0, 0, tmp.width, tmp.height)
        })()
        const code = jsQR(imageData.data, imageData.width, imageData.height)
        if (code) {
          // draw bounding box
          ctx.strokeStyle = '#22c55e'
          ctx.lineWidth = 4
          ctx.beginPath()
          ctx.moveTo(code.location.topLeftCorner.x, code.location.topLeftCorner.y)
          ctx.lineTo(code.location.topRightCorner.x, code.location.topRightCorner.y)
          ctx.lineTo(code.location.bottomRightCorner.x, code.location.bottomRightCorner.y)
          ctx.lineTo(code.location.bottomLeftCorner.x, code.location.bottomLeftCorner.y)
          ctx.closePath()
          ctx.stroke()
          setQrText(code.data)
          setScanStatus('detected')
          stopScan()
        } else {
          // scanning indicator
          ctx.strokeStyle = 'rgba(255,255,255,0.4)'
          ctx.lineWidth = 2
          const mid = canvas.height / 2
          ctx.beginPath()
          ctx.moveTo(20, mid)
          ctx.lineTo(canvas.width - 20, mid)
          ctx.stroke()
          requestAnimationFrame(tick)
        }
      }
      requestAnimationFrame(tick)
    } catch (e) {
      setScanStatus('error')
      alert('Camera access denied. You can upload Aadhaar image instead.')
    }
  }

  function stopScan() {
    setScanning(false)
    const s = streamRef.current
    if (s) s.getTracks().forEach(t => t.stop())
    streamRef.current = null
  }

  useEffect(() => {
    return () => stopScan()
  }, [])

  async function submit() {
    if (!address) { alert('Set UserIdentityRegistry address in Settings'); (window as any).openChatWithPrompt?.('Need help setting contract addresses?'); return }
    if (!qrText) { alert('Scan or upload Aadhaar QR first'); (window as any).openChatWithPrompt?.('Having trouble scanning the QR? Try better lighting or upload a photo.'); return }
    const h = await sha256Hex(qrText)
    const proofHex = toHexString(new TextEncoder().encode(qrText))
    await writeContractAsync({
      address,
      abi: abis.UserIdentityRegistry as any,
      functionName: 'verifyAadhaar',
      args: [h, proofHex],
    })
  }

  return (
    <div className="glass p-4 rounded-lg border border-slate-200">
      <div className="font-semibold mb-3">Aadhaar Verification (Scan QR)</div>
      <div className="grid md:grid-cols-2 gap-4">
        <div>
          <img src="/images/aadhaar-illustration.svg" alt="Aadhaar" className="w-28 mb-3 opacity-90" />
          <div className="text-sm mb-2">Scan Aadhaar QR</div>
          <div className="relative rounded-lg overflow-hidden border border-white/10 w-full max-w-md aspect-video bg-black/40">
            <video ref={videoRef} className="absolute inset-0 w-full h-full object-cover" muted playsInline />
            <canvas ref={canvasRef} className="absolute inset-0 w-full h-full" />
          </div>
          <div className="flex gap-2 mt-2">
            {!scanning && (
              <button className="px-3 py-2 rounded-md bg-white/10" onClick={startScan}>Use Camera</button>
            )}
            {scanning && (
              <button className="px-3 py-2 rounded-md bg-white/10" onClick={stopScan}>Stop</button>
            )}
            <label className="px-3 py-2 rounded-md bg-white/10 cursor-pointer">
              Upload Photo
              <input type="file" accept="image/*" onChange={onFile} className="hidden" />
            </label>
          </div>
          <div className="text-xs mt-2">
            {scanStatus==='idle' && <span className="text-white/70">Idle</span>}
            {scanStatus==='scanning' && <span className="text-amber-300">Scanning… hold QR steady</span>}
            {scanStatus==='detected' && <span className="text-emerald-400">QR detected ✓</span>}
            {scanStatus==='error' && <span className="text-red-400">Camera error</span>}
          </div>
          <div className="text-xs text-white/70 mt-2">We will securely hash the QR data and submit it. The hash is never shown.</div>
        </div>
        <div>
          <label className="block text-sm">
            <div className="mb-1 text-slate-600">Aadhaar Number (last 4 digits, optional)</div>
            <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={aadhaarNumber} onChange={e=>setAadhaarNumber(e.target.value)} placeholder="1234" />
          </label>
          <div className="mt-3 flex items-center gap-3">
            <button className="px-4 py-2 rounded-md bg-white/10" onClick={onBack}>← Back</button>
            <button className="px-4 py-2 rounded-md bg-brand-600 hover:bg-brand-700" onClick={submit} disabled={isPending}>Submit</button>
            {isPending && <span className="text-xs">Submitting…</span>}
            {waiting && <span className="text-xs">Waiting…</span>}
            {isSuccess && <button className="text-xs underline" onClick={onNext}>Continue →</button>}
            {error && <span className="text-xs text-red-600">{error.message}</span>}
          </div>
          {qrText && <div className="text-xs text-emerald-400 mt-2">QR detected ✓</div>}
        </div>
      </div>
    </div>
  )
}

