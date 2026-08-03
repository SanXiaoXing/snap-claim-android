// 差补计算 —— 通过 flutter_rust_bridge 调用 Rust 核心库 (snap_claim_core)。
// 真正的计算逻辑在 rust/src/api/allowance.rs，
// Dart 侧仅做 DateTime ↔ DateYmd 转换与薄封装。
import '../../src/rust/api/allowance.dart' as rust;

/// 将 DateTime 转为桥用的年月日结构（仅取日期部分）。
rust.DateYmd _toYmd(DateTime d) =>
    rust.DateYmd(year: d.year, month: d.month, day: d.day);

/// 计算差补金额 = 出差天数 × 每日差补标准。
/// 每日标准由 Rust 侧常量 PER_DIEM_RATE_PER_DAY 持有，单一数据源。
Future<double> perDiemAllowance(DateTime start, DateTime end) =>
    rust.perDiemAllowance(start: _toYmd(start), end: _toYmd(end));
