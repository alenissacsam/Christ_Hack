import { Link } from 'react-router-dom'
import { useLanguage } from '../contexts/LanguageContext'

export default function MyGovTabs() {
  const { t } = useLanguage()
  const tabs = [
    { to: '/wizard?step=aadhaar', label: t('discuss'), img: '/images/tab-discuss.svg' },
    { to: '/wizard?step=face', label: t('do'), img: '/images/tab-do.svg' },
    { to: '/poll-survey', label: t('pollSurvey'), img: '/images/tab-poll.svg' },
    { to: '/', label: t('blog'), img: '/images/tab-blog.svg' },
    { to: '#talk', label: t('talk'), img: '/images/tab-talk.svg' },
  ]
return (
    <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
      {tabs.map((t) => (
        <Link key={t.label} to={t.to} onClick={(e)=>{ if(t.to==='#talk'){ e.preventDefault(); window.dispatchEvent(new CustomEvent('open-chat')) } }} className="group bg-white/5 border border-white/10 rounded-lg px-4 py-3 flex items-center gap-3 hover:bg-white/10">
          <img src={t.img} alt="" className="h-7 w-7" />
          <span className="text-sm font-medium">{t.label}</span>
        </Link>
      ))}
    </div>
  )
}
