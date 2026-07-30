import { invoke, Channel } from '@tauri-apps/api/core'
import { open as openDialog } from '@tauri-apps/plugin-dialog'
import type { InvoiceRecord, Totals, PreviewRow, UpdateInfo, HistorySummary, HistoryDetail } from '../types'

// ── 图片选择（gallery 主路径：dialog.open 在 Android 返回 content:// URI）──
// ponytail: 不用 <input type=file>——Android WebView 返回 blob:// URL，
// Rust 侧 ML Kit 无法解码；dialog 直接返回 content:// URI，零转换。
export async function pickImage(): Promise<string | null> {
  const selected = await openDialog({
    multiple: false,
    filters: [{ name: '图片', extensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'] }],
  })
  return typeof selected === 'string' ? selected : null
}

// content:// URI → 可显示的 src（WebView 可直接渲染 content URI）
export function uriToDisplay(uri: string): string {
  return uri
}

// ── 图片 OCR：URI → ML Kit 文本 ──
export async function recognizeImage(uri: string): Promise<string> {
  try {
    return await invoke<string>('recognize_image_uri', { uri })
  } catch (e) {
    throw new Error(typeof e === 'string' ? e : JSON.stringify(e))
  }
}

// ── 从文本识别单据（与桌面版签名一致）──
export async function recognizeFromText(
  text: string,
  filename: string,
  fullPath: string,
  pageNumber: number,
  imageHint: { orderType: string; orderId: string; amount: number | null } | null = null,
): Promise<InvoiceRecord> {
  try {
    return await invoke<InvoiceRecord>('recognize_from_text', {
      text, filename, fullPath, pageNumber, imageHint,
    })
  } catch (e) {
    throw new Error(typeof e === 'string' ? e : JSON.stringify(e))
  }
}

// ── 扫码路径：QR 字符串 → 记录（移动端新增）──
export async function recognizeFromQr(
  qr: string,
  filename: string,
  fullPath: string,
): Promise<InvoiceRecord> {
  try {
    return await invoke<InvoiceRecord>('recognize_from_qr', { qr, filename, fullPath })
  } catch (e) {
    throw new Error(typeof e === 'string' ? e : JSON.stringify(e))
  }
}

// ── 自动更新（与桌面版逐字相同）──
export async function checkForUpdate(): Promise<UpdateInfo | null> {
  try {
    return await invoke<UpdateInfo | null>('check_for_update')
  } catch (e) {
    throw new Error(typeof e === 'string' ? e : JSON.stringify(e))
  }
}

export interface DownloadProgressEvent {
  event: 'Started' | 'Progress' | 'Finished'
  data?: { contentLength?: number; chunkLength?: number }
}

export async function downloadUpdate(
  onProgress?: (downloaded: number, total: number | null) => void
): Promise<void> {
  const channel = new Channel<DownloadProgressEvent>()
  let downloaded = 0
  let total: number | null = null

  channel.onmessage = (event: DownloadProgressEvent) => {
    switch (event.event) {
      case 'Started':
        total = event.data?.contentLength ?? null
        onProgress?.(0, total)
        break
      case 'Progress':
        downloaded += event.data?.chunkLength ?? 0
        onProgress?.(downloaded, total)
        break
      case 'Finished':
        onProgress?.(downloaded, total ?? downloaded)
        break
    }
  }

  try {
    await invoke<void>('download_update', { onEvent: channel })
  } catch (e) {
    throw new Error(typeof e === 'string' ? e : JSON.stringify(e))
  }
}

export async function installDownloadedUpdate(): Promise<void> {
  try {
    await invoke<void>('install_update')
  } catch (e) {
    throw new Error(typeof e === 'string' ? e : JSON.stringify(e))
  }
}

// ── 历史记录（与桌面版逐字相同）──
export async function saveHistory(
  records: InvoiceRecord[],
  totals: Totals,
  previewRows: PreviewRow[],
  startDate: string | null,
  endDate: string | null,
  days: number,
): Promise<HistoryDetail> {
  try {
    return await invoke<HistoryDetail>('save_history', { records, totals, previewRows, startDate, endDate, days })
  } catch (e) {
    throw new Error(typeof e === 'string' ? e : JSON.stringify(e))
  }
}

export async function getHistoryList(): Promise<HistorySummary[]> {
  try {
    return await invoke<HistorySummary[]>('get_history_list')
  } catch (e) {
    throw new Error(typeof e === 'string' ? e : JSON.stringify(e))
  }
}

export async function getHistoryDetail(id: number): Promise<HistoryDetail> {
  try {
    return await invoke<HistoryDetail>('get_history_detail', { id })
  } catch (e) {
    throw new Error(typeof e === 'string' ? e : JSON.stringify(e))
  }
}

export async function deleteHistory(id: number): Promise<void> {
  try {
    await invoke<void>('delete_history', { id })
  } catch (e) {
    throw new Error(typeof e === 'string' ? e : JSON.stringify(e))
  }
}
