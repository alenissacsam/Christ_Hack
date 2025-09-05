import { useMemo, useState } from 'react'
import { getCategorizedContracts } from '../../lib/abiRegistry'
import ContractMethodForm from '../../components/ContractMethodForm'

export default function ZkProof({ onBack }: { onBack: () => void }) {
  // Show any functions that include a `bytes` or `proof` parameter
  const zkFns = useMemo(() => {
    const contracts = getCategorizedContracts()
    return contracts.flatMap((c) =>
      c.functions.write
        .filter((f) => f.inputs.some((i) => i.type === 'bytes' || (i.name || '').toLowerCase().includes('proof')))
        .map((fn) => ({ key: c.key, fn }))
    )
  }, [])

  return (
    <div className="glass p-4 rounded-lg border border-white/10">
      <div className="font-semibold mb-3">Zero-Knowledge Proof Submission</div>
      <p className="text-sm text-white/70 mb-4">Detected write methods that accept proof bytes. Paste or upload your proof and submit.</p>
      <div className="space-y-4">
        {zkFns.length === 0 && <div className="text-white/60 text-sm">No proof-accepting functions detected in ABIs.</div>}
        {zkFns.map(({ key, fn }) => (
          <ContractMethodForm key={`${String(key)}.${fn.name}`} contractKey={key as any} fn={fn} />
        ))}
      </div>
      <div className="mt-4">
        <button className="px-4 py-2 rounded-md bg-white/10" onClick={onBack}>← Back</button>
      </div>
    </div>
  )
}

