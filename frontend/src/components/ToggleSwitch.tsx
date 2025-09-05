export default function ToggleSwitch({ checked, onChange, labels = ['No', 'Yes'] }: { checked: boolean; onChange: (v: boolean) => void; labels?: [string, string] | string[] }) {
  const [off, on] = labels
  return (
    <div className="flex items-center gap-2">
      <span className={`text-sm ${!checked ? '' : 'text-white/50'}`}>{off}</span>
      <button
        type="button"
        onClick={() => onChange(!checked)}
        className={`relative inline-flex h-6 w-11 items-center rounded-full transition ${checked ? 'bg-brand-600' : 'bg-white/20'}`}
      >
        <span className={`inline-block h-5 w-5 transform rounded-full bg-white transition ${checked ? 'translate-x-5' : 'translate-x-1'}`} />
      </button>
      <span className={`text-sm ${checked ? '' : 'text-white/50'}`}>{on}</span>
    </div>
  )
}
