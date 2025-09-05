import type { AbiFunction } from '../types/contracts'
import { useState } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { useConfigStore } from '../store/config'
import { abis } from '../contracts/abis'
import { ensure0x, isHexString } from '../utils/hex'

function InputField({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block text-sm mb-3">
      <div className="mb-1 text-white/70">{label}</div>
      {children}
    </label>
  )
}

function parseArg(type: string, value: string): any {
  if (type.endsWith('[]')) {
    const base = type.slice(0, -2)
    return value.split(',').map((v) => parseArg(base.trim(), v.trim()))
  }
  if (type.startsWith('uint') || type.startsWith('int')) return BigInt(value)
  if (type === 'bool') return value === 'true'
  if (type === 'bytes32') return ensure0x(value)
  if (type === 'bytes') return ensure0x(value)
  return value
}

export default function ContractMethodForm({
  contractKey,
  fn,
}: {
  contractKey: keyof typeof abis
  fn: AbiFunction
}) {
  const { address: user } = useAccount()
  const contractAddress = useConfigStore((s) => s.addresses[contractKey as any])
  const [values, setValues] = useState<Record<string, string>>({})
  const { writeContractAsync, data: txHash, isPending, error: writeError } = useWriteContract()
  const { data: receipt, isLoading: waiting } = useWaitForTransactionReceipt({ hash: txHash })

  const argControls = fn.inputs.map((input, idx) => {
    const name = input.name || `arg${idx}`
    const type = input.type
    const v = values[name] ?? ''

    let placeholder = type
    if (type === 'address') placeholder = '0x...' 
    if (type === 'bytes32') placeholder = '0x + 64 hex chars'
    if (type === 'bytes') placeholder = '0x... (hex-encoded)'

    return (
      <InputField key={name} label={`${name} (${type})`}>
        <input
          className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10"
          value={v}
          placeholder={placeholder}
          onChange={(e) => setValues((s) => ({ ...s, [name]: e.target.value }))}
        />
      </InputField>
    )
  })

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!contractAddress) return alert('Please set the contract address in Settings first.')
    const args = fn.inputs.map((input, idx) => {
      const name = input.name || `arg${idx}`
      return parseArg(input.type, values[name] ?? '')
    })
    await writeContractAsync({
      address: contractAddress,
      abi: (abis as any)[contractKey],
      functionName: fn.name as any,
      args: args as any,
    })
  }

  return (
    <form onSubmit={onSubmit} className="p-4 rounded-lg glass border border-white/10">
      <div className="text-sm mb-4">
        <div className="font-semibold">{String(contractKey)}.{fn.name}</div>
        <div className="text-white/60">state: {fn.stateMutability}</div>
      </div>
      <div className="grid md:grid-cols-2 gap-3">
        {argControls}
      </div>
      <div className="mt-4 flex items-center gap-3">
        <button
          className="px-4 py-2 rounded-md bg-brand-600 hover:bg-brand-700 disabled:opacity-50"
          type="submit"
          disabled={isPending}
        >
          {isPending ? 'Submitting...' : 'Submit'}
        </button>
        {txHash && <span className="text-xs text-white/60">tx: {txHash.slice(0, 10)}…</span>}
        {waiting && <span className="text-xs">Waiting for receipt…</span>}
        {receipt && <span className="text-xs text-emerald-400">Confirmed in block {receipt.blockNumber?.toString()}</span>}
        {writeError && <span className="text-xs text-red-400">{writeError.message}</span>}
      </div>
    </form>
  )
}

