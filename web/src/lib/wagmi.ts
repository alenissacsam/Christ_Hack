import { getDefaultConfig } from "@rainbow-me/rainbowkit"
import { mainnet, sepolia } from "wagmi/chains"

const DEFAULT_CHAIN_ID = Number(import.meta.env.VITE_DEFAULT_CHAIN_ID || 11155111) // sepolia

export const config = getDefaultConfig({
  appName: "Christ Hack Identity",
  projectId: "your-walletconnect-project-id", // Get from https://cloud.walletconnect.com
  chains: [sepolia, mainnet],
  ssr: false,
})
