import { useState } from 'react'
import { pinFile } from '../utils/ipfs'

export default function IpfsUploadInput({ label, onUploaded }: { label: string; onUploaded: (url: string) => void }) {
  const [file, setFile] = useState<File | null>(null)
  const [status, setStatus] = useState<'idle'|'uploading'|'done'|'error'>('idle')
  const [error, setError] = useState<string | null>(null)

  async function upload() {
    if (!file) return
    setStatus('uploading'); setError(null)
    try {
      const { url } = await pinFile(file)
      onUploaded(url)
      setStatus('done')
    } catch (e: any) {
      setError(e?.message || 'Upload failed')
      setStatus('error')
    }
  }

  return (
    <div className="space-y-2">
      <label className="block text-sm">
        <div className="mb-1 text-slate-600">{label}</div>
        <input type="file" onChange={(e)=>setFile(e.target.files?.[0] || null)} />
      </label>
      <div className="flex items-center gap-2">
        <button type="button" className="px-3 py-2 rounded-md bg-brand-600 hover:bg-brand-700 text-white text-sm" onClick={upload} disabled={!file || status==='uploading'}>
          {status==='uploading' ? 'Uploading…' : 'Upload to IPFS'}
        </button>
        {status==='done' && <span className="text-xs text-emerald-600">Uploaded ✓</span>}
        {error && <span className="text-xs text-red-600">{error}</span>}
      </div>
      <div className="text-xs text-slate-500">Powered by Pinata. Files are stored on IPFS; links use your configured gateway.</div>
    </div>
  )
}
