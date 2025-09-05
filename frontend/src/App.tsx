import { Outlet, Link, useLocation } from 'react-router-dom'
import WalletConnectButton from './components/WalletConnectButton'
import GovTopBar from './components/GovTopBar'
import MyGovNav from './components/MyGovNav'
import ChatBot from './components/ChatBot'
import { LanguageProvider, useLanguage, languageOptions } from './contexts/LanguageContext'
import { useState } from 'react'

function AppContent() {
  const { pathname } = useLocation()
  const { t } = useLanguage()
  const tabs = [
    { to: '/', label: t('home') },
    { to: '/status', label: t('myStatus') },
    { to: '/wizard', label: t('verification') },
    { to: '/admin', label: t('adminServices') },
    { to: '/settings', label: t('settings') },
  ]
  return (
    <div className="min-h-screen crystal-bg text-slate-100">
      <GovTopBar />
      <header className="sticky top-0 z-50 border-b border-white/10 backdrop-blur glass">
        <div className="flag-ribbon animate-flag" />
        <div className="mx-auto max-w-6xl px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-full bg-gradient-to-br from-brand-600 to-indiaGreen grid place-items-center">
              <img src="/images/ashoka.svg" alt="Ashoka" className="h-6 w-6" />
            </div>
            <div className="font-semibold">
              {t('digitalIdentityServices')}
              <div className="text-xs text-white/60">{t('governmentOfIndia')}</div>
            </div>
          </div>
          <nav className="hidden md:flex items-center gap-1">
            {tabs.map(t => (
              <Link
                key={t.to}
                to={t.to}
                className={`px-3 py-1.5 rounded-md hover:bg-white/10 ${pathname === t.to ? 'bg-white/10' : ''}`}
              >
                {t.label}
              </Link>
            ))}
          </nav>
          <div className="flex items-center gap-3">
            <LanguageDropdown />
            <span className="px-2 py-1 rounded-full text-xs bg-white/10 border border-white/20 text-slate-200">{t('network')}: Ethereum Sepolia</span>
            <WalletConnectButton />
          </div>
        </div>
      </header>
      <MyGovNav />
      <main className="mx-auto max-w-6xl px-4 py-6">
        <Outlet />
      </main>
      <footer className="mx-auto max-w-6xl px-4 py-8 text-center text-sm text-white/50">
        {t('footerText')}
      </footer>
      <ChatBot />
    </div>
  )
}

function LanguageDropdown() {
  const { language, setLanguage } = useLanguage()
  const [isOpen, setIsOpen] = useState(false)

  const currentLanguage = languageOptions.find(lang => lang.code === language)

  return (
    <div className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-2 px-3 py-1.5 rounded-md bg-white/10 border border-white/20 hover:bg-white/20 text-sm transition-colors"
      >
        <span className="text-xs">🌐</span>
        <span>{currentLanguage?.nativeName}</span>
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      
      {isOpen && (
        <div className="absolute right-0 mt-2 w-48 bg-slate-800 border border-white/20 rounded-lg shadow-lg z-50 max-h-64 overflow-y-auto">
          {languageOptions.map((lang) => (
            <button
              key={lang.code}
              onClick={() => {
                setLanguage(lang.code)
                setIsOpen(false)
              }}
              className={`w-full text-left px-3 py-2 text-sm hover:bg-white/10 transition-colors ${
                language === lang.code ? 'bg-white/20 text-brand-400' : 'text-white/90'
              }`}
            >
              <div className="font-medium">{lang.nativeName}</div>
              <div className="text-xs text-white/60">{lang.name}</div>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

export default function App() {
  return (
    <LanguageProvider>
      <AppContent />
    </LanguageProvider>
  )
}

