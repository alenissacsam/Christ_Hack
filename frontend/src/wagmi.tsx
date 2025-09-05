import { http, createConfig, WagmiProvider } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { injected, walletConnect } from 'wagmi/connectors'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactNode, useMemo } from 'react'

const sepoliaRpc = import.meta.env.VITE_RPC_SEPOLIA || ''

export const wagmiConfig = createConfig({
  chains: [sepolia],
  transports: {
    [sepolia.id]: http(sepoliaRpc || undefined),
  },
  connectors: [
    injected(),
    ...(import.meta.env.VITE_WALLETCONNECT_PROJECT_ID
      ? [walletConnect({ projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID })]
      : []),
  ],
  ssr: false,
})

const queryClient = new QueryClient()

export function Providers({ children }: { children: ReactNode }) {
  const config = useMemo(() => wagmiConfig, [])
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </WagmiProvider>
  )
}

