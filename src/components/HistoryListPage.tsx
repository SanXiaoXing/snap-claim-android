import { useEffect, useMemo, useState } from 'react'
import { Search, Briefcase } from 'lucide-react'
import type { HistorySummary } from '../types'
import { getHistoryList } from '../lib/tauri'

interface HistoryListPageProps {
  onOpen: (id: number) => void
}

// ponytail: 原型历史页是极简 recent-card（缩略图 + 名称 + 备注 + 金额），
// 不带逐类徽标——逐类徽标在详情页才有意义，列表页只是入口。
function monthKey(iso: string): string {
  const d = new Date(iso)
  if (isNaN(d.getTime())) return '其他'
  return `${d.getFullYear()} 年 ${d.getMonth() + 1} 月`
}

export default function HistoryListPage({ onOpen }: HistoryListPageProps) {
  const [list, setList] = useState<HistorySummary[] | null>(null)
  const [showSearch, setShowSearch] = useState(false)
  const [query, setQuery] = useState('')

  useEffect(() => {
    getHistoryList()
      .then(setList)
      .catch(e => { alert('加载失败：' + (e as Error).message); setList([]) })
  }, [])

  const filtered = useMemo(() => {
    if (!list) return []
    const q = query.trim().toLowerCase()
    if (!q) return list
    return list.filter(h => (h.name + ' ' + (h.remark ?? '')).toLowerCase().includes(q))
  }, [list, query])

  const groups = useMemo(() => {
    const m = new Map<string, HistorySummary[]>()
    for (const h of filtered) {
      const k = monthKey(h.createdAt)
      const arr = m.get(k) ?? []
      arr.push(h)
      m.set(k, arr)
    }
    return Array.from(m.entries())
  }, [filtered])

  return (
    <div className="min-h-screen flex flex-col">
      <header className="topbar flex items-center justify-between px-5 pt-3 pb-3.5">
        <div style={{ minWidth: 36 }} />
        <div className="text-[18px] font-bold">历史记录</div>
        <button
          onClick={() => setShowSearch(v => !v)}
          className="icon-btn"
          aria-label="搜索"
        >
          <Search size={16} />
        </button>
      </header>

      <main className="flex-1 overflow-y-auto no-scrollbar px-5 pt-1 pb-24">
        {showSearch && (
          <input
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="搜索名称或备注"
            className="card w-full px-3 py-2 text-sm mb-3 outline-none"
            style={{ background: 'var(--bg-secondary)', borderColor: 'var(--border)' }}
          />
        )}

        {list === null ? (
          <div className="text-center py-10 text-sm" style={{ color: 'var(--fg-soft)' }}>加载中…</div>
        ) : groups.length === 0 ? (
          <div className="text-center py-10 text-sm" style={{ color: 'var(--fg-soft)' }}>
            {query ? '无匹配结果' : '暂无历史记录'}
          </div>
        ) : (
          groups.map(([month, items]) => (
            <div key={month} className="mb-5">
              <div className="text-xs font-semibold mb-2 px-1" style={{ color: 'var(--fg-muted)' }}>
                {month}
              </div>
              <div className="space-y-3">
                {items.map((h, i) => (
                  <button
                    key={h.id}
                    onClick={() => onOpen(h.id)}
                    className="card row-enter w-full text-left"
                    style={{
                      display: 'flex', alignItems: 'center', gap: 12,
                      padding: '14px 16px',
                      animationDelay: `${i * 0.04}s`,
                      cursor: 'pointer',
                    }}
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
                        {h.remark ? h.remark + ' · ' : ''}{h.days} 天
                        {h.startDate && h.endDate ? ` · ${h.startDate}~${h.endDate}` : ''}
                      </p>
                    </div>
                    <span className="text-base font-bold" style={{ color: 'var(--accent)' }}>
                      ¥{h.totals.total.toFixed(0)}
                    </span>
                  </button>
                ))}
              </div>
            </div>
          ))
        )}
      </main>
    </div>
  )
}
