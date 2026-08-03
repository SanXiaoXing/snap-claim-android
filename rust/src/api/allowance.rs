//! 差补计算。
//! 出差天数 = 结束日期 - 开始日期 + 1（按自然天计，含首尾两天）。
//! 差补金额 = 出差天数 × 每日差补标准。

/// 差补每日标准（元/天），与 Dart 侧常量保持一致。
pub const PER_DIEM_RATE_PER_DAY: f64 = 100.0;

/// 仅含年月日的日期，用于跨桥传递（避免引入 chrono 依赖）。
#[derive(Clone, Debug)]
pub struct DateYmd {
    pub year: i32,
    pub month: i32,
    pub day: i32,
}

/// 计算出差天数（含首尾两天）。
/// 仅比较日期部分，忽略时分秒，避免同一天出差被算作 0 天。
fn travel_days(start: DateYmd, end: DateYmd) -> i32 {
    days_between(start, end) + 1
}

/// 计算差补金额。
pub fn per_diem_allowance(start: DateYmd, end: DateYmd) -> f64 {
    travel_days(start, end) as f64 * PER_DIEM_RATE_PER_DAY
}

/// 两个日期之间的自然天数差（end - start）。
/// 使用 1582 年格里高利历规则，对公元 1 年起的历史日期也成立。
fn days_between(start: DateYmd, end: DateYmd) -> i32 {
    days_from_epoch(end.year, end.month, end.day) - days_from_epoch(start.year, start.month, start.day)
}

/// 将 (年, 月, 日) 转换为相对公元 0000-03-01 的天数序号。
/// 算法来自 Howard Hinnant 的 date 库，无外部依赖。
fn days_from_epoch(year: i32, month: i32, day: i32) -> i32 {
    let y = if month <= 2 { year - 1 } else { year };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400; // [0, 399]
    let m = month as i32;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + day - 1; // [0, 365]
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy; // [0, 146096]
    era * 146097 + doe - 719468
}

#[cfg(test)]
mod tests {
    use super::*;

    fn d(y: i32, m: i32, d: i32) -> DateYmd {
        DateYmd { year: y, month: m, day: d }
    }

    #[test]
    fn same_day_is_one_day() {
        assert_eq!(travel_days(d(2026, 3, 1), d(2026, 3, 1)), 1);
    }

    #[test]
    fn two_day_span() {
        assert_eq!(travel_days(d(2026, 3, 1), d(2026, 3, 2)), 2);
    }

    #[test]
    fn allowance_same_day_is_one_rate() {
        assert_eq!(per_diem_allowance(d(2026, 3, 1), d(2026, 3, 1)), 100.0);
    }

    #[test]
    fn allowance_three_days() {
        assert_eq!(per_diem_allowance(d(2026, 3, 1), d(2026, 3, 3)), 300.0);
    }

    #[test]
    fn across_month_boundary() {
        // 1月31日到2月2日 = 3天（含首尾）。
        assert_eq!(travel_days(d(2026, 1, 31), d(2026, 2, 2)), 3);
    }
}

