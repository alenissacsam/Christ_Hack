import { useAccount, useReadContract } from 'wagmi'
import { abis } from '../contracts/abis'
import { useConfigStore } from '../store/config'

// DEFAULT_ADMIN_ROLE in OpenZeppelin AccessControl is 0x00...00 (32 bytes)
const DEFAULT_ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000'

export function useIsAdmin() {
  const { address } = useAccount()
  const contract = useConfigStore((s) => s.addresses['UserIdentityRegistry'])
  const { data, isLoading } = useReadContract({
    address: contract,
    abi: abis.UserIdentityRegistry as any,
    functionName: 'hasRole',
    args: address ? [DEFAULT_ADMIN_ROLE, address] : undefined,
    query: { enabled: !!contract && !!address },
  })
  return { isAdmin: Boolean(data), isLoading }
}
