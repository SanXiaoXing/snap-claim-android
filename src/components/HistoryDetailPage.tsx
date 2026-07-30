import { useEffect, useState } from 'react'
import {
  ChevronLeft, Share2, Trash2, Calendar, ArrowRight, Calculator,
  TrainFront, Plane, BedDouble, Car, FileText, Plus, ScanLine, ImageIcon, Pencil,
} from 'lucide-react'
import type { HistoryDetail, InvoiceRecord, InvoiceType } from '../types'
import { getHistoryDetail, deleteHistory } from '../lib/tauri'

interface HistoryDetailPageProps {
  id: number
  onBack: () => void
}

const TYPE_ICON: Record<InvoiceType, typeof TrainFront> = {
  train: TrainFront, flight: Plane, hotel: BedDouble, car: Car, invoice: FileText, unknown: FileText,
}
const TYPE_BADGE = {
  train: 'badge-train', flight: 'badge-flight', hotel: 'badge-hotel', car: 'badge-car', invoice: 'badge-invoice',
} as const
const TYPE_LABEL = { train: '火车', flight: '飞机', hotel: '酒店', car: '用车', invoice: '发票' } as const

function describeRecord(r: InvoiceRecord): { title: string; sub: string; type: InvoiceType } {
  if (r.type === 'train') {
    return {
      type: 'train',
      title: `${r.trainNumber ?? ''} ${r.departureStation ?? ''}→${r.arrivalStation ?? ''}`.trim(),
      sub: r.departureTime ?? '',
    }
  }
  if (r.type === 'flight') {
    return {
      type: 'flight',
      title: `${r.flightNumber ?? ''} ${r.departureCity ?? ''}→${r.arrivalCity ?? ''}`.trim(),
      sub: r.flightDate ?? '',
    }
  }
  if (r.type === 'hotel') {
    return {
      type: 'hotel',
      title: r.hotelName ?? '',
      sub: `${r.checkInDate ?? ''}→${r.checkOutDate ?? ''} ${r.nights ?? 0}晚`.trim(),
    }
  }
  if (r.type === 'car') {
    return {
      type: 'car',
      title: r.carDate ? `用车 ${r.carDate}` : '用车',
      sub: r.isRoundTrip ? `${r.mileage ?? 0} km · 往返` : `${r.mileage ?? 0} km`,
    }
  }
  return { type: r.type, title: r.filename || '发票', sub: r.issueDate ?? '' }
}

// 与原型 6 行汇总对齐：火车 / 飞机 / 酒店 / 市内交通 / 往返交通 / 差补
function buildSummaryLines(t: HistoryDetail['totals']) {
  return [
    { label: '火车', amount: t.train },
    { label: '飞机', amount: t.flight },
    { label: '酒店', amount: t.hotel },
    { label: '市内交通', amount: t.car },
    { label: '往返交通', amount: t.roundTrip ?? 0 },
    { label: '差补', amount: t.subsidy },
  ]
}

export default function HistoryDetailPage({ id, onBack }: HistoryDetailPageProps) {
  const [detail, setDetail] = useState<HistoryDetail | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [fabOpen, setFabOpen] = useState(false)

  useEffect(() => {
    getHistoryDetail(id).then(setDetail).catch(e => setError((e as Error).message))
  }, [id])

  // 分享（ponytail: 优先 Web Share API，不可用则降级为 alert 文本）
  const onShare = async () => {
    if (!detail) return
    const text = `${detail.name}\n合计 ¥${detail.totals.total.toFixed(2)}（${detail.totals.chinese}）`
    if (navigator.share) {
      try { await navigator.share({ title: detail.name, text }) } catch { /* 用户取消 */ }
    } else {
      alert(text)
    }
  }

  const onDelete = async () => {
    if (!detail) return
    if (!window.confirm('确定删除该报销单？此操作不可撤销。')) return
    try {
      await deleteHistory(id)
      onBack()
    } catch (e) {
      alert('删除失败：' + (e as Error).message)
    }
  }

  // ponytail: 详情页 FAB 仅作视觉对齐原型——编辑已有报销单需要加载到 ReportPage 的草稿流，
  // 当前未实现；点击给用户明确提示，避免无声无响应。
  const onFabAction = (name: string) => {
    setFabOpen(false)
    alert(`${name}：编辑已有报销单功能待实现`)
  }

  if (error) return (
    <div className="min-h-screen flex flex-col">
      <Header onBack={onBack} title="详情" onShare={() => {}} />
      <div className="text-center py-10" style={{ color: 'var(--danger)' }}>{error}</div>
    </div>
  )

  if (!detail) return (
    <div className="min-h-screen flex flex-col">
      <Header onBack={onBack} title="详情" onShare={() => {}} />
      <div className="text-center py-10" style={{ color: 'var(--fg-soft)' }}>加载中…</div>
    </div>
  )

  const t = detail.totals
  const summaryLines = buildSummaryLines(t)
  const chipCounts = {
    train: detail.records.filter(r => r.type === 'train').length,
    flight: detail.records.filter(r => r.type === 'flight').length,
    hotel: detail.records.filter(r => r.type === 'hotel').length,
    car: detail.records.filter(r => r.type === 'car').length,
  }

  return (
    <div className="min-h-screen flex flex-col relative">
      <Header onBack={onBack} title="报销详情" onShare={onShare} />

      <main className="flex-1 overflow-y-auto no-scrollbar px-5 pt-2 pb-28">
        {/* 名称 + 日期（只读） */}
        <div className="card p-4 mb-4">
          <div className="mb-4">
            <label className="field-label">报销单名称</label>
            <div className="text-[15px] font-semibold py-1.5">{detail.name || '未命名'}</div>
          </div>
          <div>
            <label className="field-label">出差日期</label>
            <div className="flex items-center gap-2 mt-1">
              <div className="date-pill" style={{ cursor: 'default' }}>
                <Calendar size={14} style={{ color: 'var(--accent)' }} />
                {detail.startDate || '—'} {detail.startDate && <span>开始</span>}
              </div>
              <ArrowRight size={14} style={{ color: 'var(--fg-soft)' }} />
              <div className="date-pill" style={{ cursor: 'default' }}>
                <Calendar size={14} style={{ color: 'var(--accent)' }} />
                {detail.endDate || '—'} {detail.endDate && <span>结束</span>}
              </div>
            </div>
          </div>
        </div>

        {/* 汇总卡：6 行 + 大写 */}
        <div className="card summary-card mb-4">
          <div className="flex items-center justify-between mb-3">
            <span className="text-sm font-semibold">报销汇总</span>
            <Calculator size={16} style={{ color: 'var(--fg-muted)' }} />
          </div>
          <div className="summary-total mb-1">¥{t.total.toFixed(2)}</div>
          <p className="text-xs mb-4" style={{ color: 'var(--fg-muted)' }}>人民币 {t.chinese}</p>
          <div className="summary-grid">
            {summaryLines.map(line => (
              <div key={line.label} className="flex justify-between">
                <span style={{ color: 'var(--fg-muted)' }}>{line.label}</span>
                <span className="font-semibold tabular-nums">¥{line.amount.toFixed(2)}</span>
              </div>
            ))}
          </div>
          {detail.days > 0 && (
            <div className="mt-3 pt-3 text-xs" style={{ borderTop: '1px solid var(--border)', color: 'var(--fg-muted)' }}>
              {detail.days} 天
            </div>
          )}
        </div>

        {/* 明细记录标题 */}
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-sm font-semibold">明细记录（{detail.records.length}）</h3>
        </div>

        {/* 类别 chip 计数 */}
        {(chipCounts.train + chipCounts.flight + chipCounts.hotel + chipCounts.car) > 0 && (
          <div className="flex items-center gap-2 flex-wrap mb-3">
            {chipCounts.train > 0 && <span className="tag-chip"><span className="dot train" />火车 {chipCounts.train}</span>}
            {chipCounts.flight > 0 && <span className="tag-chip"><span className="dot flight" />飞机 {chipCounts.flight}</span>}
            {chipCounts.hotel > 0 && <span className="tag-chip"><span className="dot hotel" />酒店 {chipCounts.hotel}</span>}
            {chipCounts.car > 0 && <span className="tag-chip"><span className="dot car" />用车 {chipCounts.car}</span>}
          </div>
        )}

        {/* 平铺明细列表（只读，对齐原型 04 详情页） */}
        {detail.records.length === 0 ? (
          <div className="card p-4 text-center text-sm mb-24" style={{ color: 'var(--fg-muted)' }}>
            无明细记录
          </div>
        ) : (
          <div className="space-y-2.5 mb-24">
            {detail.records.map((r, i) => {
              const { title, sub, type } = describeRecord(r)
              const Icon = TYPE_ICON[type] ?? FileText
              const badgeCls = TYPE_BADGE[type as keyof typeof TYPE_BADGE]
              const label = TYPE_LABEL[type as keyof typeof TYPE_LABEL]
              return (
                <div key={i} className="rec-row">
                  <div className={`rec-icon ${type}`}><Icon size={16} /></div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold truncate">{title || '—'}</p>
                    <p className="text-xs truncate" style={{ color: 'var(--fg-muted)' }}>{sub}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-semibold tabular-nums">¥{(r.amount ?? 0).toFixed(2)}</p>
                    {badgeCls && label && <span className={`badge ${badgeCls} mt-1`}>{label}</span>}
                  </div>
                </div>
              )
            })}
          </div>
        )}

        {/* 备注卡 */}
        {detail.remark && (
          <div className="card p-3 mb-4 flex items-start gap-2">
            <FileText size={16} style={{ color: 'var(--fg-soft)' }} className="mt-0.5 shrink-0" />
            <div className="text-sm whitespace-pre-wrap break-words">{detail.remark}</div>
          </div>
        )}

        {/* 删除按钮（用户偏好：非红色背景，用边框 + 红字） */}
        <button
          onClick={onDelete}
          className="w-full py-3 rounded-2xl text-sm font-medium flex items-center justify-center gap-1"
          style={{
            color: 'var(--danger)',
            border: '1px solid var(--danger)',
            background: 'transparent',
            cursor: 'pointer',
          }}
        >
          <Trash2 size={16} /> 删除该报销单
        </button>
      </main>

      {/* FAB 浮动菜单（视觉对齐原型 04 详情页） */}
      <div
        className={`fab-backdrop ${fabOpen ? 'show' : ''}`}
        onClick={() => setFabOpen(false)}
      />
      <div className={`fab-wrap ${fabOpen ? 'open' : ''}`}>
        <div className="fab-menu">
          <button onClick={() => onFabAction('扫码添加')} className="fab-item">
            <span className="fab-item-icon"><ScanLine size={14} /></span>扫码添加
          </button>
          <button onClick={() => onFabAction('上传图片')} className="fab-item">
            <span className="fab-item-icon"><ImageIcon size={14} /></span>上传图片
          </button>
          <button onClick={() => onFabAction('手动添加')} className="fab-item">
            <span className="fab-item-icon"><Pencil size={14} /></span>手动添加
          </button>
        </div>
        <button
          onClick={() => setFabOpen(v => !v)}
          className="fab-main"
          aria-label="追加记录"
        >
          <Plus size={24} />
        </button>
      </div>
    </div>
  )
}

function Header({ onBack, title, onShare }: { onBack: () => void; title: string; onShare: () => void }) {
  return (
    <header className="topbar flex items-center justify-between px-5 pt-3 pb-3.5">
      <button onClick={onBack} className="icon-btn" aria-label="返回">
        <ChevronLeft size={20} />
      </button>
      <div className="text-[18px] font-bold truncate">{title}</div>
      <button onClick={onShare} className="icon-btn" aria-label="分享">
        <Share2 size={16} />
      </button>
    </header>
  )
}
