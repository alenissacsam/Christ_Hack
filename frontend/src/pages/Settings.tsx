import { useConfigStore, CONTRACT_KEYS } from '../store/config'
import { useState } from 'react'
import { useLanguage } from '../contexts/LanguageContext'

export default function Settings() {
  const { chainId, setChainId, addresses, setAddress } = useConfigStore()
  const [local, setLocal] = useState(addresses)
  const { t } = useLanguage()
  
  // User preferences state
  const [userPrefs, setUserPrefs] = useState({
    enableNotifications: true,
    dataCollection: false,
    shareWithGov: true,
    autoDelete: false,
    acceptLiability: false,
    agreeTerms: false
  })

  function save() {
    CONTRACT_KEYS.forEach((k) => {
      const v = (local as any)[k] || ''
      if (v) setAddress(k, v)
    })
    // Save user preferences to localStorage
    localStorage.setItem('userPreferences', JSON.stringify(userPrefs))
    alert(t('saved'))
  }
  
  function handlePreferenceChange(key: string, value: boolean) {
    setUserPrefs(prev => ({ ...prev, [key]: value }))
  }

  return (
    <div className="space-y-6">
      <section className="relative overflow-hidden rounded-xl">
        <img src="/images/settings.svg" alt="Settings" className="absolute inset-0 h-32 w-full object-cover opacity-20" />
        <div className="relative h-32 grid content-center p-4 bg-gradient-to-r from-[#0b1f3a]/60 to-transparent text-white">
          <div className="text-lg font-semibold">{t('settingsTitle')}</div>
          <div className="text-xs opacity-90">{t('networkSettings')}</div>
        </div>
      </section>
      {/* User Preferences Section */}
      <section className="glass p-4 rounded-lg border border-white/10">
        <div className="font-semibold mb-4">{t('userPreferences')}</div>
        <div className="space-y-4">
          {/* Privacy Settings */}
          <div>
            <h3 className="font-medium mb-3 text-white/90">{t('privacySettings')}</h3>
            <div className="space-y-3">
              <label className="flex items-center justify-between">
                <span className="text-sm text-white/80">{t('dataCollection')}</span>
                <input
                  type="checkbox"
                  checked={userPrefs.dataCollection}
                  onChange={(e) => handlePreferenceChange('dataCollection', e.target.checked)}
                  className="w-4 h-4 text-brand-600 bg-white/10 border-white/20 rounded focus:ring-brand-500 focus:ring-2"
                />
              </label>
              <label className="flex items-center justify-between">
                <span className="text-sm text-white/80">{t('shareWithGov')}</span>
                <input
                  type="checkbox"
                  checked={userPrefs.shareWithGov}
                  onChange={(e) => handlePreferenceChange('shareWithGov', e.target.checked)}
                  className="w-4 h-4 text-brand-600 bg-white/10 border-white/20 rounded focus:ring-brand-500 focus:ring-2"
                />
              </label>
            </div>
          </div>
          
          {/* Notification Settings */}
          <div>
            <h3 className="font-medium mb-3 text-white/90">{t('notificationSettings')}</h3>
            <label className="flex items-center justify-between">
              <span className="text-sm text-white/80">{t('enableNotifications')}</span>
              <input
                type="checkbox"
                checked={userPrefs.enableNotifications}
                onChange={(e) => handlePreferenceChange('enableNotifications', e.target.checked)}
                className="w-4 h-4 text-brand-600 bg-white/10 border-white/20 rounded focus:ring-brand-500 focus:ring-2"
              />
            </label>
          </div>
          
          {/* Data Retention */}
          <div>
            <h3 className="font-medium mb-3 text-white/90">{t('dataRetention')}</h3>
            <label className="flex items-center justify-between">
              <span className="text-sm text-white/80">{t('autoDelete')}</span>
              <input
                type="checkbox"
                checked={userPrefs.autoDelete}
                onChange={(e) => handlePreferenceChange('autoDelete', e.target.checked)}
                className="w-4 h-4 text-brand-600 bg-white/10 border-white/20 rounded focus:ring-brand-500 focus:ring-2"
              />
            </label>
          </div>
          
          {/* Liability & Legal */}
          <div>
            <h3 className="font-medium mb-3 text-white/90">{t('liabilitySettings')}</h3>
            <div className="space-y-3">
              <label className="flex items-start gap-3">
                <input
                  type="checkbox"
                  checked={userPrefs.acceptLiability}
                  onChange={(e) => handlePreferenceChange('acceptLiability', e.target.checked)}
                  className="w-4 h-4 text-brand-600 bg-white/10 border-white/20 rounded focus:ring-brand-500 focus:ring-2 mt-0.5"
                />
                <div className="text-sm">
                  <span className="text-white/80">{t('acceptLiability')}</span>
                  <p className="text-xs text-white/60 mt-1">
                    By checking this, you acknowledge that you are responsible for the accuracy and authenticity of the information you provide.
                  </p>
                </div>
              </label>
              <label className="flex items-start gap-3">
                <input
                  type="checkbox"
                  checked={userPrefs.agreeTerms}
                  onChange={(e) => handlePreferenceChange('agreeTerms', e.target.checked)}
                  className="w-4 h-4 text-brand-600 bg-white/10 border-white/20 rounded focus:ring-brand-500 focus:ring-2 mt-0.5"
                />
                <div className="text-sm">
                  <span className="text-white/80">{t('agreeTerms')}</span>
                  <p className="text-xs text-white/60 mt-1">
                    You agree to comply with all applicable laws and regulations while using this digital identity platform.
                  </p>
                </div>
              </label>
            </div>
          </div>
        </div>
      </section>

      <section className="glass p-4 rounded-lg border border-white/10">
        <div className="font-semibold mb-3">{t('network')} (Ethereum Sepolia)</div>
        <label className="block text-sm">
          <div className="mb-1 text-white/70">Chain ID</div>
          <input
            className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10 text-white placeholder-white/50"
            type="number"
            value={chainId}
            onChange={(e) => setChainId(parseInt(e.target.value || '0', 10))}
          />
        </label>
      </section>

      <section className="glass p-4 rounded-lg border border-white/10">
        <div className="font-semibold mb-3">Service Addresses (Advanced)</div>
        <div className="grid md:grid-cols-2 gap-3">
          {CONTRACT_KEYS.map((key) => (
            <label key={key} className="block text-sm">
              <div className="mb-1 text-white/70">{key}</div>
              <input
                className="w-full px-3 py-2 rounded-md bg-white/5 border border-white/10 text-white placeholder-white/50"
                placeholder="0x..."
                value={(local as any)[key] || ''}
                onChange={(e) => setLocal((s) => ({ ...s, [key]: e.target.value }))}
              />
            </label>
          ))}
        </div>
        <div className="mt-4">
          <button className="px-4 py-2 rounded-md bg-brand-600 hover:bg-brand-700" onClick={save}>{t('save')}</button>
        </div>
      </section>

      <section className="glass p-4 rounded-lg border border-white/10 text-sm text-white/70">
        <div className="font-semibold mb-2">Help</div>
        <ul className="list-disc pl-5 space-y-1">
          <li>Paste deployed addresses for each service above.</li>
          <li>Chain ID for Sepolia is 11155111.</li>
          <li>Optional: set VITE_WALLETCONNECT_PROJECT_ID in a .env to enable WalletConnect.</li>
        </ul>
      </section>
    </div>
  )
}

