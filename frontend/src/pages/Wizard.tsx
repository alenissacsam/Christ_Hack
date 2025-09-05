import Stepper from '../components/Stepper'
import FaceVerification from './steps/FaceVerification'
import AadhaarVerification from './steps/AadhaarVerification'
import IncomeProof from './steps/IncomeProof'
import ZkProof from './steps/ZkProof'
import { useState } from 'react'

const steps = ['Face', 'Aadhaar', 'Income', 'ZK Proof']

export default function Wizard() {
  const [current, setCurrent] = useState(0)

  // Allow deep-link via query ?step=face|aadhaar|income|zk
  const params = new URLSearchParams(location.search)
  const stepParam = params.get('step')
  if (stepParam) {
    const idx = ['face','aadhaar','income','zk'].indexOf(stepParam)
    if (idx !== -1 && idx !== current) setCurrent(idx)
  }

  return (
    <div>
      <section className="relative overflow-hidden rounded-xl mb-6">
        <img src="/images/hero.svg" alt="Digital India" className="absolute inset-0 h-32 w-full object-cover opacity-80" />
        <div className="relative h-32 grid content-center p-4 bg-gradient-to-r from-[#0b1f3a]/40 to-transparent text-white">
          <div className="text-lg font-semibold drop-shadow">Verification Steps</div>
          <div className="text-xs opacity-90 drop-shadow">Face → Aadhaar → Income → Finish</div>
        </div>
      </section>
      <Stepper current={current} steps={steps} />
      <div className="space-y-6">
        {current === 0 && <FaceVerification onNext={() => setCurrent(1)} />}
        {current === 1 && <AadhaarVerification onNext={() => setCurrent(2)} onBack={() => setCurrent(0)} />}
        {current === 2 && <IncomeProof onNext={() => setCurrent(3)} onBack={() => setCurrent(1)} />}
        {current === 3 && <ZkProof onBack={() => setCurrent(2)} />}
      </div>
    </div>
  )
}

