import { create } from 'zustand'
import { persist } from 'zustand/middleware'

export const CONTRACT_KEYS = [
  'UserIdentityRegistry',
  'CertificateManager',
  'OrganizationRegistry',
  'GlobalCredentialAnchor',
  'CrossChainManager',
  'RecognitionManager',
  'VerificationLogger',
] as const

export type ContractKey = typeof CONTRACT_KEYS[number]

type Address = `0x${string}`

interface ConfigState {
  chainId: number
  addresses: Partial<Record<ContractKey, Address>>
  setAddress: (key: ContractKey, addr: string) => void
  setChainId: (id: number) => void
}

export const useConfigStore = create<ConfigState>()(
  persist(
    (set) => ({
      chainId: 11155111, // sepolia default
      addresses: {
        UserIdentityRegistry: '0x9754F529b2c4Acd30f3830d4198aE210667ed411' as Address,
        CertificateManager: '0x131ec26d5Cb482eE8155e2df7bB244c2586AADC6' as Address,
        OrganizationRegistry: '0xBCDa4D0464509228BBD983864DfE12D2ddCA3E04' as Address,
        GlobalCredentialAnchor: '0x4688ad554cdd5dD5be4F7e0aA62c87122E06ef7c' as Address,
        CrossChainManager: '0xA225572131580227aE68e784251C28e7371ABA83' as Address,
        RecognitionManager: '0x04FC417B7729935bee1eD410B7a0E5EfB1A0928f' as Address,
        VerificationLogger: '0x2F257E2f78FDF76Fc156E16b17E62e0357a5Cec1' as Address,
      },
      setAddress: (key, addr) =>
        set((s) => ({ addresses: { ...s.addresses, [key]: addr as Address } })),
      setChainId: (id) => set({ chainId: id }),
    }),
    { name: 'identity-dapp-config' }
  )
)

