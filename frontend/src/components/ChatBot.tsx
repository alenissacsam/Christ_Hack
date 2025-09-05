import { useEffect, useRef, useState } from 'react'
import { abis } from '../contracts/abis'
import { useConfigStore } from '../store/config'
import knowledge from '../knowledge/base'

function matchAnswer(q: string): string {
  const s = q.toLowerCase()
  // simple intent matching
  for (const item of knowledge) {
    if (item.q.some((k) => s.includes(k))) return item.a
  }
  // fallback
  return "I'm here to help with Face, Aadhaar, Income verification, wallet, and settings. Try asking: ‘How do I scan Aadhaar QR?’ or ‘Why is my transaction pending?’"
}

export default function ChatBot() {
  const [open, setOpen] = useState(false)
  const [messages, setMessages] = useState<{ role: 'user'|'assistant'; content: string }[]>([
    { role: 'assistant', content: 'Namaste! I am your Digital Identity assistant. How can I help you today?' }
  ])
  const [input, setInput] = useState('')
  const intervalRef = useRef<number | null>(null)
  const bubbleRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const onOpen = (e: any) => {
      if (e?.detail?.message) setMessages((m)=>[...m,{role:'assistant',content:e.detail.message}])
      setOpen(true)
    }
    window.addEventListener('open-chat', onOpen as any)
    ;(window as any).openChatWithPrompt = (msg: string) => {
      window.dispatchEvent(new CustomEvent('open-chat', { detail: { message: msg } }))
    }
    intervalRef.current = window.setInterval(() => {
      if (!open) {
        bubbleRef.current?.classList.add('animate-bounce')
        setTimeout(()=>bubbleRef.current?.classList.remove('animate-bounce'), 1200)
      }
    }, 20000)
    return () => {
      window.removeEventListener('open-chat', onOpen as any)
      if (intervalRef.current) window.clearInterval(intervalRef.current)
    }
  }, [open])

  async function send() {
    const q = input.trim()
    if (!q) return
    setMessages((m)=>[...m,{role:'user',content:q}])
    setInput('')
    // If configured to use external chat API
    const apiUrl = import.meta.env.VITE_CHAT_API_URL
    const apiKey = import.meta.env.VITE_CHAT_API_KEY
    if (apiUrl && apiKey) {
      try {
        const res = await fetch(apiUrl, { method: 'POST', headers: { 'Content-Type':'application/json', Authorization: `Bearer ${apiKey}` }, body: JSON.stringify({ messages: [{ role: 'user', content: q }] }) })
        const data = await res.json()
        const content = data?.reply || data?.choices?.[0]?.message?.content || matchAnswer(q)
        setMessages((m)=>[...m,{role:'assistant',content}])
        return
      } catch {}
    }
    const a = matchAnswer(q)
    setMessages((m)=>[...m,{role:'assistant',content:a}])
  }

  return (
    <>
      {/* floating bubble */}
      <div ref={bubbleRef} className="fixed bottom-6 right-6 z-50">
        {!open && (
          <button onClick={()=>setOpen(true)} className="rounded-full bg-brand-600 hover:bg-brand-700 text-white shadow-lg px-4 py-3 flex items-center gap-2">
            <span>💬</span>
            <span className="text-sm">Talk</span>
          </button>
        )}
      </div>

      {/* panel */}
      {open && (
        <div className="fixed bottom-6 right-6 z-50 w-[360px] max-w-[90vw] rounded-xl glass border border-white/10 shadow-2xl">
          <div className="px-4 py-3 flex items-center justify-between border-b border-white/10">
            <div className="font-semibold">Assistant</div>
            <button onClick={()=>setOpen(false)} className="text-white/70 hover:text-white">✕</button>
          </div>
          <div className="p-3 h-64 overflow-auto space-y-2 text-sm">
            {messages.map((m,i)=> (
              <div key={i} className={m.role==='user' ? 'text-right' : 'text-left'}>
                <div className={`inline-block px-3 py-2 rounded-lg ${m.role==='user' ? 'bg-white/10' : 'bg-brand-600'}`}>{m.content}</div>
              </div>
            ))}
          </div>
          <div className="p-3 flex items-center gap-2 border-t border-white/10">
            <input value={input} onChange={e=>setInput(e.target.value)} onKeyDown={e=>{ if(e.key==='Enter') send() }} className="flex-1 px-3 py-2 rounded-md bg-white/5 border border-white/10" placeholder="Type your question…" />
            <button onClick={send} className="px-3 py-2 rounded-md bg-brand-600 hover:bg-brand-700">Send</button>
          </div>
        </div>
      )}
    </>
  )
}
