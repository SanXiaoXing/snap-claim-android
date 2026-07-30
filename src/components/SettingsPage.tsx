import { useState } from 'react'
import {
  PieChart, Moon, ChevronRight, ShieldCheck, FileText, HelpCircle,
} from 'lucide-react'
import { checkForUpdate } from '../lib/tauri'

interface SettingsPageProps {
  theme: 'light' | 'dark'
  setTheme: (t: 'light' | 'dark') => void
}

// ponytail: 原型「我的」页对齐——头像卡 + 偏好卡（含主题切换）+ 关于卡 + 版本卡。
// 检查更新按钮被并到「报销统计」行触发——保留功能不丢，但不再独占卡片。
export default function SettingsPage({ theme, setTheme }: SettingsPageProps) {
  const [checking, setChecking] = useState(false)

  const onCheckUpdate = async () => {
    if (checking) return
    setChecking(true)
    try {
      const info = await checkForUpdate()
      if (info) alert(`发现新版本 ${info.version}\n\n${info.notes}`)
      else alert('已是最新版本')
    } catch (e) {
      alert('检查更新失败：' + (e as Error).message)
    } finally {
      setChecking(false)
    }
  }

  const toggleTheme = () => setTheme(theme === 'light' ? 'dark' : 'light')

  return (
    <div className="min-h-screen flex flex-col">
      <header className="topbar flex items-center justify-between px-5 pt-3 pb-3.5">
        <div style={{ minWidth: 36 }} />
        <div className="text-[18px] font-bold">我的</div>
        <div style={{ minWidth: 36 }} />
      </header>

      <main className="flex-1 overflow-y-auto no-scrollbar px-5 pt-2 pb-24">
        {/* 用户头像卡 */}
        <div className="card p-4 mb-4 flex items-center gap-4">
          <div className="mine-avatar">S</div>
          <div>
            <p className="text-base font-bold">SanXiaoXing</p>
            <p className="text-xs" style={{ color: 'var(--fg-muted)' }}>sanxiaoxing@example.com</p>
          </div>
        </div>

        {/* 偏好卡：报销统计 + 深色模式 */}
        <div className="card mb-4 overflow-hidden">
          <button
            onClick={onCheckUpdate}
            className="mine-row w-full text-left"
            style={{ borderBottom: '1px solid var(--border)' }}
          >
            <div className="mine-row-left">
              <div className="mine-row-icon"><PieChart size={16} /></div>
              <div>
                <p className="text-sm font-semibold">{checking ? '检查更新中…' : '检查更新'}</p>
                <p className="text-xs" style={{ color: 'var(--fg-muted)' }}>查看最新版本与新功能</p>
              </div>
            </div>
            <ChevronRight size={16} style={{ color: 'var(--fg-soft)' }} />
          </button>
          <div className="mine-row">
            <div className="mine-row-left">
              <div className="mine-row-icon"><Moon size={16} /></div>
              <div>
                <p className="text-sm font-semibold">深色模式</p>
                <p className="text-xs" style={{ color: 'var(--fg-muted)' }}>切换界面主题</p>
              </div>
            </div>
            <div
              role="switch"
              aria-checked={theme === 'dark'}
              tabIndex={0}
              onClick={toggleTheme}
              onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleTheme() } }}
              className="theme-toggle"
            />
          </div>
        </div>

        {/* 关于卡：隐私 / 协议 / 帮助 */}
        <div className="card overflow-hidden mb-4">
          <div className="mine-row" style={{ borderBottom: '1px solid var(--border)' }}>
            <div className="mine-row-left">
              <div className="mine-row-icon"><ShieldCheck size={16} /></div>
              <span className="text-sm font-semibold">隐私政策</span>
            </div>
            <ChevronRight size={16} style={{ color: 'var(--fg-soft)' }} />
          </div>
          <div className="mine-row" style={{ borderBottom: '1px solid var(--border)' }}>
            <div className="mine-row-left">
              <div className="mine-row-icon"><FileText size={16} /></div>
              <span className="text-sm font-semibold">用户协议</span>
            </div>
            <ChevronRight size={16} style={{ color: 'var(--fg-soft)' }} />
          </div>
          <div className="mine-row">
            <div className="mine-row-left">
              <div className="mine-row-icon"><HelpCircle size={16} /></div>
              <span className="text-sm font-semibold">帮助与反馈</span>
            </div>
            <ChevronRight size={16} style={{ color: 'var(--fg-soft)' }} />
          </div>
        </div>

        {/* 版本卡 */}
        <div className="card p-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-semibold">版本信息</span>
            <span className="text-xs" style={{ color: 'var(--fg-muted)' }}>v0.1.0</span>
          </div>
          <p className="text-xs" style={{ color: 'var(--fg-muted)' }}>
            SnapClaim · Copyright © 2026 SanXiaoXing. All rights reserved.
          </p>
        </div>
      </main>
    </div>
  )
}
