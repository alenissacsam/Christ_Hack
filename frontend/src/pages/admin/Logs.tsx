import ToggleSwitch from '../../components/ToggleSwitch'
import { useState } from 'react'
import { useWriteContract } from 'wagmi'
import { useConfigStore } from '../../store/config'
import { abis } from '../../contracts/abis'

export default function Logs() {
  const address = useConfigStore((s) => s.addresses['VerificationLogger'])
  const { writeContractAsync, isPending, error } = useWriteContract()
  const [user, setUser] = useState('')
  const [type, setType] = useState<'Face'|'Aadhaar'|'Income'>('Face')
  const [success, setSuccess] = useState(true)
  const [details, setDetails] = useState('')

  async function submit() {
    if (!address) return alert('Set VerificationLogger address in Settings')
    await writeContractAsync({
      address,
      abi: abis.VerificationLogger as any,
      functionName: 'logVerification',
      args: [user as `0x${string}`, type, success, details],
    })
    setUser(''); setDetails('')
  }

  return (
    <div className="glass p-4 rounded-lg border border-white/10">
      <div className="text-lg font-semibold mb-3">Record Verification Activity</div>
      <div className="grid md:grid-cols-2 gap-3">
        <label className="block text-sm">
          <div className="mb-1">User Address</div>
          <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={user} onChange={e=>setUser(e.target.value)} placeholder="0x..." />
        </label>
        <label className="block text-sm">
          <div className="mb-1">Verification Type</div>
          <select className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={type} onChange={e=>setType(e.target.value as any)}>
            {['Face','Aadhaar','Income'].map(o=> <option key={o} value={o}>{o}</option>)}
          </select>
        </label>
        <label className="block text-sm">
          <div className="mb-1">Successful?</div>
          <ToggleSwitch checked={success} onChange={setSuccess} labels={['No','Yes']} />
        </label>
        <label className="block text-sm md:col-span-2">
          <div className="mb-1">Details (optional)</div>
          <textarea className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={details} onChange={e=>setDetails(e.target.value)} />
        </label>
      </div>
      <div className="mt-4">
        <button className="px-4 py-2 rounded-md bg-brand-600 hover:bg-brand-700" onClick={submit} disabled={isPending}>Save</button>
        {error && <span className="text-xs text-red-400 ml-3">{error.message}</span>}
      </div>
    </div>
  )
}
