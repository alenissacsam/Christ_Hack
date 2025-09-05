import { useState } from 'react'
import { useWriteContract } from 'wagmi'
import { useConfigStore } from '../../store/config'
import { abis } from '../../contracts/abis'
import { sha256Hex } from '../../utils/hash'

export default function CrossChain() {
  return (
    <div className="space-y-8">
      <AddChain />
      <AnchorCrossChain />
    </div>
  )
}

function AddChain() {
  const address = useConfigStore((s) => s.addresses['CrossChainManager'])
  const { writeContractAsync, isPending, error } = useWriteContract()
  const [name, setName] = useState('Polygon')

  async function submit() {
    if (!address) return alert('Set CrossChainManager address in Settings')
    await writeContractAsync({ address, abi: abis.CrossChainManager as any, functionName: 'addSupportedChain', args: [name] })
  }

  return (
    <section className="glass p-4 rounded-lg border border-white/10">
      <div className="text-lg font-semibold mb-3">Add Supported Chain</div>
      <div className="grid md:grid-cols-2 gap-3">
        <label className="block text-sm">
          <div className="mb-1">Chain Name</div>
          <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={name} onChange={e=>setName(e.target.value)} />
        </label>
      </div>
      <div className="mt-4">
        <button className="px-4 py-2 rounded-md bg-brand-600 hover:bg-brand-700" onClick={submit} disabled={isPending}>Add</button>
        {error && <span className="text-xs text-red-400 ml-3">{error.message}</span>}
      </div>
    </section>
  )
}

function AnchorCrossChain() {
  const address = useConfigStore((s) => s.addresses['CrossChainManager'])
  const { writeContractAsync, isPending, error } = useWriteContract()
  const [credentialId, setCredentialId] = useState('')
  const [targetChain, setTargetChain] = useState('Polygon')
  const [targetContract, setTargetContract] = useState('')
  const [details, setDetails] = useState('')

  async function submit() {
    if (!address) return alert('Set CrossChainManager address in Settings')
    if (!credentialId || !targetContract) return alert('Fill all fields')
    const anchorHash = await sha256Hex(details || `${credentialId}-${targetChain}-${targetContract}`)
    await writeContractAsync({
      address,
      abi: abis.CrossChainManager as any,
      functionName: 'anchorCrossChain',
      args: [BigInt(credentialId), targetChain, targetContract, anchorHash],
    })
    setDetails('')
  }

  return (
    <section className="glass p-4 rounded-lg border border-white/10">
      <div className="text-lg font-semibold mb-3">Anchor Credential on Another Chain</div>
      <div className="grid md:grid-cols-2 gap-3">
        <label className="block text-sm">
          <div className="mb-1">Credential ID</div>
          <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={credentialId} onChange={e=>setCredentialId(e.target.value)} />
        </label>
        <label className="block text-sm">
          <div className="mb-1">Target Chain</div>
          <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={targetChain} onChange={e=>setTargetChain(e.target.value)} />
        </label>
        <label className="block text-sm md:col-span-2">
          <div className="mb-1">Target Contract Address</div>
          <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={targetContract} onChange={e=>setTargetContract(e.target.value)} placeholder="0x..." />
        </label>
        <label className="block text-sm md:col-span-2">
          <div className="mb-1">Anchor Details (will be securely hashed)</div>
          <textarea className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={details} onChange={e=>setDetails(e.target.value)} placeholder="Optional note" />
        </label>
      </div>
      <div className="mt-4">
        <button className="px-4 py-2 rounded-md bg-brand-600 hover:bg-brand-700" onClick={submit} disabled={isPending}>Anchor</button>
        {error && <span className="text-xs text-red-400 ml-3">{error.message}</span>}
      </div>
    </section>
  )
}
