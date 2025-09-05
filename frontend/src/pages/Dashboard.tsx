import { useAccount, useReadContract } from 'wagmi'
import { useConfigStore } from '../store/config'
import { abis } from '../contracts/abis'
import { getCategorizedContracts } from '../lib/abiRegistry'

export default function Dashboard() {
  const { address: user } = useAccount()
  const addr = useConfigStore((s) => s.addresses['UserIdentityRegistry'])

  const { data: profile } = useReadContract({
    address: addr,
    abi: abis.UserIdentityRegistry as any,
    functionName: 'getUserProfile',
    args: user ? [user] : undefined,
    query: { enabled: !!addr && !!user },
  })

  const levels = useReadContract({
    address: addr,
    abi: abis.UserIdentityRegistry as any,
    functionName: 'getVerificationLevels',
    args: user ? [user] : undefined,
    query: { enabled: !!addr && !!user },
  })


  return (
    <div className="space-y-6">
      <section className="relative overflow-hidden rounded-xl">
        <img src="/images/parliament.svg" alt="Parliament" className="absolute inset-0 h-40 w-full object-cover opacity-40" />
        <div className="relative h-40 grid content-center p-6 bg-gradient-to-r from-[#0b1f3a]/60 via-transparent to-transparent">
          <div className="text-xl font-semibold text-white drop-shadow">Citizen Dashboard</div>
          <div className="text-sm text-white/80 drop-shadow">Check your verification progress and take quick actions</div>
        </div>
      </section>
      <section className="glass p-4 rounded-lg border border-slate-200">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-lg font-semibold">Welcome {user ? shorten(user) : 'Citizen'}</div>
            <div className="text-slate-600 text-sm">Connect your wallet to see your verification status.</div>
          </div>
          <div className="text-sm">
            <a className="underline" href="/wizard">Start Verification →</a>
          </div>
        </div>
      </section>

      <section className="grid md:grid-cols-2 gap-4">
        <div className="glass p-4 rounded-lg border border-white/10">
          <div className="font-semibold mb-2">My Verification Status</div>
          {!addr && <div className="text-white/70 text-sm">Set User Identity service address in Settings.</div>}
          {addr && !user && <div className="text-white/70 text-sm">Connect your wallet.</div>}
          {addr && user && (
            <div className="text-sm space-y-1">
              <div>Face Check: {status(profile?.[3])}</div>
              <div>Aadhaar: {status(profile?.[5])}</div>
              <div>Income: {status(profile?.[6])}</div>
              <div>Annual Income: {profile?.[6] && typeof profile?.[6] !== 'boolean' ? String(profile?.[6]) : String(profile?.[7])}</div>
              <div>Global Link: {String(profile?.[10])}</div>
            </div>
          )}
        </div>

        <div className="glass p-4 rounded-lg border border-white/10">
          <div className="font-semibold mb-2">Quick Actions</div>
          <div className="grid sm:grid-cols-2 gap-3">
            <a href="/wizard?step=face" className="block p-3 rounded-md border border-white/10 hover:bg-white/10">Do Face Check</a>
            <a href="/wizard?step=aadhaar" className="block p-3 rounded-md border border-white/10 hover:bg-white/10">Verify Aadhaar</a>
            <a href="/wizard?step=income" className="block p-3 rounded-md border border-white/10 hover:bg-white/10">Upload Income Proof</a>
            <a href="/admin" className="block p-3 rounded-md border border-white/10 hover:bg-white/10">Admin Services</a>
          </div>
        </div>
      </section>
    </div>
  )
}

function shorten(addr: string) { return `${addr.slice(0, 6)}…${addr.slice(-4)}` }
function status(code: any) { if (code === undefined) return '—'; const n = Number(code); if (n === 0) return 'Not done'; if (n === 1) return 'Done'; if (n === 2) return 'Cancelled'; return String(n) }

