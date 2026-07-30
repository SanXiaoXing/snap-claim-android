// 与后端 expense_calculator.rs 严格对齐的前端计算逻辑。
// ponytail: 后端无独立 calc_totals 命令暴露；save_history 时后端会重新算并存库，
// 此处仅用于前端实时预览。两处逻辑必须保持一致。
import type { InvoiceRecord, Totals, PreviewRow } from '../types'

export const SUBSIDY_PER_DAY = 100.0

export function calcTotals(records: InvoiceRecord[], days: number): Totals {
  const train = sumAmounts(records, 'train')
  const flight = sumAmounts(records, 'flight')
  const hotel = sumAmounts(records, 'hotel')
  const invoice = sumAmounts(records, 'invoice')

  // 用车按 is_round_trip 拆市内/往返
  const { car, roundTrip } = records
    .filter((r) => r.type === 'car')
    .reduce(
      (acc, r) => {
        const amt = r.amount ?? 0
        return r.isRoundTrip
          ? { car: acc.car, roundTrip: acc.roundTrip + amt }
          : { car: acc.car + amt, roundTrip: acc.roundTrip }
      },
      { car: 0, roundTrip: 0 },
    )

  const subsidy = days * SUBSIDY_PER_DAY
  const advance = car + roundTrip + flight + hotel
  const refund = train + subsidy
  const total = train + flight + hotel + car + roundTrip + invoice + subsidy
  const chinese = convertToChinese(total)

  return { train, flight, hotel, car, roundTrip, invoice, subsidy, advance, refund, total, chinese }
}

export function buildPreviewRows(_records: InvoiceRecord[], _days: number): PreviewRow[] {
  // ponytail: 移动端不需要 Excel 预览，但 save_history 命令签名要求传 previewRows。
  // 返回空数组即可，后端存库不依赖它做计算（totals 才是计算结果）。
  return []
}

function sumAmounts(records: InvoiceRecord[], kind: string): number {
  return records
    .filter((r) => r.type === kind)
    .reduce((s, r) => s + (r.amount ?? 0), 0)
}

// ===== 中文大写金额（与后端 amount_converter.rs 对齐）=====
const DIGIT_MAP = ['零', '壹', '贰', '叁', '肆', '伍', '陆', '柒', '捌', '玖']
const UNIT_MAP = ['元', '拾', '佰', '仟', '万', '拾', '佰', '仟', '亿']
const DECIMAL_UNIT = ['角', '分']

function convertToChinese(amount: number): string {
  if (amount < 0) return '金额不能为负数'
  if (amount === 0) return '零元整'

  const amountStr = amount.toFixed(2)
  const [integerPart, decimalPart] = amountStr.split('.')
  const integerChinese = convertInteger(integerPart)
  const decimalChinese = convertDecimal(decimalPart)

  return decimalChinese === '' ? `${integerChinese}整` : `${integerChinese}${decimalChinese}`
}

function convertInteger(integerStr: string): string {
  let result = ''
  const chars = integerStr.split('')
  const length = chars.length
  for (let i = 0; i < length; i++) {
    const pos = length - 1 - i
    const unit = UNIT_MAP[pos % UNIT_MAP.length]
    const digit = parseInt(chars[i], 10)
    if (digit === 0) {
      if (!result.endsWith('零')) result += '零'
    } else {
      if (result.endsWith('零') && i > 0) result = result.slice(0, -1)
      result += DIGIT_MAP[digit] + unit
    }
  }
  while (result.endsWith('零')) result = result.slice(0, -1)
  return result
}

function convertDecimal(decimalStr: string): string {
  let result = ''
  const chars = decimalStr.split('')
  if (chars[0] !== '0') {
    result += DIGIT_MAP[parseInt(chars[0], 10)] + DECIMAL_UNIT[0]
  }
  if (chars[1] !== '0') {
    result += DIGIT_MAP[parseInt(chars[1], 10)] + DECIMAL_UNIT[1]
  }
  return result
}
