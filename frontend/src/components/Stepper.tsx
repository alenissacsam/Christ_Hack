export default function Stepper({ current, steps }: { current: number; steps: string[] }) {
  return (
    <div className="flex items-center gap-2 mb-6">
      {steps.map((s, i) => {
        const active = i <= current
        return (
          <div key={s} className="flex items-center gap-2">
            <div className={`h-8 w-8 rounded-full grid place-items-center text-sm ${active ? 'bg-brand-600' : 'bg-white/10'}`}>{i+1}</div>
            <div className={`text-sm ${active ? '' : 'text-white/60'}`}>{s}</div>
            {i < steps.length - 1 && <div className="w-8 h-px bg-white/20 mx-2" />}
          </div>
        )
      })}
    </div>
  )
}

