import { useEffect, useState } from 'react'
import { Home, Archive, User } from 'lucide-react'
import HomePage from './components/HomePage'
import ReportPage from './components/ReportPage'
import HistoryListPage from './components/HistoryListPage'
import HistoryDetailPage from './components/HistoryDetailPage'
import SettingsPage from './components/SettingsPage'
import { saveHistory } from './lib/tauri'
import { calcTotals, buildPreviewRows } from './lib/calc'
import type { InvoiceRecord } from './types'
import './styles/globals.css'

// ponytail: 'report' 不是底部 Tab，而是从首页「创建报销单」进入的子屏。
// 保留在联合类型里以便条件渲染；Tab Bar 只显示 home/history/settings 三个。
type Tab = 'home' | 'report' | 'history' | 'settings'
type Theme = 'light' | 'dark'

function App() {
  const [tab, setTab] = useState<Tab>('home')
  const [theme, setTheme] = useState<Theme>(() => (localStorage.getItem('theme') as Theme) || 'light')
  const [records, setRecords] = useState<InvoiceRecord[]>([])
  const [claimName, setClaimName] = useState('')
  const [startDate, setStartDate] = useState('')
  const [endDate, setEndDate] = useState('')
  const [historyDetailId, setHistoryDetailId] = useState<number | null>(null)

  // ponytail: 主题切换 → 写到 <html data-theme>，CSS 变量自动级联。
  // localStorage 持久化用户偏好，无系统偏好跟随（保持简单，原型亦无）。
  useEffect(() => {
    document.documentElement.dataset.theme = theme
    localStorage.setItem('theme', theme)
  }, [theme])

  // 计算天数（含首尾）
  const days = (() => {
    if (!startDate || !endDate) return 0
    const s = new Date(startDate).getTime()
    const e = new Date(endDate).getTime()
    if (isNaN(s) || isNaN(e) || e < s) return 0
    return Math.floor((e - s) / 86400000) + 1
  })()

  const handleSave = async () => {
    if (records.length === 0) {
      alert('没有记录可保存')
      return
    }
    try {
      const totals = calcTotals(records, days)
      const previewRows = buildPreviewRows(records, days)
      await saveHistory(
        records,
        totals,
        previewRows,
        startDate || null,
        endDate || null,
        days,
      )
      alert('保存成功')
      setRecords([])
      setClaimName('')
      setStartDate('')
      setEndDate('')
      setTab('home')
    } catch (e) {
      alert('保存失败: ' + (e instanceof Error ? e.message : String(e)))
    }
  }

  // 从首页「创建报销单」进入编辑器：清空草稿，切到 report tab
  const handleCreate = () => {
    setRecords([])
    setClaimName('')
    setStartDate('')
    setEndDate('')
    setTab('report')
  }

  // 历史详情屏：覆盖整个视图（无 Tab Bar）
  if (historyDetailId !== null) {
    return (
      <HistoryDetailPage
        id={historyDetailId}
        onBack={() => setHistoryDetailId(null)}
      />
    )
  }

  return (
    <div className="min-h-screen flex flex-col">
      <main className="flex-1 overflow-y-auto pb-24">
        {tab === 'home' && (
          <HomePage
            onCreate={handleCreate}
            onOpenHistory={(id: number) => setHistoryDetailId(id)}
            onShowAll={() => setTab('history')}
          />
        )}
        {tab === 'report' && (
          <ReportPage
            records={records}
            setRecords={setRecords}
            startDate={startDate}
            setStartDate={setStartDate}
            endDate={endDate}
            setEndDate={setEndDate}
            claimName={claimName}
            setClaimName={setClaimName}
            onSave={handleSave}
            onBack={() => setTab('home')}
          />
        )}
        {tab === 'history' && (
          <HistoryListPage onOpen={(id: number) => setHistoryDetailId(id)} />
        )}
        {tab === 'settings' && (
          <SettingsPage theme={theme} setTheme={setTheme} />
        )}
      </main>

      {/* 底部 Tab Bar */}
      <nav className="tabbar fixed bottom-0 left-0 right-0">
        <TabItem icon={<Home size={20} />} label="首页" active={tab === 'home'} onClick={() => setTab('home')} />
        <TabItem icon={<Archive size={20} />} label="历史" active={tab === 'history'} onClick={() => setTab('history')} />
        <TabItem icon={<User size={20} />} label="我的" active={tab === 'settings'} onClick={() => setTab('settings')} />
      </nav>
    </div>
  )
}

function TabItem({
  icon, label, active, onClick,
}: { icon: React.ReactNode; label: string; active: boolean; onClick: () => void }) {
  return (
    <button onClick={onClick} className={`tab ${active ? 'active' : ''}`}>
      {icon}
      <span>{label}</span>
    </button>
  )
}

export default App
