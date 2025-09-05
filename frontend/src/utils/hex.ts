export function toHexString(buf: ArrayBuffer | Uint8Array): `0x${string}` {
  const bytes = buf instanceof ArrayBuffer ? new Uint8Array(buf) : buf
  const hex = Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join('')
  return (`0x${hex}`) as `0x${string}`
}

export function isHexString(v: string): v is `0x${string}` {
  return /^0x[0-9a-fA-F]*$/.test(v)
}

export function ensure0x(v: string): `0x${string}` {
  return (v.startsWith('0x') ? v : `0x${v}`) as `0x${string}`
}

