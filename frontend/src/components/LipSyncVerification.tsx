import React, { useState, useRef, useEffect } from 'react'
import { useLanguage } from '../contexts/LanguageContext'
import { sha256Hex } from '../utils/hash'

interface LipSyncVerificationProps {
  onVerificationComplete: (success: boolean, data?: any) => void
  isActive: boolean
}

// Voice challenge phrases
const VOICE_PHRASES = [
  "Security verification in progress",
  "Digital identity confirmation required", 
  "Biometric authentication system active",
  "Alpha Bravo Charlie seven five two",
  "The bright ocean flows four five six",
  "Red key number thirty four code seven eight nine"
]

const LipSyncVerification: React.FC<LipSyncVerificationProps> = ({ onVerificationComplete, isActive }) => {
  const { t } = useLanguage()
  const videoRef = useRef<HTMLVideoElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  
  const [currentPhrase, setCurrentPhrase] = useState<string>('')
  const [isRecording, setIsRecording] = useState(false)
  const [countdown, setCountdown] = useState<number>(0)
  const [recognizedText, setRecognizedText] = useState<string>('')
  const [recordingProgress, setRecordingProgress] = useState(0)
  const [verificationResult, setVerificationResult] = useState<'waiting' | 'success' | 'partial' | 'failed'>('waiting')
  const [videoHash, setVideoHash] = useState<string>('')
  const [audioHash, setAudioHash] = useState<string>('')
  
  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const videoChunksRef = useRef<Blob[]>([])
  const audioChunksRef = useRef<Blob[]>([])
  const streamRef = useRef<MediaStream | null>(null)

  // Generate random phrase when component becomes active
  useEffect(() => {
    if (isActive && !currentPhrase) {
      const randomPhrase = VOICE_PHRASES[Math.floor(Math.random() * VOICE_PHRASES.length)]
      setCurrentPhrase(randomPhrase)
    }
  }, [isActive, currentPhrase])

  // Start camera and microphone
  const startCapture = async () => {
    try {
      // Get both video and audio streams
      const stream = await navigator.mediaDevices.getUserMedia({ 
        video: { width: 640, height: 480 },
        audio: { 
          echoCancellation: true,
          noiseSuppression: true,
          sampleRate: 44100
        }
      })
      
      streamRef.current = stream
      
      if (videoRef.current) {
        videoRef.current.srcObject = stream
        await videoRef.current.play()
      }
      
      // Start countdown before recording
      startCountdown(3)
      
    } catch (error) {
      console.error('Media access denied:', error)
      alert('Camera and microphone access is required for biometric verification')
    }
  }

  // Countdown before recording
  const startCountdown = (seconds: number) => {
    setCountdown(seconds)
    
    const countdownInterval = setInterval(() => {
      setCountdown(prev => {
        if (prev <= 1) {
          clearInterval(countdownInterval)
          startRecording()
          return 0
        }
        return prev - 1
      })
    }, 1000)
  }

  // Start simultaneous video + audio recording
  const startRecording = async () => {
    if (!streamRef.current) return
    
    try {
      // Create media recorder for both video and audio
      const mediaRecorder = new MediaRecorder(streamRef.current, {
        mimeType: 'video/webm;codecs=vp8,opus'
      })
      
      mediaRecorderRef.current = mediaRecorder
      videoChunksRef.current = []
      audioChunksRef.current = []

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          videoChunksRef.current.push(event.data)
        }
      }

      mediaRecorder.onstop = () => {
        processRecording()
        if (streamRef.current) {
          streamRef.current.getTracks().forEach(track => track.stop())
        }
      }

      setIsRecording(true)
      mediaRecorder.start(100) // Record in 100ms chunks

      // Record for 5 seconds with progress
      let progress = 0
      const progressInterval = setInterval(() => {
        progress += 2 // 2% every 100ms for 5 seconds
        setRecordingProgress(progress)
        
        // Capture video frames during recording for lip-sync analysis
        if (progress % 20 === 0) { // Every 1 second
          captureFrame()
        }
        
        if (progress >= 100) {
          clearInterval(progressInterval)
          mediaRecorder.stop()
          setIsRecording(false)
        }
      }, 100)

    } catch (error) {
      console.error('Recording failed:', error)
      setIsRecording(false)
    }
  }

  // Capture individual video frames for analysis
  const captureFrame = () => {
    const video = videoRef.current
    const canvas = canvasRef.current
    if (!video || !canvas) return

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    canvas.width = video.videoWidth
    canvas.height = video.videoHeight
    ctx.drawImage(video, 0, 0)
  }

  // Process recorded video and audio
  const processRecording = async () => {
    if (videoChunksRef.current.length === 0) return

    const videoBlob = new Blob(videoChunksRef.current, { type: 'video/webm' })
    
    // Generate hashes for blockchain verification
    const videoBuffer = await videoBlob.arrayBuffer()
    const vHash = await sha256Hex(videoBuffer)
    setVideoHash(vHash)
    
    // Extract audio from video for speech recognition
    extractAudioAndAnalyze(videoBlob)
  }

  // Extract audio and perform speech recognition
  const extractAudioAndAnalyze = async (videoBlob: Blob) => {
    // Create audio context for analysis
    const audioContext = new AudioContext()
    
    try {
      // For real implementation, you'd extract audio from video blob
      // For now, simulate speech recognition
      setTimeout(() => {
        simulateSpeechRecognition(videoBlob)
      }, 1000)
    } catch (error) {
      console.error('Audio analysis failed:', error)
      simulateSpeechRecognition(videoBlob)
    }
  }

  // Simulate speech recognition (replace with real implementation)
  const simulateSpeechRecognition = async (videoBlob: Blob) => {
    // In production, you would:
    // 1. Extract audio track from video
    // 2. Send to speech recognition service
    // 3. Perform lip-sync analysis comparing video frames with audio
    
    setTimeout(() => {
      // For demo, sometimes return correct, sometimes incorrect
      const shouldBeCorrect = Math.random() > 0.3 // 70% chance of correct recognition
      
      if (shouldBeCorrect) {
        setRecognizedText(currentPhrase.toLowerCase())
      } else {
        // Generate wrong text
        const wrongPhrases = [
          "something completely different",
          currentPhrase.split(' ').reverse().join(' '), // Reversed order
          currentPhrase.split(' ').slice(0, -2).join(' '), // Missing words
        ]
        setRecognizedText(wrongPhrases[Math.floor(Math.random() * wrongPhrases.length)])
      }
      
      // Analyze results
      analyzeVerification()
    }, 2000)
  }

  // Analyze both speech and lip-sync
  const analyzeVerification = () => {
    const similarity = calculateSimilarity(currentPhrase, recognizedText)
    
    // In production, you'd also check:
    // - Lip movement matches audio timing
    // - Facial features are consistent
    // - No signs of deepfake or video manipulation
    const lipSyncScore = simulateLipSyncAnalysis()
    
    console.log('Comprehensive verification:', {
      expected: currentPhrase,
      recognized: recognizedText,
      speechSimilarity: similarity,
      lipSyncScore: lipSyncScore,
      videoHash: videoHash
    })
    
    // Combined score (speech + lip-sync)
    const combinedScore = (similarity * 0.7) + (lipSyncScore * 0.3)
    
    if (combinedScore >= 0.85 && similarity >= 0.8 && lipSyncScore >= 0.7) {
      setVerificationResult('success')
      setTimeout(() => onVerificationComplete(true, {
        phrase: currentPhrase,
        recognized: recognizedText,
        speechSimilarity: similarity,
        lipSyncScore: lipSyncScore,
        combinedScore: combinedScore,
        videoHash: videoHash,
        audioHash: audioHash,
        timestamp: Date.now()
      }), 1000)
    } else if (combinedScore >= 0.6) {
      setVerificationResult('partial')
      setTimeout(() => onVerificationComplete(false, {
        phrase: currentPhrase,
        recognized: recognizedText,
        speechSimilarity: similarity,
        lipSyncScore: lipSyncScore,
        combinedScore: combinedScore,
        reason: `Verification incomplete. Speech: ${Math.round(similarity * 100)}%, Lip-sync: ${Math.round(lipSyncScore * 100)}%`
      }), 2000)
    } else {
      setVerificationResult('failed')
      setTimeout(() => onVerificationComplete(false, {
        phrase: currentPhrase,
        recognized: recognizedText,
        speechSimilarity: similarity,
        lipSyncScore: lipSyncScore,
        combinedScore: combinedScore,
        reason: `Verification failed. Please ensure you speak the exact phrase while looking at the camera.`
      }), 2000)
    }
  }

  // Simulate lip-sync analysis
  const simulateLipSyncAnalysis = (): number => {
    // In production, this would analyze video frames to detect:
    // - Mouth movement timing
    // - Lip shape correlation with phonemes
    // - Face presence and consistency
    return Math.random() * 0.4 + 0.6 // Random score between 0.6-1.0
  }

  // Calculate speech similarity (same as before but more strict)
  const calculateSimilarity = (expected: string, recognized: string): number => {
    const exp = expected.toLowerCase().replace(/[^\w\s]/g, '').split(' ').filter(w => w.length > 0)
    const rec = recognized.toLowerCase().replace(/[^\w\s]/g, '').split(' ').filter(w => w.length > 0)
    
    if (exp.length === 0 || rec.length === 0) return 0
    
    let exactMatches = 0
    let orderScore = 0
    
    const expSet = new Set(exp)
    const recSet = new Set(rec)
    exactMatches = [...expSet].filter(word => recSet.has(word)).length
    
    let expIndex = 0
    for (const word of rec) {
      if (expIndex < exp.length && exp[expIndex] === word) {
        orderScore++
        expIndex++
      }
    }
    
    const wordSimilarity = exactMatches / Math.max(exp.length, rec.length)
    const sequenceBonus = orderScore / exp.length * 0.3
    
    return Math.min(1.0, wordSimilarity + sequenceBonus)
  }

  // Reset for retry
  const resetVerification = () => {
    setCurrentPhrase('')
    setRecognizedText('')
    setVerificationResult('waiting')
    setRecordingProgress(0)
    setCountdown(0)
    setIsRecording(false)
    setVideoHash('')
    setAudioHash('')
    
    setTimeout(() => {
      const randomPhrase = VOICE_PHRASES[Math.floor(Math.random() * VOICE_PHRASES.length)]
      setCurrentPhrase(randomPhrase)
    }, 500)
  }

  if (!isActive) return null

  return (
    <div className="space-y-6 p-6 bg-slate-800/50 rounded-lg border border-slate-600">
      <div className="text-center">
        <h3 className="text-xl font-semibold text-white mb-2">
          🎥🎤 Biometric Verification Challenge
        </h3>
        <p className="text-slate-300 text-sm">
          Simultaneous video recording with voice verification and lip-sync analysis
        </p>
      </div>

      {/* Video Display */}
      <div className="flex justify-center">
        <div className="relative">
          <video 
            ref={videoRef} 
            className="w-80 h-60 rounded-lg bg-black border-2 border-slate-600" 
            muted 
            playsInline 
          />
          <canvas ref={canvasRef} className="hidden" />
          {isRecording && (
            <div className="absolute top-2 right-2 flex items-center gap-2 bg-red-600 px-2 py-1 rounded-full text-white text-xs">
              <div className="w-2 h-2 bg-white rounded-full animate-pulse"></div>
              REC
            </div>
          )}
        </div>
      </div>

      {/* Phrase Display */}
      {currentPhrase && (
        <div className="text-center p-6 bg-slate-700 rounded-lg border-2 border-green-500">
          <div className="text-sm text-green-400 mb-2">📢 Read this phrase clearly while looking at the camera:</div>
          <div className="text-2xl font-bold text-green-300 leading-relaxed">
            "{currentPhrase}"
          </div>
        </div>
      )}

      {/* Countdown */}
      {countdown > 0 && (
        <div className="text-center">
          <div className="text-3xl font-bold text-red-400 animate-pulse">
            🕐 Recording starts in {countdown}
          </div>
          <div className="text-sm text-slate-400 mt-2">
            Position your face clearly in the camera frame
          </div>
        </div>
      )}

      {/* Recording Progress */}
      {isRecording && (
        <div className="space-y-3">
          <div className="text-center text-red-400 font-semibold">
            🔴 RECORDING! Speak the phrase above clearly
          </div>
          <div className="w-full bg-slate-600 rounded-full h-4">
            <div 
              className="bg-red-500 h-4 rounded-full transition-all duration-100"
              style={{ width: `${recordingProgress}%` }}
            />
          </div>
          <div className="text-center text-sm text-slate-400">
            {Math.round(recordingProgress)}% complete • Keep your face visible
          </div>
        </div>
      )}

      {/* Analysis Results */}
      {recognizedText && (
        <div className="space-y-4">
          <div className="p-4 bg-slate-700 rounded-lg">
            <div className="text-sm text-slate-400 mb-2">🎧 Speech Recognition:</div>
            <div className="text-lg text-white">"{recognizedText}"</div>
          </div>
          
          <div className="p-4 bg-slate-700 rounded-lg">
            <div className="text-sm text-slate-400 mb-2">📊 Verification Status:</div>
            <div className="flex items-center gap-2">
              {verificationResult === 'success' && (
                <span className="flex items-center gap-2 text-green-400">
                  ✅ Biometric verification successful!
                </span>
              )}
              {verificationResult === 'partial' && (
                <span className="flex items-center gap-2 text-yellow-400">
                  ⚠️ Partial verification - please try again
                </span>
              )}
              {verificationResult === 'failed' && (
                <span className="flex items-center gap-2 text-red-400">
                  ❌ Verification failed - speak clearly and maintain eye contact
                </span>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Action Buttons */}
      <div className="flex gap-3 justify-center">
        {!isRecording && !recognizedText && (
          <button
            onClick={startCapture}
            className="px-6 py-3 bg-green-600 hover:bg-green-700 text-white rounded-lg font-semibold transition-colors"
          >
            🚀 Start Biometric Verification
          </button>
        )}
        
        {recognizedText && verificationResult !== 'success' && (
          <button
            onClick={resetVerification}
            className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-colors"
          >
            🔄 Try Again
          </button>
        )}
      </div>

      {/* Enhanced Instructions */}
      <div className="text-xs text-slate-400 text-center space-y-1">
        <div>💡 Look directly at the camera and speak the phrase clearly</div>
        <div>🎥 Your video will be recorded for lip-sync verification</div>
        <div>🔒 All biometric data is hashed for secure blockchain storage</div>
        <div>📱 Grant camera and microphone permissions when prompted</div>
      </div>
    </div>
  )
}

export default LipSyncVerification
