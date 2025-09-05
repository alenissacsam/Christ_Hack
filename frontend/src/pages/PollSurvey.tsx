import { useLanguage } from '../contexts/LanguageContext'

// Simple SVG-based chart components since we couldn't install chart libraries
const PieChart = ({ data, colors }: { data: { label: string; value: number; percentage: number }[], colors: string[] }) => {
  let currentAngle = 0
  const radius = 80
  const centerX = 100
  const centerY = 100

  const createPath = (startAngle: number, endAngle: number) => {
    const start = {
      x: centerX + radius * Math.cos((startAngle * Math.PI) / 180),
      y: centerY + radius * Math.sin((startAngle * Math.PI) / 180),
    }
    const end = {
      x: centerX + radius * Math.cos((endAngle * Math.PI) / 180),
      y: centerY + radius * Math.sin((endAngle * Math.PI) / 180),
    }
    
    const largeArcFlag = endAngle - startAngle <= 180 ? '0' : '1'
    
    return `M ${centerX} ${centerY} L ${start.x} ${start.y} A ${radius} ${radius} 0 ${largeArcFlag} 1 ${end.x} ${end.y} Z`
  }

  return (
    <div className="flex items-center gap-8">
      <svg width="200" height="200" viewBox="0 0 200 200" className="drop-shadow-lg">
        {data.map((item, index) => {
          const startAngle = currentAngle
          const sliceAngle = (item.percentage / 100) * 360
          const endAngle = currentAngle + sliceAngle
          currentAngle += sliceAngle

          return (
            <path
              key={index}
              d={createPath(startAngle, endAngle)}
              fill={colors[index]}
              stroke="rgba(255, 255, 255, 0.2)"
              strokeWidth="2"
              className="hover:opacity-80 transition-opacity"
            />
          )
        })}
        <circle cx={centerX} cy={centerY} r="30" fill="rgba(0, 0, 0, 0.1)" />
      </svg>
      
      <div className="space-y-3">
        {data.map((item, index) => (
          <div key={index} className="flex items-center gap-3">
            <div 
              className="w-4 h-4 rounded-sm"
              style={{ backgroundColor: colors[index] }}
            />
            <div className="text-sm">
              <div className="font-medium text-white">{item.label}</div>
              <div className="text-white/60">{item.value.toLocaleString()} ({item.percentage}%)</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

const BarChart = ({ data, colors }: { data: { label: string; value: number }[], colors: string[] }) => {
  const maxValue = Math.max(...data.map(item => item.value))
  
  return (
    <div className="space-y-4">
      {data.map((item, index) => {
        const percentage = (item.value / maxValue) * 100
        return (
          <div key={index} className="space-y-2">
            <div className="flex justify-between items-center">
              <span className="text-sm font-medium text-white">{item.label}</span>
              <span className="text-sm text-white/60">{item.value.toLocaleString()}</span>
            </div>
            <div className="w-full bg-white/10 rounded-full h-6 overflow-hidden">
              <div
                className="h-full rounded-full transition-all duration-500 flex items-center justify-end pr-3"
                style={{ 
                  width: `${percentage}%`, 
                  backgroundColor: colors[index] 
                }}
              >
                <span className="text-xs font-medium text-white drop-shadow">
                  {Math.round(percentage)}%
                </span>
              </div>
            </div>
          </div>
        )
      })}
    </div>
  )
}

export default function PollSurvey() {
  const { t } = useLanguage()
  
  // Hardcoded data with Indian colors theme
  const identityData = [
    { label: t('aadhaarHolders'), value: 1350000000, percentage: 68 },
    { label: t('otherIdentityHolders'), value: 480000000, percentage: 24 },
    { label: t('noIdentity'), value: 160000000, percentage: 8 },
  ]
  
  const regionData = [
    { label: 'North India', value: 450000000 },
    { label: 'South India', value: 380000000 },
    { label: 'West India', value: 420000000 },
    { label: 'East India', value: 320000000 },
    { label: 'Northeast India', value: 90000000 },
  ]
  
  // Indian flag inspired colors - saffron, blue, green
  const pieColors = ['#FF9933', '#128807', '#000080'] // Saffron, Green, Navy Blue
  const barColors = ['#FF9933', '#FFFFFF', '#128807', '#000080', '#FF6B6B'] // Adding white and complementary colors
  
  return (
    <div className="space-y-6">
      {/* Header Section */}
      <section className="relative overflow-hidden rounded-xl">
        <img src="/images/settings.svg" alt="Poll Survey" className="absolute inset-0 h-32 w-full object-cover opacity-20" />
        <div className="relative h-32 grid content-center p-4 bg-gradient-to-r from-[#0b1f3a]/60 to-transparent text-white">
          <div className="text-lg font-semibold">{t('identityDistribution')}</div>
          <div className="text-xs opacity-90">Real-time insights into India's digital identity landscape</div>
        </div>
      </section>

      {/* Survey Results Section */}
      <div className="grid md:grid-cols-2 gap-6">
        {/* Identity Distribution Pie Chart */}
        <section className="glass p-6 rounded-lg border border-white/10">
          <div className="mb-6">
            <h2 className="text-xl font-semibold text-white mb-2">{t('identityDistribution')}</h2>
            <p className="text-sm text-white/70">Current distribution of identity document holders across India</p>
          </div>
          
          <PieChart data={identityData} colors={pieColors} />
          
          <div className="mt-6 p-4 bg-white/5 rounded-lg">
            <div className="text-xs text-white/60 mb-2">Survey Details</div>
            <div className="text-sm text-white/80">
              <div>Total Population Surveyed: <span className="font-medium">1.99 Billion</span></div>
              <div>Survey Period: January 2024 - Present</div>
              <div>Confidence Level: 95%</div>
            </div>
          </div>
        </section>

        {/* Regional Distribution Bar Chart */}
        <section className="glass p-6 rounded-lg border border-white/10">
          <div className="mb-6">
            <h2 className="text-xl font-semibold text-white mb-2">Regional Distribution</h2>
            <p className="text-sm text-white/70">Identity document holders by Indian regions</p>
          </div>
          
          <BarChart data={regionData} colors={barColors} />
          
          <div className="mt-6 p-4 bg-white/5 rounded-lg">
            <div className="text-xs text-white/60 mb-2">Methodology</div>
            <div className="text-sm text-white/80">
              <div>Sampling: Random stratified sampling</div>
              <div>Data Collection: Digital and field surveys</div>
              <div>Quality Assurance: Multi-tier verification</div>
            </div>
          </div>
        </section>
      </div>

      {/* Additional Insights */}
      <section className="glass p-6 rounded-lg border border-white/10">
        <h2 className="text-xl font-semibold text-white mb-4">Key Insights</h2>
        <div className="grid md:grid-cols-3 gap-6">
          <div className="text-center">
            <div className="w-16 h-16 mx-auto mb-3 rounded-full bg-gradient-to-r from-[#FF9933] to-[#FF6B35] flex items-center justify-center">
              <span className="text-2xl font-bold text-white">68%</span>
            </div>
            <h3 className="font-medium text-white mb-1">Aadhaar Penetration</h3>
            <p className="text-xs text-white/60">Highest identity verification coverage in the world</p>
          </div>
          
          <div className="text-center">
            <div className="w-16 h-16 mx-auto mb-3 rounded-full bg-gradient-to-r from-[#128807] to-[#20B2AA] flex items-center justify-center">
              <span className="text-2xl font-bold text-white">24%</span>
            </div>
            <h3 className="font-medium text-white mb-1">Alternative IDs</h3>
            <p className="text-xs text-white/60">Using PAN, Voter ID, Passport, or other documents</p>
          </div>
          
          <div className="text-center">
            <div className="w-16 h-16 mx-auto mb-3 rounded-full bg-gradient-to-r from-[#000080] to-[#4169E1] flex items-center justify-center">
              <span className="text-2xl font-bold text-white">8%</span>
            </div>
            <h3 className="font-medium text-white mb-1">No Identity</h3>
            <p className="text-xs text-white/60">Target group for inclusion initiatives</p>
          </div>
        </div>
      </section>

      {/* Survey Participation */}
      <section className="glass p-6 rounded-lg border border-white/10">
        <h2 className="text-xl font-semibold text-white mb-4">Participate in Our Survey</h2>
        <div className="grid md:grid-cols-2 gap-6">
          <div>
            <p className="text-sm text-white/80 mb-4">
              Help us improve India's digital identity infrastructure by sharing your experience and feedback. 
              Your responses are completely anonymous and contribute to policy decisions.
            </p>
            <div className="flex gap-3">
              <button className="px-4 py-2 bg-brand-600 hover:bg-brand-700 rounded-md text-sm font-medium transition-colors">
                Take Survey
              </button>
              <button className="px-4 py-2 bg-white/10 hover:bg-white/20 rounded-md text-sm font-medium transition-colors">
                View Results
              </button>
            </div>
          </div>
          <div className="space-y-3 text-sm">
            <div className="flex justify-between">
              <span className="text-white/70">Survey Duration:</span>
              <span className="text-white">5-7 minutes</span>
            </div>
            <div className="flex justify-between">
              <span className="text-white/70">Languages Available:</span>
              <span className="text-white">22 Indian languages</span>
            </div>
            <div className="flex justify-between">
              <span className="text-white/70">Incentive:</span>
              <span className="text-white">Digital certificate</span>
            </div>
          </div>
        </div>
      </section>
    </div>
  )
}
