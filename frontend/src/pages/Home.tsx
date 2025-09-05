function AdminCard() {
  const { isAdmin } = useIsAdmin()
  if (!isAdmin) {
    return <div className="opacity-50 cursor-not-allowed">
      <CardButton to="#" title="Admin Services (restricted)" subtitle="Only authorized officials" img="/images/gov-building.svg" />
    </div>
  }
  return <CardButton to="/admin" title="Admin Services" subtitle="Organizations, certificates, recognitions" img="/images/gov-building.svg" />
}

import CardButton from '../components/CardButton'
import MyGovTabs from '../components/MyGovTabs'
import { useIsAdmin } from '../hooks/useIsAdmin'

export default function Home() {
  return (
    <div className="space-y-8">
      <div className="relative rounded-xl overflow-hidden">
        <img src="/images/mygov-hero.svg" alt="Citizen Engagement" className="absolute inset-0 h-56 w-full object-cover opacity-80" />
        <div className="relative p-6 h-56 grid content-center bg-gradient-to-r from-[#0b1f3a]/60 to-transparent">
          <div className="text-3xl font-bold drop-shadow">WORLD LARGEST CITIZEN</div>
          <div className="text-3xl font-bold text-[#ff9933] drop-shadow">ENGAGEMENT PLATFORM</div>
        </div>
      </div>

      <MyGovTabs />

      <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <CardButton to="/wizard?step=face" title="Face Check" subtitle="Quick selfie verification" img="/images/selfie-illustration.svg" />
        <CardButton to="/wizard?step=aadhaar" title="Aadhaar" subtitle="Scan QR or upload Aadhaar" img="/images/aadhaar-card.svg" />
        <CardButton to="/wizard?step=income" title="Income Proof" subtitle="Upload income document" img="/images/income-illustration.svg" />
        <CardButton to="/status" title="My Status" subtitle="View your verification status" img="/images/status-illustration.svg" />
        <AdminCard />
        <CardButton to="/settings" title="Settings" subtitle="Network & contract addresses" img="/images/settings.svg" />
      </div>
    </div>
  )
}
