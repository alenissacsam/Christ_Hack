import ToggleSwitch from '../../components/ToggleSwitch'
import { useState } from 'react'
import { useWriteContract } from 'wagmi'
import { useConfigStore } from '../../store/config'
import { abis } from '../../contracts/abis'
import IpfsUploadInput from '../../components/IpfsUploadInput'

export default function Organizations() {
  return (
    <div className="space-y-8">
      <RegisterOrganization />
      <ApproveOrganization />
    </div>
  )
}

function RegisterOrganization() {
  const address = useConfigStore((s) => s.addresses['OrganizationRegistry'])
  const { writeContractAsync, isPending, error } = useWriteContract()
  const [name, setName] = useState('')
  const [orgType, setOrgType] = useState<'Government' | 'Private' | 'NGO' | 'Bank' | 'University' | 'Employer'>('Government')
  const [profileUri, setProfileUri] = useState('')
  const [country, setCountry] = useState('India')
  const [regNo, setRegNo] = useState('')
  const [types, setTypes] = useState<{ [k: string]: boolean }>({ Income: true, Identity: false, Employment: false })
  const [customTypes, setCustomTypes] = useState('')

  const typeToUint: Record<string, number> = { Government: 0, Private: 1, NGO: 2, Bank: 3, University: 4, Employer: 5 }

  async function submit() {
    if (!address) return alert('Set OrganizationRegistry address in Settings')
    const allowed = [
      ...Object.entries(types).filter(([, v]) => v).map(([k]) => k),
      ...customTypes.split(',').map((s) => s.trim()).filter(Boolean),
    ]
    await writeContractAsync({
      address,
      abi: abis.OrganizationRegistry as any,
      functionName: 'registerOrganization',
      args: [
        name,
        BigInt(typeToUint[orgType]),
        profileUri,
        allowed,
        country,
        regNo,
      ],
    })
    setName(''); setProfileUri(''); setRegNo(''); setCustomTypes('')
  }

  return (
    <section className="glass p-4 rounded-lg border border-slate-200">
      <div className="text-lg font-semibold mb-3">Register an Organization</div>
      <div className="grid md:grid-cols-2 gap-3">
        <label className="block text-sm">
          <div className="mb-1 text-slate-600">Organization Name</div>
          <input className="w-full px-3 py-2 rounded-md bg-white border border-slate-300" value={name} onChange={e=>setName(e.target.value)} />
        </label>
        <label className="block text-sm">
          <div className="mb-1 text-slate-600">Organization Type</div>
          <select className="w-full px-3 py-2 rounded-md bg-white border border-slate-300" value={orgType} onChange={e=>setOrgType(e.target.value as any)}>
            {['Government','Private','NGO','Bank','University','Employer'].map(o=> <option key={o} value={o}>{o}</option>)}
          </select>
        </label>
        <label className="block text-sm md:col-span-2">
          <div className="mb-1 text-slate-600">Profile Link (optional)</div>
          <input className="w-full px-3 py-2 rounded-md bg-white border border-slate-300" value={profileUri} onChange={e=>setProfileUri(e.target.value)} placeholder="https://..." />
          <div className="mt-2"><IpfsUploadInput label="Or upload a profile document" onUploaded={setProfileUri} /></div>
        </label>
        <label className="block text-sm">
          <div className="mb-1 text-slate-600">Country</div>
          <input className="w-full px-3 py-2 rounded-md bg-white border border-slate-300" value={country} onChange={e=>setCountry(e.target.value)} />
        </label>
        <label className="block text-sm">
          <div className="mb-1 text-slate-600">Registration Number</div>
          <input className="w-full px-3 py-2 rounded-md bg-white border border-slate-300" value={regNo} onChange={e=>setRegNo(e.target.value)} />
        </label>
        <div className="block text-sm">
          <div className="mb-1">Certificates you can issue</div>
          <div className="flex flex-wrap gap-3 text-sm">
            {Object.keys(types).map(k => (
              <label key={k} className="flex items-center gap-2">
                <input type="checkbox" checked={types[k]} onChange={e=>setTypes(s=>({ ...s, [k]: e.target.checked }))} /> {k}
              </label>
            ))}
          </div>
          <div className="mt-2">
            <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={customTypes} onChange={e=>setCustomTypes(e.target.value)} placeholder="Custom types (comma separated)" />
          </div>
        </div>
      </div>
      <div className="mt-4 flex items-center gap-3">
        <button className="px-4 py-2 rounded-md bg-brand-600 hover:bg-brand-700" onClick={submit} disabled={isPending}>Register</button>
        {error && <span className="text-xs text-red-600">{error.message}</span>}
      </div>
    </section>
  )
}

function ApproveOrganization() {
  const address = useConfigStore((s) => s.addresses['OrganizationRegistry'])
  const { writeContractAsync, isPending, error } = useWriteContract()
  const [orgId, setOrgId] = useState('')
  const [allowGlobal, setAllowGlobal] = useState(false)

  async function submit() {
    if (!address) return alert('Set OrganizationRegistry address in Settings')
    if (!orgId) return alert('Enter Organization ID')
    await writeContractAsync({
      address,
      abi: abis.OrganizationRegistry as any,
      functionName: 'approveOrganization',
      args: [BigInt(orgId), allowGlobal],
    })
    setOrgId(''); setAllowGlobal(false)
  }

  return (
    <section className="glass p-4 rounded-lg border border-slate-200">
      <div className="text-lg font-semibold mb-3">Approve Organization</div>
      <div className="grid md:grid-cols-2 gap-3">
        <label className="block text-sm">
          <div className="mb-1 text-slate-600">Organization ID</div>
          <input className="w-full px-3 py-2 rounded-md bg-white border border-slate-300" value={orgId} onChange={e=>setOrgId(e.target.value)} />
        </label>
        <label className="block text-sm">
          <div className="mb-1 text-slate-600">Allow Global Certificates</div>
          <ToggleSwitch checked={allowGlobal} onChange={setAllowGlobal} labels={['No','Yes']} />
        </label>
      </div>
      <div className="mt-4">
        <button className="px-4 py-2 rounded-md bg-brand-600 hover:bg-brand-700" onClick={submit} disabled={isPending}>Approve</button>
        {error && <span className="text-xs text-red-400 ml-3">{error.message}</span>}
      </div>
    </section>
  )
}
