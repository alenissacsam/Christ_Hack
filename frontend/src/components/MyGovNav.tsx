import { Link } from 'react-router-dom'

export default function MyGovNav() {
  const items = [
    { to: '/wizard', label: 'Activities' },
    { to: '/', label: 'MyGov States' },
    { to: '/', label: 'Microsites' },
    { to: '/status', label: 'Get to Know' },
    { to: '/settings', label: 'Help/Feedback' },
  ]
  return (
    <div className="border-b border-white/10 bg-white/5">
      <div className="mx-auto max-w-6xl px-4 py-2 text-sm flex items-center gap-4">
        {items.map((it) => (
          <Link key={it.label} to={it.to} className="hover:underline">
            {it.label}
          </Link>
        ))}
      </div>
    </div>
  )
}
