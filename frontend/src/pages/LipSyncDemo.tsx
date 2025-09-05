import { useState } from 'react'
import LipSyncVerification from '../components/LipSyncVerification'
import { useLanguage } from '../contexts/LanguageContext'

export default function LipSyncDemo() {
  const { t } = useLanguage()
  const [isActive, setIsActive] = useState(true)
  const [results, setResults] = useState<any[]>([])

  function handleVerificationComplete(success: boolean, data?: any) {
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
    }, 4000)
  }

  return (
    <div className="max-w-6xl mx-auto space-y-6">
      {/* Header */}
      <section className="relative overflow-hidden rounded-xl">
        <div className="h-32 bg-gradient-to-r from-purple-600 via-blue-600 to-green-600 grid content-center p-4 text-white">
          <div className="text-2xl font-semibold">🎥🎤 Advanced Lip-Sync Verification Demo</div>
          <div className="text-sm opacity-90">
            Simultaneous video + voice recording with biometric analysis and blockchain integration
          </div>
        </div>
      </section>

      {/* Main Verification Component */}
      <LipSyncVerification 
        isActive={isActive}
        onVerificationComplete={handleVerificationComplete}
      />

      {/* Controls */}
      <div className="glass p-4 rounded-lg border border-slate-200">
        <div className="flex gap-3 items-center flex-wrap">
          <button
            onClick={() => {
              setIsActive(false)
              setTimeout(() => setIsActive(true), 100)
            }}
            className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-colors"
          >
            🔄 Reset Verification
          </button>
          <button
            onClick={() => setResults([])}
            className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg font-semibold transition-colors"
          >
            🗑️ Clear Results
          </button>
          <div className="ml-auto text-sm text-slate-400">
            Status: {isActive ? '✅ Active' : '⏸️ Inactive'} | Results: {results.length}
          </div>
        </div>
      </div>

      {/* Verification Results */}
      {results.length > 0 && (
        <div className="glass p-6 rounded-lg border border-slate-200">
          <h3 className="text-xl font-semibold mb-4 flex items-center gap-2">
            📊 Biometric Verification Results
            <span className="text-sm font-normal text-slate-400">
              ({results.filter(r => r.success).length}/{results.length} successful)
            </span>
          </h3>
          
          <div className="grid gap-4">
            {results.map((result, index) => (
              <div 
                key={index}
                className={`p-4 rounded-lg border-2 ${
                  result.success 
                    ? 'bg-green-500/10 border-green-500/30' 
                    : 'bg-red-500/10 border-red-500/30'
                }`}
              >
                <div className="flex items-start justify-between mb-3">
                  <div className="flex items-center gap-3">
                    <span className={`text-2xl ${result.success ? 'text-green-400' : 'text-red-400'}`}>
                      {result.success ? '✅' : '❌'}
                    </span>
                    <div>
                      <div className="font-semibold">
                        {result.success ? 'Biometric Verification Successful' : 'Verification Failed'}
                      </div>
                      <div className="text-xs text-slate-400">{result.timestamp}</div>
                    </div>
                  </div>
                  
                  {result.combinedScore !== undefined && (
                    <div className="text-right">
                      <div className="text-lg font-bold">
                        {Math.round(result.combinedScore * 100)}%
                      </div>
                      <div className="text-xs text-slate-400">Combined Score</div>
                    </div>
                  )}
                </div>
                
                {/* Detailed Metrics */}
                <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-4 mb-3">
                  {result.speechSimilarity !== undefined && (
                    <div className="bg-slate-700/50 p-3 rounded-lg">
                      <div className="text-sm text-slate-400 mb-1">🗣️ Speech Accuracy</div>
                      <div className="text-lg font-semibold">
                        {Math.round(result.speechSimilarity * 100)}%
                      </div>
                      <div className={`text-xs ${result.speechSimilarity >= 0.8 ? 'text-green-400' : result.speechSimilarity >= 0.6 ? 'text-yellow-400' : 'text-red-400'}`}>
                        {result.speechSimilarity >= 0.8 ? 'Excellent' : result.speechSimilarity >= 0.6 ? 'Good' : 'Poor'}
                      </div>
                    </div>
                  )}
                  
                  {result.lipSyncScore !== undefined && (
                    <div className="bg-slate-700/50 p-3 rounded-lg">
                      <div className="text-sm text-slate-400 mb-1">👄 Lip-Sync Score</div>
                      <div className="text-lg font-semibold">
                        {Math.round(result.lipSyncScore * 100)}%
                      </div>
                      <div className={`text-xs ${result.lipSyncScore >= 0.7 ? 'text-green-400' : result.lipSyncScore >= 0.5 ? 'text-yellow-400' : 'text-red-400'}`}>
                        {result.lipSyncScore >= 0.7 ? 'Synchronized' : result.lipSyncScore >= 0.5 ? 'Partial' : 'Poor'}
                      </div>
                    </div>
                  )}
                  
                  {result.videoHash && (
                    <div className="bg-slate-700/50 p-3 rounded-lg">
                      <div className="text-sm text-slate-400 mb-1">🎥 Video Hash</div>
                      <div className="text-xs font-mono break-all">
                        {result.videoHash.substring(0, 12)}...
                      </div>
                      <div className="text-xs text-green-400">Captured</div>
                    </div>
                  )}
                </div>
                
                {/* Speech Analysis */}
                <div className="grid md:grid-cols-2 gap-4">
                  {result.phrase && (
                    <div className="bg-slate-800/50 p-3 rounded-lg">
                      <div className="text-sm text-slate-400 mb-2">📝 Expected Phrase:</div>
                      <div className="text-sm font-mono">"{result.phrase}"</div>
                    </div>
                  )}
                  
                  {result.recognized && (
                    <div className="bg-slate-800/50 p-3 rounded-lg">
                      <div className="text-sm text-slate-400 mb-2">🎧 Recognized Speech:</div>
                      <div className="text-sm font-mono">"{result.recognized}"</div>
                    </div>
                  )}
                </div>
                
                {/* Failure Reason */}
                {result.reason && (
                  <div className="mt-3 p-3 bg-red-500/10 border border-red-500/30 rounded-lg">
                    <div className="text-sm text-red-300">
                      <strong>Reason:</strong> {result.reason}
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Technical Information */}
      <div className="grid md:grid-cols-2 gap-6">
        {/* How It Works */}
        <div className="glass p-6 rounded-lg border border-slate-200">
          <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
            ⚙️ How It Works
          </h3>
          <div className="space-y-3 text-sm text-slate-300">
            <div className="flex items-start gap-3">
              <span className="text-blue-400 font-semibold">1.</span>
              <div>
                <strong>Video + Audio Capture</strong>
                <div className="text-xs text-slate-400">Simultaneous recording of face and voice</div>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <span className="text-blue-400 font-semibold">2.</span>
              <div>
                <strong>Speech Recognition</strong>
                <div className="text-xs text-slate-400">Convert speech to text and compare with phrase</div>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <span className="text-blue-400 font-semibold">3.</span>
              <div>
                <strong>Lip-Sync Analysis</strong>
                <div className="text-xs text-slate-400">Verify mouth movements match audio timing</div>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <span className="text-blue-400 font-semibold">4.</span>
              <div>
                <strong>Biometric Scoring</strong>
                <div className="text-xs text-slate-400">Combine speech + lip-sync scores for final result</div>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <span className="text-blue-400 font-semibold">5.</span>
              <div>
                <strong>Blockchain Integration</strong>
                <div className="text-xs text-slate-400">Generate hash signatures for smart contract verification</div>
              </div>
            </div>
          </div>
        </div>

        {/* Security Features */}
        <div className="glass p-6 rounded-lg border border-slate-200">
          <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
            🔒 Security Features
          </h3>
          <div className="space-y-3 text-sm text-slate-300">
            <div className="flex items-start gap-3">
              <span className="text-green-400">✓</span>
              <div>
                <strong>Strict Similarity Thresholds</strong>
                <div className="text-xs text-slate-400">85%+ combined score required for success</div>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <span className="text-green-400">✓</span>
              <div>
                <strong>Real-time Liveness Detection</strong>
                <div className="text-xs text-slate-400">Video recording prevents static image attacks</div>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <span className="text-green-400">✓</span>
              <div>
                <strong>Hash-based Verification</strong>
                <div className="text-xs text-slate-400">SHA-256 signatures for tamper-proof verification</div>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <span className="text-green-400">✓</span>
              <div>
                <strong>Multi-modal Authentication</strong>
                <div className="text-xs text-slate-400">Face + Voice + Lip-sync for comprehensive security</div>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <span className="text-green-400">✓</span>
              <div>
                <strong>Blockchain Immutability</strong>
                <div className="text-xs text-slate-400">Verification records stored on-chain</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Usage Instructions */}
      <div className="glass p-6 rounded-lg border border-slate-200">
        <h3 className="text-lg font-semibold mb-4">📋 Usage Instructions</h3>
        <div className="grid md:grid-cols-2 gap-6">
          <div>
            <h4 className="font-semibold mb-3 text-blue-300">For Best Results:</h4>
            <div className="space-y-2 text-sm text-slate-300">
              <div>🎯 Look directly at the camera</div>
              <div>🗣️ Speak clearly at normal volume</div>
              <div>💡 Ensure good lighting on your face</div>
              <div>🔇 Use a quiet environment</div>
              <div>📱 Grant camera and microphone permissions</div>
            </div>
          </div>
          <div>
            <h4 className="font-semibold mb-3 text-yellow-300">Scoring Criteria:</h4>
            <div className="space-y-2 text-sm text-slate-300">
              <div>🎤 Speech Accuracy: 80%+ required</div>
              <div>👄 Lip-Sync Score: 70%+ required</div>
              <div>🎯 Combined Score: 85%+ for success</div>
              <div>🔍 Word order and pronunciation matter</div>
              <div>⚡ Real-time analysis during recording</div>
            </div>
          </div>
        </div>
        
        <div className="mt-4 p-4 bg-blue-500/10 border border-blue-500/30 rounded-lg">
          <div className="text-sm text-blue-300">
            <strong>💡 Technical Note:</strong> This demo uses simulated speech recognition and lip-sync analysis. 
            In production, you would integrate with advanced speech recognition APIs (like Google Speech-to-Text, Azure Speech) 
            and computer vision libraries for accurate lip movement analysis.
          </div>
        </div>
      </div>
    </div>
  )
}
