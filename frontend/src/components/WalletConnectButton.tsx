import { useAccount, useConnect, useDisconnect } from 'wagmi'
import { useMemo } from 'react'

export default function WalletConnectButton() {
  const { address, isConnected } = useAccount()
  const { connectors, connect, status: connectStatus, error } = useConnect()
  const { disconnect } = useDisconnect()
  const injected = useMemo(() => connectors.find(c => c.id === 'injected'), [connectors])

  if (isConnected) {
    return (
      <button
        className="px-3 py-1.5 rounded-md bg-white/10 hover:bg-white/20"
        onClick={() => disconnect()}
        title={address}
      >
        {shorten(address!)} • Disconnect
      </button>
    )
  }

  return (
    <div className="flex items-center gap-2">
      {injected && (
        <button
          className="px-3 py-1.5 rounded-md bg-white/10 hover:bg-white/20"
          onClick={() => connect({ connector: injected })}
        >
          Connect Wallet
        </button>
      )}
      {!injected && (
        <span className="text-sm text-white/60">Install MetaMask or use WalletConnect (set project ID)</span>
      )}
      {connectStatus === 'pending' && <span className="text-sm">Connecting...</span>}
      {error && <span className="text-sm text-red-400">{error.message}</span>}
    </div>
  )
}

function shorten(addr: string) {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

