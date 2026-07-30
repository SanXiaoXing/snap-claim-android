import { useRef, useState } from 'react'
import {
  ChevronLeft, Calendar, ArrowRight,
  TrainFront, Plane, BedDouble, Car, FileText,
  Plus, ScanLine, ImageIcon, Pencil, Trash2, Calculator,
} from 'lucide-react'
import type { InvoiceRecord } from '../types'
import { calcTotals, SUBSIDY_PER_DAY } from '../lib/calc'
import { pickImage, recognizeImage, recognizeFromText, recognizeFromQr } from '../lib/tauri'
import { splitOrderSegments, extractImageHint } from '../services/ocr/imageHint'

interface ReportPageProps {
  records: InvoiceRecord[]
  setRecords: (r: InvoiceRecord[]) => void
  startDate: string
  setStartDate: (d: string) => void
  endDate: string
  setEndDate: (d: string) => void
  claimName: string
  setClaimName: (s: string) => void
  onSave: () => void
  onBack: () => void
}

// 与原型 6 行汇总对齐：火车 / 飞机 / 酒店 / 市内交通 / 往返交通 / 差补
function buildSummaryLines(t: ReturnType<typeof calcTotals>) {
  return [
    { label: '火车', amount: t.train },
    { label: '飞机', amount: t.flight },
    { label: '酒店', amount: t.hotel },
    { label: '市内交通', amount: t.car },
    { label: '往返交通', amount: t.roundTrip ?? 0 },
    { label: '差补', amount: t.subsidy },
  ]
}

function describeRecord(r: InvoiceRecord): { title: string; sub: string; type: 'train' | 'flight' | 'hotel' | 'car' | 'invoice' } {
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
  return {
    type: 'invoice',
    title: r.filename || '发票',
    sub: r.issueDate ?? '',
  }
}

const TYPE_ICON = {
  train: TrainFront, flight: Plane, hotel: BedDouble, car: Car, invoice: FileText,
} as const
const TYPE_BADGE = {
  train: 'badge-train', flight: 'badge-flight', hotel: 'badge-hotel', car: 'badge-car', invoice: 'badge-invoice',
} as const
const TYPE_LABEL = { train: '火车', flight: '飞机', hotel: '酒店', car: '用车', invoice: '发票' } as const

export default function ReportPage({
  records, setRecords, startDate, setStartDate, endDate, setEndDate,
  claimName, setClaimName, onSave, onBack,
}: ReportPageProps) {
  const [showDateModal, setShowDateModal] = useState(false)
  const [fabOpen, setFabOpen] = useState(false)
  const [busy, setBusy] = useState(false)

  const days = (() => {
    if (!startDate || !endDate) return 0
    const s = new Date(startDate).getTime()
    const e = new Date(endDate).getTime()
    if (isNaN(s) || isNaN(e) || e < s) return 0
    return Math.floor((e - s) / 86400000) + 1
  })()

  const totals = calcTotals(records, days)
  const summaryLines = buildSummaryLines(totals)

  const chipCounts = {
    train: records.filter(r => r.type === 'train').length,
    flight: records.filter(r => r.type === 'flight').length,
    hotel: records.filter(r => r.type === 'hotel').length,
    car: records.filter(r => r.type === 'car').length,
  }

  const deleteRecord = (idx: number) => {
    setRecords(records.filter((_, i) => i !== idx))
  }

  // 扫码添加：调原生扫码（M1 用 prompt 模拟），再走 recognize_from_qr
  const onScan = async () => {
    if (busy) return
    setFabOpen(false)
    setBusy(true)
    try {
      const qr = window.prompt('扫码结果（模拟）')
      if (!qr) return
      const rec = await recognizeFromQr(qr, 'scan', 'scan')
      setRecords([...records, rec])
    } catch (e) {
      alert('扫码失败：' + (e as Error).message)
    } finally {
      setBusy(false)
    }
  }

  // 上传图片：dialog.open 选图 → ML Kit OCR 文本 → splitOrderSegments → 逐段识别
  const onUploadImage = async () => {
    if (busy) return
    setFabOpen(false)
    setBusy(true)
    try {
      const uri = await pickImage()
      if (!uri) return
      const text = await recognizeImage(uri)
      const filename = uri.split('/').pop() ?? uri
      const segments = splitOrderSegments(text)

      const newRecs: InvoiceRecord[] = []
      if (segments.length === 0) {
        // 火车票等无订单号的图片：整段文本直接识别
        const rec = await recognizeFromText(text, filename, uri, 1, null)
        newRecs.push(rec)
      } else {
        for (let i = 0; i < segments.length; i++) {
          const seg = segments[i]
          const hint = extractImageHint(seg)
          const rec = await recognizeFromText(seg, filename, uri, i + 1, hint)
          newRecs.push(rec)
        }
      }
      setRecords([...records, ...newRecs])
    } catch (e) {
      alert('识别失败：' + (e as Error).message)
    } finally {
      setBusy(false)
    }
  }

  // 手动添加：M1 用 prompt 输入金额，归为 invoice 类型
  const onManualAdd = () => {
    setFabOpen(false)
    const s = window.prompt('输入金额')
    const amt = s ? parseFloat(s) : NaN
    if (isNaN(amt)) return
    setRecords([...records, {
      type: 'invoice', amount: amt, qrAmount: false,
      filename: 'manual', fullPath: '', pageNumber: records.length + 1,
    }])
  }

  return (
    <div className="min-h-screen flex flex-col relative">
      <header className="topbar flex items-center justify-between px-5 pt-3 pb-3.5">
        <button onClick={onBack} className="icon-btn" aria-label="返回">
          <ChevronLeft size={20} />
        </button>
        <div className="text-[18px] font-bold">报销单</div>
        <button onClick={onSave} className="text-btn" disabled={busy}>保存</button>
      </header>

      <main className="flex-1 overflow-y-auto no-scrollbar px-5 pt-2 pb-28">
        {/* 报销单名称 + 日期区间 */}
        <div className="card p-4 mb-4">
          <div className="mb-4">
            <label className="field-label">报销单名称</label>
            <input
              className="input-line"
              type="text"
              value={claimName}
              onChange={e => setClaimName(e.target.value)}
              placeholder="例如：2026-07 上海出差"
            />
          </div>
          <div>
            <label className="field-label">出差日期</label>
            <div className="flex items-center gap-2 mt-1">
              <button onClick={() => setShowDateModal(true)} className="date-pill">
                <Calendar size={14} style={{ color: 'var(--accent)' }} />
                {startDate || '开始'}
                {startDate && <span>开始</span>}
              </button>
              <ArrowRight size={14} style={{ color: 'var(--fg-soft)' }} />
              <button onClick={() => setShowDateModal(true)} className="date-pill">
                <Calendar size={14} style={{ color: 'var(--accent)' }} />
                {endDate || '结束'}
                {endDate && <span>结束</span>}
              </button>
            </div>
          </div>
        </div>

        {/* 汇总卡：6 行 + 大写金额 */}
        <div className="card summary-card mb-4">
          <div className="flex items-center justify-between mb-3">
            <span className="text-sm font-semibold">报销汇总</span>
            <Calculator size={16} style={{ color: 'var(--fg-muted)' }} />
          </div>
          <div className="summary-total mb-1">¥{totals.total.toFixed(2)}</div>
          <p className="text-xs mb-4" style={{ color: 'var(--fg-muted)' }}>人民币 {totals.chinese}</p>
          <div className="summary-grid">
            {summaryLines.map(line => (
              <div key={line.label} className="flex justify-between">
                <span style={{ color: 'var(--fg-muted)' }}>{line.label}</span>
                <span className="font-semibold tabular-nums">¥{line.amount.toFixed(2)}</span>
              </div>
            ))}
          </div>
          {days > 0 && (
            <div className="mt-3 pt-3 text-xs" style={{ borderTop: '1px solid var(--border)', color: 'var(--fg-muted)' }}>
              差补 = {days} 天 × ¥{SUBSIDY_PER_DAY.toFixed(0)}/天
            </div>
          )}
        </div>

        {/* 明细记录标题 */}
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-sm font-semibold">明细记录（{records.length}）</h3>
          {records.length > 0 && (
            <span className="text-[10px]" style={{ color: 'var(--fg-soft)' }}>左滑删除</span>
          )}
        </div>

        {/* 类别 chip 计数 */}
        {(chipCounts.train + chipCounts.flight + chipCounts.hotel + chipCounts.car) > 0 && (
          <div className="flex items-center gap-2 flex-wrap mb-3">
            {chipCounts.train > 0 && (
              <span className="tag-chip"><span className="dot train" />火车 {chipCounts.train}</span>
            )}
            {chipCounts.flight > 0 && (
              <span className="tag-chip"><span className="dot flight" />飞机 {chipCounts.flight}</span>
            )}
            {chipCounts.hotel > 0 && (
              <span className="tag-chip"><span className="dot hotel" />酒店 {chipCounts.hotel}</span>
            )}
            {chipCounts.car > 0 && (
              <span className="tag-chip"><span className="dot car" />用车 {chipCounts.car}</span>
            )}
          </div>
        )}

        {/* 明细列表（左滑删除） */}
        {records.length === 0 ? (
          <div className="card p-4 text-center text-sm mb-24" style={{ color: 'var(--fg-muted)' }}>
            还没有记录，点右下角 + 添加
          </div>
        ) : (
          <div className="mb-24">
            {records.map((r, idx) => (
              <SwipeRow key={idx} onDelete={() => deleteRecord(idx)}>
                <RecordRow r={r} />
              </SwipeRow>
            ))}
          </div>
        )}
      </main>

      {/* FAB 浮动菜单 */}
      <div
        className={`fab-backdrop ${fabOpen ? 'show' : ''}`}
        onClick={() => setFabOpen(false)}
      />
      <div className={`fab-wrap ${fabOpen ? 'open' : ''}`}>
        <div className="fab-menu">
          <button onClick={onScan} disabled={busy} className="fab-item">
            <span className="fab-item-icon"><ScanLine size={14} /></span>扫码添加
          </button>
          <button onClick={onUploadImage} disabled={busy} className="fab-item">
            <span className="fab-item-icon"><ImageIcon size={14} /></span>上传图片
          </button>
          <button onClick={onManualAdd} disabled={busy} className="fab-item">
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

      {/* 日期选择弹层 */}
      {showDateModal && (
        <div className="fixed inset-0 z-50 flex items-end" onClick={() => setShowDateModal(false)}>
          <div className="absolute inset-0 bg-black/30" />
          <div
            className="card relative w-full p-4 space-y-3"
            style={{ borderRadius: '16px 16px 0 0' }}
            onClick={e => e.stopPropagation()}
          >
            <div className="font-medium text-sm">选择出差日期</div>
            <label className="block text-xs" style={{ color: 'var(--fg-muted)' }}>
              开始
              <input
                type="date"
                value={startDate}
                onChange={e => setStartDate(e.target.value)}
                className="mt-1 w-full px-3 py-2 rounded-lg border bg-transparent"
                style={{ borderColor: 'var(--border)', color: 'var(--fg)' }}
              />
            </label>
            <label className="block text-xs" style={{ color: 'var(--fg-muted)' }}>
              结束
              <input
                type="date"
                value={endDate}
                onChange={e => setEndDate(e.target.value)}
                className="mt-1 w-full px-3 py-2 rounded-lg border bg-transparent"
                style={{ borderColor: 'var(--border)', color: 'var(--fg)' }}
              />
            </label>
            <button onClick={() => setShowDateModal(false)} className="btn-primary py-2 text-sm">确定</button>
          </div>
        </div>
      )}
    </div>
  )
}

function RecordRow({ r }: { r: InvoiceRecord }) {
  const { title, sub, type } = describeRecord(r)
  const Icon = TYPE_ICON[type]
  return (
    <div className="rec-row">
      <div className={`rec-icon ${type}`}><Icon size={16} /></div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold truncate">{title || '—'}</p>
        <p className="text-xs truncate" style={{ color: 'var(--fg-muted)' }}>{sub}</p>
      </div>
      <div className="text-right">
        <p className="text-sm font-semibold tabular-nums">¥{(r.amount ?? 0).toFixed(2)}</p>
        <span className={`badge ${TYPE_BADGE[type]} mt-1`}>{TYPE_LABEL[type]}</span>
      </div>
    </div>
  )
}

// 左滑删除（touch + mouse，对齐原型 initSwipe；用 transform 平移避免每帧 re-render）
function SwipeRow({ children, onDelete }: { children: React.ReactNode; onDelete: () => void }) {
  const contentRef = useRef<HTMLDivElement>(null)
  const stateRef = useRef({ startX: 0, current: 0, dragging: false, isOpen: false })

  const start = (x: number) => {
    stateRef.current.startX = x
    stateRef.current.dragging = true
    if (contentRef.current) contentRef.current.style.transition = 'none'
  }
  const move = (x: number) => {
    if (!stateRef.current.dragging) return
    const delta = x - stateRef.current.startX
    if (delta < 0) {
      stateRef.current.current = Math.max(delta, -88)
      if (contentRef.current) contentRef.current.style.transform = `translateX(${stateRef.current.current}px)`
    }
  }
  const end = () => {
    if (!stateRef.current.dragging) return
    stateRef.current.dragging = false
    if (contentRef.current) contentRef.current.style.transition = 'transform .22s cubic-bezier(0.16, 1, 0.3, 1)'
    if (stateRef.current.current < -44) {
      if (contentRef.current) contentRef.current.style.transform = 'translateX(-88px)'
      stateRef.current.isOpen = true
    } else {
      if (contentRef.current) contentRef.current.style.transform = 'translateX(0)'
      stateRef.current.isOpen = false
    }
  }

  return (
    <div className="swipe-row">
      <div className="swipe-bg" onClick={onDelete}>
        <Trash2 size={16} />删除
      </div>
      <div
        ref={contentRef}
        className="swipe-content"
        onTouchStart={e => start(e.touches[0].clientX)}
        onTouchMove={e => move(e.touches[0].clientX)}
        onTouchEnd={end}
        onMouseDown={e => start(e.clientX)}
        onMouseMove={e => stateRef.current.dragging && move(e.clientX)}
        onMouseUp={end}
        onMouseLeave={() => stateRef.current.dragging && end()}
      >
        {children}
      </div>
    </div>
  )
}
