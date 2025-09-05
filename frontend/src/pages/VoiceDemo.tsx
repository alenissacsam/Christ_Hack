import { useState } from 'react'
import VoiceVerification from '../components/VoiceVerification'
import { useLanguage } from '../contexts/LanguageContext'

export default function VoiceDemo() {
  const { t } = useLanguage()
  const [isActive, setIsActive] = useState(true)
  const [results, setResults] = useState<any[]>([])

  function handleVoiceComplete(success: boolean, data?: any) {
    const result = {
      timestamp: new Date().toLocaleTimeString(),
      success,
      ...data
    }
    setResults(prev => [result, ...prev])
    
    // Reset for next test after delay
    setTimeout(() => {
      setIsActive(false)
      setTimeout(() => setIsActive(true), 500)
    }, 3000)
  }

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Header */}
      <section className="relative overflow-hidden rounded-xl">
        <div className="h-24 bg-gradient-to-r from-blue-600 to-purple-600 grid content-center p-4 text-white">
          <div className="text-xl font-semibold">🎤 Voice Verification Demo</div>
          <div className="text-sm opacity-90">Test the voice challenge system with speech recognition</div>
        </div>
      </section>

      {/* Voice Challenge */}
      <VoiceVerification 
        isActive={isActive}
        onVoiceComplete={handleVoiceComplete}
      />

      {/* Controls */}
      <div className="glass p-4 rounded-lg border border-slate-200">
        <div className="flex gap-3 items-center">
          <button
            onClick={() => {
              setIsActive(false)
              setTimeout(() => setIsActive(true), 100)
            }}
            className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-colors"
          >
            🔄 Reset Challenge
          </button>
          <button
            onClick={() => setResults([])}
            className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg font-semibold transition-colors"
          >
            🗑️ Clear Results
          </button>
          <div className="ml-auto text-sm text-slate-400">
            Status: {isActive ? '✅ Active' : '⏸️ Inactive'}
          </div>
        </div>
      </div>

      {/* Results History */}
      {results.length > 0 && (
        <div className="glass p-4 rounded-lg border border-slate-200">
          <h3 className="text-lg font-semibold mb-4">📊 Verification Results</h3>
          <div className="space-y-3">
            {results.map((result, index) => (
              <div 
                key={index}
                className={`p-3 rounded-lg border ${
                  result.success 
                    ? 'bg-green-500/10 border-green-500/30' 
                    : 'bg-red-500/10 border-red-500/30'
                }`}
              >
                <div className="flex items-start justify-between">
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <span className={result.success ? 'text-green-400' : 'text-red-400'}>
                        {result.success ? '✅' : '❌'}
                      </span>
                      <span className="font-medium">
                        {result.success ? 'Voice Verified' : 'Verification Failed'}
                      </span>
                      <span className="text-xs text-slate-400">{result.timestamp}</span>
                    </div>
                    
                    {result.phrase && (
                      <div className="text-sm">
                        <span className="text-slate-400">Expected:</span> "{result.phrase}"
                      </div>
                    )}
                    
                    {result.recognized && (
                      <div className="text-sm">
                        <span className="text-slate-400">Recognized:</span> "{result.recognized}"
                      </div>
                    )}
                    
                    {result.similarity !== undefined && (
                      <div className="text-sm">
                        <span className="text-slate-400">Similarity:</span> {Math.round(result.similarity * 100)}%
                      </div>
                    )}
                    
                    {result.reason && (
                      <div className="text-sm text-red-400">
                        <span className="text-slate-400">Reason:</span> {result.reason}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Instructions */}
      <div className="glass p-4 rounded-lg border border-slate-200">
        <h3 className="text-lg font-semibold mb-3">📋 How to Use</h3>
        <div className="space-y-2 text-sm text-slate-300">
          <div>1. 📢 <strong>Read the phrase</strong> - A random security phrase will be displayed clearly</div>
          <div>2. 🎙️ <strong>Grant microphone permission</strong> - Allow browser access to your microphone</div>
          <div>3. 🗣️ <strong>Speak clearly</strong> - Read the phrase aloud when recording starts</div>
          <div>4. 👂 <strong>See recognition</strong> - View what the system heard in real-time</div>
          <div>5. ✅ <strong>Get feedback</strong> - Receive instant verification results</div>
        </div>
        
        <div className="mt-4 p-3 bg-blue-500/10 rounded-lg border border-blue-500/30">
          <div className="text-sm text-blue-300">
            <strong>💡 Pro tip:</strong> For best results, speak at normal volume in a quiet environment. 
            The system uses speech recognition to compare your spoken words with the displayed phrase.
          </div>
        </div>
        
        <div className="mt-3 p-3 bg-yellow-500/10 rounded-lg border border-yellow-500/30">
          <div className="text-sm text-yellow-300">
            <strong>⚠️ Note:</strong> This demo uses simulated speech recognition. 
            In production, you would integrate with Web Speech API or server-side speech processing.
          </div>
        </div>
      </div>
    </div>
  )
}
