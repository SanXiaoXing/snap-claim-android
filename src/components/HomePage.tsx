import { useEffect, useState } from 'react'
import { Bell, PlusCircle, Briefcase, ChevronRight } from 'lucide-react'
import type { HistorySummary } from '../types'
import { getHistoryList } from '../lib/tauri'

interface HomePageProps {
  onCreate: () => void
  onOpenHistory: (id: number) => void
  onShowAll: () => void
}

// ponytail: 取最近 5 条作为首页快速入口；列表页才是完整历史
export default function HomePage({ onCreate, onOpenHistory, onShowAll }: HomePageProps) {
  const [recent, setRecent] = useState<HistorySummary[] | null>(null)

  useEffect(() => {
    getHistoryList()
      .then(list => setRecent(list.slice(0, 5)))
      .catch(() => setRecent([]))
  }, [])

  const greeting = (() => {
    const h = new Date().getHours()
    if (h < 6) return '夜深了，还在忙吗？'
    if (h < 12) return '早上好，今天有什么要报销？'
    if (h < 14) return '中午好，先休息一下吧。'
    if (h < 18) return '下午好，准备开始报销了吗？'
    return '晚上好，今天辛苦了。'
  })()

  return (
    <div className="min-h-screen flex flex-col">
      {/* 顶部栏 */}
      <header className="topbar flex items-center justify-between px-5 pt-3 pb-3.5">
        <div style={{ minWidth: 36 }} />
        <div className="font-title text-[18px] font-bold">SnapClaim</div>
        <button className="icon-btn" aria-label="通知">
          <Bell size={16} />
        </button>
      </header>

      <main className="flex-1 overflow-y-auto no-scrollbar px-5 pt-2 pb-24">
        <div className="mb-5">
          <p className="text-sm" style={{ color: 'var(--fg-muted)' }}>{greeting}</p>
          <h2 className="text-2xl font-bold mt-1">新建报销单</h2>
        </div>

        <button onClick={onCreate} className="btn-primary mb-6">
          <PlusCircle size={20} /> 创建报销单
        </button>

        <div className="flex items-center justify-between mb-3">
          <h3 className="text-sm font-semibold">最近报销单</h3>
          {recent && recent.length > 0 && (
            <button onClick={onShowAll} className="text-xs" style={{ color: 'var(--fg-soft)', background: 'none', border: 'none', cursor: 'pointer' }}>
              查看全部
            </button>
          )}
        </div>

        {recent === null ? (
          <div className="text-center py-6 text-sm" style={{ color: 'var(--fg-soft)' }}>加载中…</div>
        ) : recent.length === 0 ? (
          <div className="card p-4 text-center text-sm" style={{ color: 'var(--fg-muted)' }}>
            还没有报销单，点击上方按钮创建第一张。
          </div>
        ) : (
          <div className="space-y-3 mb-4">
            {recent.map((h, i) => (
              <button
                key={h.id}
                onClick={() => onOpenHistory(h.id)}
                className="card row-enter w-full text-left"
                style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px', animationDelay: `${i * 0.04}s`, cursor: 'pointer' }}
              >
                <div
                  className="rec-icon"
                  style={{ width: 44, height: 44, borderRadius: 12, background: 'var(--accent-bg)', color: 'var(--accent)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}
                >
                  <Briefcase size={20} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold truncate">{h.name || '未命名'}</p>
                  <p className="text-xs truncate" style={{ color: 'var(--fg-muted)' }}>
                    {h.days} 天{h.startDate && h.endDate ? ` · ${h.startDate}~${h.endDate}` : ''}
                  </p>
                </div>
                <span className="text-sm font-bold" style={{ color: 'var(--accent)' }}>¥{h.totals.total.toFixed(0)}</span>
                <ChevronRight size={16} style={{ color: 'var(--fg-soft)' }} />
              </button>
            ))}
          </div>
        )}

        <div className="card p-4 mt-2" style={{ background: 'var(--accent-bg)', borderColor: 'transparent' }}>
          <p className="text-xs font-medium" style={{ color: 'var(--accent)' }}>提示</p>
          <p className="text-sm mt-1" style={{ color: 'var(--fg)' }}>点击上方按钮创建新报销单，或从最近记录中打开已有单据继续编辑。</p>
        </div>
      </main>
    </div>
  )
}
