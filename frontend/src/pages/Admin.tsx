import { getCategorizedContracts } from '../lib/abiRegistry'
import ContractMethodForm from '../components/ContractMethodForm'
import { useConfigStore } from '../store/config'

import CardButton from '../components/CardButton'

import { useIsAdmin } from '../hooks/useIsAdmin'

export default function Admin() {
  const { isAdmin } = useIsAdmin()
  if (!isAdmin) {
    return (
      <div className="glass p-4 rounded-lg border border-white/10">
        <div className="text-lg font-semibold mb-2">Access Denied</div>
        <div className="text-sm">This area is restricted to authorized administrators. If you believe this is a mistake, please contact your administrator.
          <button className="ml-2 underline" onClick={()=>window.dispatchEvent(new CustomEvent('open-chat',{detail:{message:'I need admin access help'}}))}>Talk to assistant</button>
        </div>
      </div>
    )
  }
  return (
    <div className="space-y-6">
      <section className="relative overflow-hidden rounded-xl">
        <img src="/images/gov-building.svg" alt="Government" className="absolute inset-0 h-40 w-full object-cover opacity-30" />
        <div className="relative h-40 grid content-center p-6 bg-gradient-to-r from-[#0b1f3a]/60 via-transparent to-transparent">
          <div className="text-xl font-semibold text-white drop-shadow">Admin Services</div>
          <div className="text-sm text-white/80 drop-shadow">Manage organizations, certificates, recognitions and more</div>
        </div>
      </section>
      <div className="glass p-4 rounded-lg border border-white/10">
        <div className="text-xl font-semibold">Admin Services</div>
        <div className="text-sm text-white/70">Simple tools for officials to manage organizations, certificates, recognitions and more.</div>
      </div>

      <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <CardButton to="/admin/organizations" title="Organizations" subtitle="Register and approve organizations" img="/org.svg" />
        <CardButton to="/admin/certificates" title="Certificates" subtitle="Issue or revoke certificates" img="/certificate.svg" />
        <CardButton to="/admin/recognitions" title="Recognitions" subtitle="Add or revoke country recognition" img="/recognition.svg" />
        <CardButton to="/admin/cross-chain" title="Cross-Chain" subtitle="Anchor credentials on other chains" img="/chain.svg" />
        <CardButton to="/admin/logs" title="Logs" subtitle="Record verification activity" img="/logs.svg" />
      </div>

      <div className="text-xs text-white/50">Advanced developer tools are hidden to keep things simple for users.</div>
    </div>
  )
}

