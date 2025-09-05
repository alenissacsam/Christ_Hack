import { useState } from 'react'
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { useConfigStore } from '../../store/config'
import { abis } from '../../contracts/abis'
import { fileToArrayBuffer, sha256Hex } from '../../utils/hash'
import { toHexString } from '../../utils/hex'

export default function IncomeProof({ onNext, onBack }: { onNext: () => void; onBack: () => void }) {
  const [hash, setHash] = useState<`0x${string}` | ''>('')
  const [proofHex, setProofHex] = useState<`0x${string}` | ''>('')
  const [income, setIncome] = useState('')
  const address = useConfigStore((s) => s.addresses['UserIdentityRegistry'])
  const { writeContractAsync, data: txHash, isPending, error } = useWriteContract()
  const { isLoading: waiting, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })

  async function onFile(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0]
    if (!f) return
    const buf = await fileToArrayBuffer(f)
    const h = await sha256Hex(buf)
    setHash(h)
  }

  async function submit() {
    if (!address) return alert('Set UserIdentityRegistry address in Settings')
    if (!hash) return alert('Upload income document to compute hash')
    // proof is optional; you can upload a code below
    if (!income) return alert('Enter annual income')
    await writeContractAsync({
      address,
      abi: abis.UserIdentityRegistry as any,
      functionName: 'verifyIncome',
      args: [hash, (proofHex || ('0x' as `0x${string}`)), BigInt(income)],
    })
  }

  return (
    <div className="glass p-4 rounded-lg border border-slate-200">
      <div className="font-semibold mb-3">Income Certificate</div>
      <div className="grid md:grid-cols-2 gap-4">
        <div>
          <img src="/images/income-illustration.svg" alt="Income" className="w-28 mb-3 opacity-90" />
          <label className="block text-sm">
            <div className="mb-1 text-slate-600">Upload income proof document</div>
            <input type="file" accept="image/*,.pdf" onChange={onFile} />
          </label>
          <div className="text-sm mt-3">Status:</div>
          <div className="text-xs bg-white/5 p-2 rounded-md">{hash ? 'Document processed ✓' : 'No document yet'}</div>
        </div>
        <div>
          <label className="block text-sm">
            <div className="mb-1 text-slate-600">Annual Income (numbers only)</div>
            <input className="w-full px-3 py-2 rounded-md bg-white border border-slate-300" value={income} onChange={e=>setIncome(e.target.value)} placeholder="e.g., 100000" />
          </label>
          <details className="block text-sm mt-3">
            <summary className="cursor-pointer">Upload verification code (optional)</summary>
            <div className="mt-2 grid gap-2">
              <input type="file" onChange={async (e)=>{ const f=e.target.files?.[0]; if(!f) return; const buf=await fileToArrayBuffer(f); setProofHex(toHexString(new Uint8Array(buf))) }} />
              <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={proofHex} onChange={e=>setProofHex(e.target.value as any)} placeholder="paste code" />
            </div>
          </details>
          <div className="flex items-center gap-3 mt-3">
            <button className="px-4 py-2 rounded-md bg-white/10" onClick={onBack}>← Back</button>
            <button className="px-4 py-2 rounded-md bg-brand-600 hover:bg-brand-700" onClick={submit} disabled={isPending}>Submit</button>
            {isPending && <span className="text-xs">Submitting…</span>}
            {waiting && <span className="text-xs">Waiting…</span>}
            {isSuccess && <button className="text-xs underline" onClick={onNext}>Continue →</button>}
            {error && <span className="text-xs text-red-400">{error.message}</span>}
          </div>
        </div>
      </div>
    </div>
  )
}

