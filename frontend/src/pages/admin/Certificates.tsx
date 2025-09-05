import ToggleSwitch from '../../components/ToggleSwitch'
import { useState } from 'react'
import { useWriteContract } from 'wagmi'
import { useConfigStore } from '../../store/config'
import { abis } from '../../contracts/abis'
import IpfsUploadInput from '../../components/IpfsUploadInput'

export default function Certificates() {
  return (
    <div className="space-y-8">
      <IssueCertificate />
      <RevokeCertificate />
    </div>
  )
}

function IssueCertificate() {
  const address = useConfigStore((s) => s.addresses['CertificateManager'])
  const { writeContractAsync, isPending, error } = useWriteContract()
  const [recipient, setRecipient] = useState('')
  const [ctype, setCtype] = useState('Income Certificate')
  const [docLink, setDocLink] = useState('')
  const [expiry, setExpiry] = useState('')
  const [isGlobal, setIsGlobal] = useState(false)

  async function submit() {
    if (!address) return alert('Set CertificateManager address in Settings')
    if (!recipient) return alert('Enter recipient address')
    const expiryTs = expiry ? BigInt(Math.floor(new Date(expiry).getTime()/1000)) : BigInt(0)
    await writeContractAsync({
      address,
      abi: abis.CertificateManager as any,
      functionName: 'issueCertificate',
      args: [recipient as `0x${string}`, ctype, docLink, expiryTs, isGlobal],
    })
    setRecipient(''); setDocLink(''); setExpiry(''); setIsGlobal(false)
  }

  return (
    <section className="glass p-4 rounded-lg border border-slate-200">
      <div className="text-lg font-semibold mb-3">Give Certificate</div>
      <div className="grid md:grid-cols-2 gap-3">
        <label className="block text-sm">
          <div className="mb-1 text-slate-600">Recipient Address</div>
          <input className="w-full px-3 py-2 rounded-md bg-white border border-slate-300" value={recipient} onChange={e=>setRecipient(e.target.value)} placeholder="0x..." />
        </label>
        <label className="block text-sm">
          <div className="mb-1 text-slate-600">Certificate Type</div>
          <input className="w-full px-3 py-2 rounded-md bg-white border border-slate-300" value={ctype} onChange={e=>setCtype(e.target.value)} />
        </label>
        <label className="block text-sm md:col-span-2">
          <div className="mb-1 text-slate-600">Document Link (IPFS/URL)</div>
          <input className="w-full px-3 py-2 rounded-md bg-white border border-slate-300" value={docLink} onChange={e=>setDocLink(e.target.value)} placeholder="https://..." />
          <div className="mt-2"><IpfsUploadInput label="Or upload file" onUploaded={setDocLink} /></div>
        </label>
        <label className="block text-sm">
          <div className="mb-1 text-slate-600">Expiry Date</div>
          <input type="date" className="w-full px-3 py-2 rounded-md bg-white border border-slate-300" value={expiry} onChange={e=>setExpiry(e.target.value)} />
        </label>
        <label className="block text-sm">
          <div className="mb-1 text-slate-600">Global Certificate</div>
          <ToggleSwitch checked={isGlobal} onChange={setIsGlobal} labels={['No','Yes']} />
        </label>
      </div>
      <div className="mt-4">
        <button className="px-4 py-2 rounded-md bg-brand-600 hover:bg-brand-700" onClick={submit} disabled={isPending}>Issue</button>
        {error && <span className="text-xs text-red-400 ml-3">{error.message}</span>}
      </div>
    </section>
  )
}

function RevokeCertificate() {
  const address = useConfigStore((s) => s.addresses['CertificateManager'])
  const { writeContractAsync, isPending, error } = useWriteContract()
  const [certId, setCertId] = useState('')

  async function submit() {
    if (!address) return alert('Set CertificateManager address in Settings')
    if (!certId) return alert('Enter Certificate ID')
    await writeContractAsync({
      address,
      abi: abis.CertificateManager as any,
      functionName: 'revokeCertificate',
      args: [BigInt(certId)],
    })
    setCertId('')
  }

  return (
    <section className="glass p-4 rounded-lg border border-slate-200">
      <div className="text-lg font-semibold mb-3">Cancel Certificate</div>
      <div className="grid md:grid-cols-2 gap-3">
        <label className="block text-sm">
          <div className="mb-1 text-slate-600">Certificate ID</div>
          <input className="w-full px-3 py-2 rounded-md bg-white border border-slate-300" value={certId} onChange={e=>setCertId(e.target.value)} />
        </label>
      </div>
      <div className="mt-4">
        <button className="px-4 py-2 rounded-md bg-brand-600 hover:bg-brand-700" onClick={submit} disabled={isPending}>Revoke</button>
        {error && <span className="text-xs text-red-400 ml-3">{error.message}</span>}
      </div>
    </section>
  )
}
