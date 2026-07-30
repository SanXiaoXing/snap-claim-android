export type InvoiceType = 'train' | 'hotel' | 'car' | 'flight' | 'invoice' | 'unknown'

export interface InvoiceRecord {
  type: InvoiceType
  amount: number | null
  qrAmount: boolean
  filename: string
  fullPath: string
  pageNumber: number
  trainNumber?: string
  departureStation?: string
  arrivalStation?: string
  departureTime?: string
  hotelName?: string
  checkInDate?: string
  checkOutDate?: string
  nights?: number
  carDate?: string
  mileage?: number
  isRoundTrip?: boolean
  flightNumber?: string
  departureCity?: string
  arrivalCity?: string
  flightDate?: string
  invoiceCode?: string
  invoiceNumber?: string
  issueDate?: string
}

export interface Totals {
  train: number
  flight: number
  hotel: number
  car: number
  roundTrip?: number
  invoice: number
  subsidy: number
  advance: number
  refund: number
  total: number
  chinese: string
}

export interface PreviewRow {
  cells: (string | number)[]
  bold: boolean
}

export interface UpdateInfo {
  version: string
  notes: string
  pubDate?: string
}

export interface HistorySummary {
  id: number
  name: string
  createdAt: string
  startDate: string | null
  endDate: string | null
  days: number
  totals: Totals
  intercityCount: number
  otherCount: number
  remark: string | null
}

export interface HistoryDetail {
  id: number
  name: string
  createdAt: string
  startDate: string | null
  endDate: string | null
  days: number
  totals: Totals
  records: InvoiceRecord[]
  previewRows: PreviewRow[]
  remark: string | null
}
