const PINATA_BASE = 'https://api.pinata.cloud'

const PINATA_JWT = import.meta.env.VITE_PINATA_JWT as string | undefined
const PINATA_API_KEY = import.meta.env.VITE_PINATA_API_KEY as string | undefined
const PINATA_API_SECRET = import.meta.env.VITE_PINATA_API_SECRET as string | undefined
const PINATA_GATEWAY = import.meta.env.VITE_PINATA_GATEWAY || 'gateway.pinata.cloud'

export async function pinFile(file: File): Promise<{ cid: string, url: string }> {
  const form = new FormData()
  form.append('file', file)
  const res = await fetch(`${PINATA_BASE}/pinning/pinFileToIPFS`, {
    method: 'POST',
    headers: authHeaders(),
    body: form,
  })
  if (!res.ok) throw new Error(`Pinata upload failed: ${res.status}`)
  const data = await res.json()
  const cid = data.IpfsHash || data.Hash || data.cid
  return { cid, url: `https://${PINATA_GATEWAY}/ipfs/${cid}` }
}

export async function pinJSON(json: any): Promise<{ cid: string, url: string }> {
  const res = await fetch(`${PINATA_BASE}/pinning/pinJSONToIPFS`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...authHeaders(),
    },
    body: JSON.stringify(json),
  })
  if (!res.ok) throw new Error(`Pinata JSON upload failed: ${res.status}`)
  const data = await res.json()
  const cid = data.IpfsHash || data.Hash || data.cid
  return { cid, url: `https://${PINATA_GATEWAY}/ipfs/${cid}` }
}

function authHeaders(): Record<string, string> {
  if (PINATA_JWT) return { Authorization: `Bearer ${PINATA_JWT}` }
  if (PINATA_API_KEY && PINATA_API_SECRET) return {
    pinata_api_key: PINATA_API_KEY,
    pinata_secret_api_key: PINATA_API_SECRET,
  }
  return {}
}
