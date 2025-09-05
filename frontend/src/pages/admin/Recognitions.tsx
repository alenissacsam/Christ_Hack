import { useState } from 'react'
import { useWriteContract } from 'wagmi'
import { useConfigStore } from '../../store/config'
import { abis } from '../../contracts/abis'

export default function Recognitions() {
  return (
    <div className="space-y-8">
      <AddRecognition />
      <RevokeRecognition />
    </div>
  )
}

function AddRecognition() {
  const address = useConfigStore((s) => s.addresses['RecognitionManager'])
  const { writeContractAsync, isPending, error } = useWriteContract()
  const [credentialId, setCredentialId] = useState('')
  const [country, setCountry] = useState('India')
  const [doc, setDoc] = useState('')

  async function submit() {
    if (!address) return alert('Set RecognitionManager address in Settings')
    await writeContractAsync({
      address,
      abi: abis.RecognitionManager as any,
      functionName: 'addCountryRecognition',
      args: [BigInt(credentialId), country, doc],
    })
    setCredentialId(''); setDoc('')
  }

  return (
    <section className="glass p-4 rounded-lg border border-white/10">
      <div className="text-lg font-semibold mb-3">Add Country Recognition</div>
      <div className="grid md:grid-cols-2 gap-3">
        <label className="block text-sm">
          <div className="mb-1">Credential ID</div>
          <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={credentialId} onChange={e=>setCredentialId(e.target.value)} />
        </label>
        <label className="block text-sm">
          <div className="mb-1">Country</div>
          <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={country} onChange={e=>setCountry(e.target.value)} />
        </label>
        <label className="block text-sm md:col-span-2">
          <div className="mb-1">Recognition Document Link (URL/IPFS)</div>
          <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={doc} onChange={e=>setDoc(e.target.value)} placeholder="https://..." />
        </label>
      </div>
      <div className="mt-4">
        <button className="px-4 py-2 rounded-md bg-brand-600 hover:bg-brand-700" onClick={submit} disabled={isPending}>Add</button>
        {error && <span className="text-xs text-red-400 ml-3">{error.message}</span>}
      </div>
    </section>
  )
}

function RevokeRecognition() {
  const address = useConfigStore((s) => s.addresses['RecognitionManager'])
  const { writeContractAsync, isPending, error } = useWriteContract()
  const [credentialId, setCredentialId] = useState('')
  const [country, setCountry] = useState('India')

  async function submit() {
    if (!address) return alert('Set RecognitionManager address in Settings')
    await writeContractAsync({
      address,
      abi: abis.RecognitionManager as any,
      functionName: 'revokeCountryRecognition',
      args: [BigInt(credentialId), country],
    })
    setCredentialId('')
  }

  return (
    <section className="glass p-4 rounded-lg border border-white/10">
      <div className="text-lg font-semibold mb-3">Revoke Country Recognition</div>
      <div className="grid md:grid-cols-2 gap-3">
        <label className="block text-sm">
          <div className="mb-1">Credential ID</div>
          <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={credentialId} onChange={e=>setCredentialId(e.target.value)} />
        </label>
        <label className="block text-sm">
          <div className="mb-1">Country</div>
          <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={country} onChange={e=>setCountry(e.target.value)} />
        </label>
      </div>
      <div className="mt-4">
        <button className="px-4 py-2 rounded-md bg-brand-600 hover:bg-brand-700" onClick={submit} disabled={isPending}>Revoke</button>
        {error && <span className="text-xs text-red-400 ml-3">{error.message}</span>}
      </div>
    </section>
  )
}
