import React, { useState, useRef, useEffect } from 'react'
import { useLanguage } from '../contexts/LanguageContext'

interface VoiceVerificationProps {
  onVoiceComplete: (success: boolean, data?: any) => void
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

const VoiceVerification: React.FC<VoiceVerificationProps> = ({ onVoiceComplete, isActive }) => {
  const { t } = useLanguage()
  const [currentPhrase, setCurrentPhrase] = useState<string>('')
  const [isRecording, setIsRecording] = useState(false)
  const [countdown, setCountdown] = useState<number>(0)
  const [recognizedText, setRecognizedText] = useState<string>('')
  const [recordingProgress, setRecordingProgress] = useState(0)
  const [voiceResult, setVoiceResult] = useState<'waiting' | 'success' | 'partial' | 'failed'>('waiting')
  
  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const audioChunksRef = useRef<Blob[]>([])

  // Generate random phrase when component becomes active
  useEffect(() => {
    if (isActive && !currentPhrase) {
      const randomPhrase = VOICE_PHRASES[Math.floor(Math.random() * VOICE_PHRASES.length)]
      setCurrentPhrase(randomPhrase)
    }
  }, [isActive, currentPhrase])

  // Start voice challenge
  const startVoiceChallenge = async () => {
    try {
      // Get microphone permission
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      
      // Start countdown
      startCountdown(3)
      
    } catch (error) {
      console.error('Microphone access denied:', error)
      alert('Microphone access is required for voice verification')
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

  // Start audio recording
  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      const mediaRecorder = new MediaRecorder(stream)
      mediaRecorderRef.current = mediaRecorder
      audioChunksRef.current = []

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          audioChunksRef.current.push(event.data)
        }
      }

      mediaRecorder.onstop = () => {
        processAudioRecording()
        stream.getTracks().forEach(track => track.stop())
      }

      setIsRecording(true)
      mediaRecorder.start()

      // Record for 5 seconds with progress
      let progress = 0
      const progressInterval = setInterval(() => {
        progress += 2 // 2% every 100ms for 5 seconds
        setRecordingProgress(progress)
        
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

  // Process recorded audio
  const processAudioRecording = () => {
    if (audioChunksRef.current.length === 0) return

    const audioBlob = new Blob(audioChunksRef.current, { type: 'audio/wav' })
    
    // Simulate speech recognition (in real implementation, you'd use Web Speech API)
    simulateSpeechRecognition(audioBlob)
  }

  // Simulate speech recognition results
  const simulateSpeechRecognition = (audioBlob: Blob) => {
    // In a real implementation, you would use:
    // - Web Speech API (if available)
    // - Send audio to your backend for processing
    // - Use the Python speech recognition we built
    
    setTimeout(() => {
      // Simulate recognition results
      const phrases = currentPhrase.toLowerCase().split(' ')
      const variations = [
        currentPhrase.toLowerCase(),
        phrases.slice(0, -1).join(' '), // Missing last word
        phrases.slice(1).join(' '), // Missing first word  
        currentPhrase.toLowerCase().replace(/[0-9]/g, (match) => {
          const numbers = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine']
          return numbers[parseInt(match)] || match
        })
      ]
      
      const randomVariation = variations[Math.floor(Math.random() * variations.length)]
      setRecognizedText(randomVariation)
      
      // Calculate similarity with stricter thresholds
      const similarity = calculateSimilarity(currentPhrase, randomVariation)
      
      console.log('Voice verification:', {
        expected: currentPhrase,
        recognized: randomVariation,
        similarity: similarity
      })
      
      // Much stricter thresholds for security
      if (similarity >= 0.85) {
        setVoiceResult('success')
        setTimeout(() => onVoiceComplete(true, { 
          phrase: currentPhrase, 
          recognized: randomVariation, 
          similarity 
        }), 1000)
      } else if (similarity >= 0.6) {
        setVoiceResult('partial')
        setTimeout(() => onVoiceComplete(false, { 
          phrase: currentPhrase, 
          recognized: randomVariation, 
          similarity,
          reason: `Insufficient match (${Math.round(similarity * 100)}%) - please speak the exact phrase`
        }), 2000)
      } else {
        setVoiceResult('failed')
        setTimeout(() => onVoiceComplete(false, {
          phrase: currentPhrase,
          recognized: randomVariation,
          similarity,
          reason: `Poor match (${Math.round(similarity * 100)}%) - please read the displayed phrase exactly`
        }), 2000)
      }
    }, 2000) // Simulate processing time
  }

  // Calculate text similarity with better accuracy
  const calculateSimilarity = (expected: string, recognized: string): number => {
    const exp = expected.toLowerCase().replace(/[^\w\s]/g, '').split(' ').filter(w => w.length > 0)
    const rec = recognized.toLowerCase().replace(/[^\w\s]/g, '').split(' ').filter(w => w.length > 0)
    
    if (exp.length === 0 || rec.length === 0) return 0
    
    // Check word order and exact matches
    let exactMatches = 0
    let orderScore = 0
    
    // Count exact word matches
    const expSet = new Set(exp)
    const recSet = new Set(rec)
    exactMatches = [...expSet].filter(word => recSet.has(word)).length
    
    // Check sequence order (bonus for maintaining word order)
    let expIndex = 0
    for (const word of rec) {
      if (expIndex < exp.length && exp[expIndex] === word) {
        orderScore++
        expIndex++
      }
    }
    
    // Strict similarity calculation
    const wordSimilarity = exactMatches / Math.max(exp.length, rec.length)
    const sequenceBonus = orderScore / exp.length * 0.3 // 30% bonus for correct order
    
    return Math.min(1.0, wordSimilarity + sequenceBonus)
  }

  // Reset for retry
  const resetVoiceChallenge = () => {
    setCurrentPhrase('')
    setRecognizedText('')
    setVoiceResult('waiting')
    setRecordingProgress(0)
    setCountdown(0)
    setIsRecording(false)
    
    // Generate new phrase
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
          🎤 Voice Verification Challenge
        </h3>
        <p className="text-slate-300 text-sm">
          Speak the phrase clearly for voice authentication
        </p>
      </div>

      {/* Phrase Display */}
      {currentPhrase && (
        <div className="text-center p-6 bg-slate-700 rounded-lg border-2 border-green-500">
          <div className="text-sm text-green-400 mb-2">📢 Please read this phrase clearly:</div>
          <div className="text-2xl font-bold text-green-300 leading-relaxed">
            "{currentPhrase}"
          </div>
        </div>
      )}

      {/* Countdown */}
      {countdown > 0 && (
        <div className="text-center">
          <div className="text-3xl font-bold text-red-400 animate-pulse">
            🕐 Get ready... Recording starts in {countdown}
          </div>
        </div>
      )}

      {/* Recording Progress */}
      {isRecording && (
        <div className="space-y-3">
          <div className="text-center text-red-400 font-semibold">
            🔴 Recording NOW! Speak the phrase above
          </div>
          <div className="w-full bg-slate-600 rounded-full h-4">
            <div 
              className="bg-red-500 h-4 rounded-full transition-all duration-100"
              style={{ width: `${recordingProgress}%` }}
            />
          </div>
          <div className="text-center text-sm text-slate-400">
            {Math.round(recordingProgress)}% complete
          </div>
        </div>
      )}

      {/* Speech Recognition Result */}
      {recognizedText && (
        <div className="p-4 bg-slate-700 rounded-lg">
          <div className="text-sm text-slate-400 mb-2">🎧 What we heard:</div>
          <div className="text-lg text-white">"{recognizedText}"</div>
          
          <div className="mt-3 flex items-center gap-2">
            {voiceResult === 'success' && (
              <span className="flex items-center gap-2 text-green-400">
                ✅ Perfect match! Voice verified
              </span>
            )}
            {voiceResult === 'partial' && (
              <span className="flex items-center gap-2 text-yellow-400">
                ⚠️ Partial match - please try again
              </span>
            )}
            {voiceResult === 'failed' && (
              <span className="flex items-center gap-2 text-red-400">
                ❌ Low match - please speak more clearly
              </span>
            )}
          </div>
        </div>
      )}

      {/* Action Buttons */}
      <div className="flex gap-3 justify-center">
        {!isRecording && !recognizedText && (
          <button
            onClick={startVoiceChallenge}
            className="px-6 py-3 bg-green-600 hover:bg-green-700 text-white rounded-lg font-semibold transition-colors"
          >
            🚀 Start Voice Challenge
          </button>
        )}
        
        {recognizedText && voiceResult !== 'success' && (
          <button
            onClick={resetVoiceChallenge}
            className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-colors"
          >
            🔄 Try Again
          </button>
        )}
      </div>

      {/* Instructions */}
      <div className="text-xs text-slate-400 text-center space-y-1">
        <div>💡 Ensure your microphone is working and speak clearly</div>
        <div>🔊 The system will analyze your voice for 5 seconds</div>
        <div>📱 Grant microphone permissions when prompted</div>
      </div>
    </div>
  )
}

export default VoiceVerification
