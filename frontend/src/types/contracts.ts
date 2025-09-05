export type AbiInput = { name?: string; type: string }
export type AbiFunction = {
  type: 'function'
  name: string
  inputs: AbiInput[]
  outputs?: { name?: string; type: string }[]
  stateMutability: 'view' | 'pure' | 'nonpayable' | 'payable'
}
export type AbiEvent = {
  type: 'event'
  name: string
  inputs: (AbiInput & { indexed?: boolean })[]
}
export type AbiItem = AbiFunction | AbiEvent | { type: string; [k: string]: any }
export type Abi = AbiItem[]

