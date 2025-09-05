import type { AbiFunction } from '../types/contracts'
import { useState } from 'react'
import { abis } from '../contracts/abis'
import { useConfigStore } from '../store/config'
import { readContract } from 'wagmi/actions'
import { wagmiConfig } from '../wagmi'

export default function ReadMethodForm({ contractKey, fn }: { contractKey: keyof typeof abis; fn: AbiFunction }) {
  const address = useConfigStore((s) => s.addresses[contractKey as any])
  const [values, setValues] = useState<Record<string, string>>({})
  const [result, setResult] = useState<any>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  function parseArg(type: string, value: string): any {
    if (type.endsWith('[]')) {
      const base = type.slice(0, -2)
      return value.split(',').map((v) => parseArg(base.trim(), v.trim()))
    }
    if (type.startsWith('uint') || type.startsWith('int')) return BigInt(value)
    if (type === 'bool') return value === 'true'
    return value
  }

  async function onRead() {
    if (!address) return alert('Set contract address in Settings')
    setLoading(true)
    setError(null)
    try {
      const args = fn.inputs.map((input, idx) => parseArg(input.type, values[input.name || `arg${idx}`] ?? ''))
      const out = await readContract(wagmiConfig, {
        address,
        abi: (abis as any)[contractKey],
        functionName: fn.name as any,
        args: args as any,
      })
      setResult(out)
    } catch (e: any) {
      setError(e?.message || String(e))
      setResult(null)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="p-4 rounded-lg glass border border-white/10">
      <div className="text-sm mb-2 font-semibold">{String(contractKey)}.{fn.name}</div>
      <div className="grid md:grid-cols-2 gap-3">
        {fn.inputs.map((input, idx) => {
          const name = input.name || `arg${idx}`
          return (
            <label key={name} className="block text-sm">
              <div className="mb-1 text-white/70">{name} ({input.type})</div>
              <input className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10" value={values[name] || ''}
                     onChange={(e)=>setValues((s)=>({ ...s, [name]: e.target.value }))} />
            </label>
          )
        })}
      </div>
      <div className="mt-3 flex items-center gap-3">
        <button className="px-3 py-2 rounded-md bg-white/10" onClick={onRead} disabled={loading}>Read</button>
        {loading && <span className="text-xs">Loading…</span>}
        {error && <span className="text-xs text-red-400">{error}</span>}
      </div>
      {result !== null && (
        <pre className="mt-3 text-xs bg-white/5 p-2 rounded-md whitespace-pre-wrap break-words">{JSON.stringify(result, null, 2)}</pre>
      )}
    </div>
  )
}

