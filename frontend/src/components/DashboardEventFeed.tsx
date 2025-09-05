import { useEffect, useState } from 'react'
import type { Abi } from '../types/contracts'
import { wagmiConfig } from '../wagmi'
import { watchContractEvent } from 'wagmi/actions'

export default function DashboardEventFeed({
  address,
  abi,
  eventName,
}: {
  address?: `0x${string}`
  abi: Abi
  eventName?: string
}) {
  const [logs, setLogs] = useState<any[]>([])

  useEffect(() => {
    if (!address) return
    const unwatch = watchContractEvent(wagmiConfig, {
      address,
      abi: abi as any,
      ...(eventName ? { eventName: eventName as any } : {}),
    }, (log) => {
      setLogs((l) => [log, ...l].slice(0, 50))
    })
    return () => unwatch?.()
  }, [address, abi, eventName])

  return (
    <div className="p-4 rounded-lg glass border border-white/10">
      <div className="font-semibold mb-3">Live Events {eventName ? `(${eventName})` : ''}</div>
      <div className="space-y-2 max-h-80 overflow-auto text-xs">
        {logs.length === 0 && <div className="text-white/60">No events yet.</div>}
        {logs.map((l, i) => (
          <pre key={i} className="bg-white/5 p-2 rounded-md whitespace-pre-wrap break-words">{JSON.stringify(l, null, 2)}</pre>
        ))}
      </div>
    </div>
  )
}

