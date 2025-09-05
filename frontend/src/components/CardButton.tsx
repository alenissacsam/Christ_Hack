import { Link } from 'react-router-dom'

export default function CardButton({ to, title, subtitle, img }: { to: string; title: string; subtitle?: string; img: string }) {
  return (
    <Link to={to} className="group block overflow-hidden rounded-xl border border-white/10 bg-white/5 hover:bg-white/10 transition">
      <div className="flex items-center gap-4 p-4">
        <img src={img} alt="" className="h-20 w-20 rounded-lg bg-white/5 p-3 object-cover" />
        <div>
          <div className="text-lg font-semibold">{title}</div>
          {subtitle && <div className="text-sm text-white/70">{subtitle}</div>}
        </div>
        <div className="ml-auto text-brand-500 text-xl">→</div>
      </div>
    </Link>
  )
}
