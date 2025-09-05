import type { Abi, AbiEvent, AbiFunction } from '../types/contracts'
import { abis } from '../contracts/abis'
import type { ContractKey } from '../store/config'

export type CategorizedContract = {
  key: ContractKey
  abi: Abi
  functions: {
    read: AbiFunction[]
    write: AbiFunction[]
  }
  events: AbiEvent[]
}

function isFunction(item: any): item is AbiFunction {
  return item?.type === 'function' && typeof item?.name === 'string'
}
function isEvent(item: any): item is AbiEvent {
  return item?.type === 'event' && typeof item?.name === 'string'
}

export function getCategorizedContracts(): CategorizedContract[] {
  const keys = Object.keys(abis) as ContractKey[]
  return keys.map((key) => {
    const abi = (abis as any)[key] as Abi
    const functions = abi.filter(isFunction) as AbiFunction[]
    const events = abi.filter(isEvent) as AbiEvent[]
    const read = functions.filter((f) => f.stateMutability === 'view' || f.stateMutability === 'pure')
    const write = functions.filter((f) => f.stateMutability === 'nonpayable' || f.stateMutability === 'payable')
    return { key, abi, functions: { read, write }, events }
  })
}

export function guessMethodCategory(fnName: string): string {
  const n = fnName.toLowerCase()
  if (n.includes('face')) return 'face'
  if (n.includes('aadhaar')) return 'aadhaar'
  if (n.includes('income')) return 'income'
  if (n.includes('zk') || n.includes('proof')) return 'zk'
  if (n.includes('certificate')) return 'certificate'
  if (n.includes('organization')) return 'organization'
  if (n.includes('anchor')) return 'anchor'
  if (n.includes('recognition')) return 'recognition'
  if (n.includes('log')) return 'logging'
  return 'generic'
}

