import { ConnectButton } from "@rainbow-me/rainbowkit"
import { useAccount } from "wagmi"

export default function App() {
  const { isConnected } = useAccount()

  return (
    <div className="min-h-screen relative overflow-hidden">
      {/* Floating Orbs */}
      <div className="floating-orb orb-1"></div>
      <div className="floating-orb orb-2"></div>
      <div className="floating-orb orb-3"></div>
      
      {/* Hero Section */}
      <div className="relative z-10">
        <div className="container mx-auto px-4 py-16">
          <div className="text-center">
            <h1 className="text-6xl md:text-8xl font-black gradient-text mb-8 animate-pulse">
              CHRIST HACK
            </h1>
            <h2 className="text-4xl md:text-6xl font-bold gradient-text mb-6">
              IDENTITY
            </h2>
            <p className="text-2xl text-white/90 max-w-3xl mx-auto mb-12 font-medium">
              🚀 Next-gen blockchain identity with biometric verification 🔥
            </p>
            
            {/* Feature Tags */}
            <div className="flex flex-wrap justify-center gap-4 mb-12">
              <div className="glass px-6 py-3 rounded-full neon-border">
                <span className="text-pink-300 text-lg font-bold">🛡️ SECURE</span>
              </div>
              <div className="glass px-6 py-3 rounded-full neon-border">
                <span className="text-cyan-300 text-lg font-bold">⚡ LIGHTNING FAST</span>
              </div>
              <div className="glass px-6 py-3 rounded-full neon-border">
                <span className="text-green-300 text-lg font-bold">🌐 DECENTRALIZED</span>
              </div>
              <div className="glass px-6 py-3 rounded-full neon-border">
                <span className="text-yellow-300 text-lg font-bold">🔥 NEXT-GEN</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="relative z-10 container mx-auto px-4 py-12">
        <div className="space-y-12">
          {/* Wallet Connection */}
          <div className="card max-w-2xl mx-auto text-center">
            <div className="mb-8">
              <h3 className="text-3xl font-bold gradient-text mb-4">
                Connect Your Wallet
              </h3>
              <p className="text-xl text-white/80 mb-6">
                Choose your favorite wallet to get started! 🚀
              </p>
            </div>
            
            <div className="flex justify-center">
              <div className="transform hover:scale-105 transition-all duration-300">
                <ConnectButton />
              </div>
            </div>
          </div>

          {/* Connected Dashboard */}
          {isConnected && (
            <div className="space-y-8">
              <div className="card max-w-4xl mx-auto">
                <div className="text-center mb-8">
                  <h2 className="text-4xl font-bold gradient-text mb-4">
                    🎉 WELCOME TO YOUR IDENTITY HUB! 🎉
                  </h2>
                  <p className="text-xl text-white/80">
                    Your blockchain identity platform is ready to rock! 🤘
                  </p>
                </div>
                
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  <div className="glass p-6 rounded-xl text-center hover:scale-105 transition-all duration-300">
                    <div className="text-4xl mb-4">🔐</div>
                    <h3 className="text-xl font-bold text-pink-300 mb-2">Biometric Vault</h3>
                    <p className="text-white/70">Secure face recognition</p>
                  </div>
                  
                  <div className="glass p-6 rounded-xl text-center hover:scale-105 transition-all duration-300">
                    <div className="text-4xl mb-4">🎓</div>
                    <h3 className="text-xl font-bold text-cyan-300 mb-2">Certificates</h3>
                    <p className="text-white/70">Digital credentials</p>
                  </div>
                  
                  <div className="glass p-6 rounded-xl text-center hover:scale-105 transition-all duration-300">
                    <div className="text-4xl mb-4">🏢</div>
                    <h3 className="text-xl font-bold text-green-300 mb-2">Organizations</h3>
                    <p className="text-white/70">Institutional management</p>
                  </div>
                </div>
              </div>
              
              {/* Action Buttons */}
              <div className="max-w-2xl mx-auto">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <button className="modern-button text-white text-lg py-4 rounded-2xl font-bold">
                    🚀 REGISTER IDENTITY
                  </button>
                  <button className="modern-button text-white text-lg py-4 rounded-2xl font-bold">
                    📋 MANAGE CERTS
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Footer */}
      <footer className="relative z-10 container mx-auto px-4 py-12 text-center">
        <div className="glass px-8 py-6 rounded-2xl max-w-md mx-auto">
          <p className="text-white/80 text-lg font-medium">
            Built with ❤️ & 🔥 using React + Blockchain
          </p>
          <div className="mt-4 text-2xl">
            🚀🔥💎🎯⚡
          </div>
        </div>
      </footer>
    </div>
  )
}
