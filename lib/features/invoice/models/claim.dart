// 报销单模型。
import 'package:flutter/material.dart';

import '../../../core/utils/format.dart';
import 'record.dart';

/// 汇总行的图标与品牌色（label 与 [Claim.summaryRows] 的行名一一对应），
/// 供统计页 / 分享卡片等按行名取样式时复用，避免各文件重复写样式。
final summaryRowStyles = <String, ({IconData icon, Color color})>{
  '火车': (icon: RecordCategory.train.icon, color: RecordCategory.train.base),
  '飞机': (icon: RecordCategory.flight.icon, color: RecordCategory.flight.base),
  '酒店': (icon: RecordCategory.hotel.icon, color: RecordCategory.hotel.base),
  '市内交通': (icon: RecordCategory.car.icon, color: RecordCategory.car.base),
  '往返交通': (icon: Icons.sync_alt, color: Color(0xFF14B8A6)),
  '高速费': (icon: RecordCategory.highway.icon, color: RecordCategory.highway.base),
  '地铁费': (icon: RecordCategory.subway.icon, color: RecordCategory.subway.base),
  '差补': (icon: Icons.payments_outlined, color: Color(0xFF6366F1)),
  '超标金额': (icon: Icons.warning_amber_outlined, color: Color(0xFFEF4444)),
  '预借金额': (icon: Icons.account_balance_wallet_outlined, color: Color(0xFF06B6D4)),
  '退补金额': (icon: Icons.currency_exchange, color: Color(0xFFF97316)),
};

/// 按年月（fmtYm 文本）分组报销单，组内保持原顺序。
Map<String, List<Claim>> groupClaimsByMonth(List<Claim> claims) {
  final groups = <String, List<Claim>>{};
  for (final claim in claims) {
    groups.putIfAbsent(fmtYm(claim.startDate), () => []).add(claim);
  }
  return groups;
}

/// 一张报销单。
@immutable
class Claim {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final List<Record> records;
  final DateTime savedAt;
  final double allowance; // 差补

  /// 超标金额：超出报销标准的部分，人工手动填写，不计入退补金额。
  final double excessAmount;

  /// 是否已归档（归档 = 已报销）。
  final bool archived;

  const Claim({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.records,
    required this.savedAt,
    this.allowance = 0,
    this.excessAmount = 0,
    this.archived = false,
  });

  double get recordsTotal =>
      records.fold(0.0, (s, r) => s + r.amount);

  /// 出差天数与差补金额现由 Rust 核心库计算（见 core/utils/allowance.dart），
  /// 报销单只持有编辑页算好并存入的 [allowance] 字段。

  /// 总金额 = 明细总额 + 差补 + 超标金额。
  double get total => recordsTotal + allowance + excessAmount;

  Map<RecordCategory, int> get tagCounts {
    final m = <RecordCategory, int>{};
    for (final r in records) {
      m[r.category] = (m[r.category] ?? 0) + 1;
    }
    return m;
  }

  Map<RecordCategory, double> get categoryTotals {
    final m = <RecordCategory, double>{};
    for (final r in records) {
      m[r.category] = (m[r.category] ?? 0) + r.amount;
    }
    return m;
  }

  /// 标记为「往返交通」的用车记录总额。
  double get roundTripTotal =>
      records.where((r) => r.isRoundTripCar).fold(0.0, (s, r) => s + r.amount);

  /// 退补金额 = 火车总额 + 高速费 + 地铁费 + 差补 - 超标金额
  /// （超标部分不予以报销）。
  double get balanceAmount =>
      (categoryTotals[RecordCategory.train] ?? 0) +
      (categoryTotals[RecordCategory.highway] ?? 0) +
      (categoryTotals[RecordCategory.subway] ?? 0) +
      allowance -
      excessAmount;

  /// 报销汇总明细（火车 / 飞机 / 酒店 / 市内交通 / 往返交通 / 高速费 / 地铁费 /
  /// 差补 / 超标金额 / 预借金额 / 退补金额）；金额为 0 的行不展示（没有对应内容就不显示标签）。
  /// 每行直接携带图标与品牌色（取自 [summaryRowStyles]），渲染层不再按行名查样式。
  List<({String label, double amount, IconData icon, Color color})>
      get summaryRows {
    final totals = categoryTotals;
    final roundTrip = roundTripTotal;
    final rows = <({String label, double amount})>[
      (label: '火车', amount: totals[RecordCategory.train] ?? 0),
      (label: '飞机', amount: totals[RecordCategory.flight] ?? 0),
      (label: '酒店', amount: totals[RecordCategory.hotel] ?? 0),
      // 市内交通 = 用车总额 - 往返交通。
      (label: '市内交通', amount: (totals[RecordCategory.car] ?? 0) - roundTrip),
      (label: '往返交通', amount: roundTrip),
      (label: '高速费', amount: totals[RecordCategory.highway] ?? 0),
      (label: '地铁费', amount: totals[RecordCategory.subway] ?? 0),
      (label: '差补', amount: allowance),
      (label: '超标金额', amount: excessAmount),
      // 预借金额 = 飞机 + 酒店 + 用车。
      (
        label: '预借金额',
        amount: (totals[RecordCategory.flight] ?? 0) +
            (totals[RecordCategory.hotel] ?? 0) +
            (totals[RecordCategory.car] ?? 0),
      ),
      // 退补金额 = 火车 + 高速费 + 地铁费 + 差补。
      (label: '退补金额', amount: balanceAmount),
    ];
    // 没有对应内容（金额为 0）的行不显示标签。
    return [
      for (final row in rows)
        if (row.amount != 0)
          (
            label: row.label,
            amount: row.amount,
            icon: summaryRowStyles[row.label]!.icon,
            color: summaryRowStyles[row.label]!.color,
          ),
    ];
  }

  Claim copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    List<Record>? records,
    DateTime? savedAt,
    double? allowance,
    double? excessAmount,
    bool? archived,
  }) {
    return Claim(
      id: id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      records: records ?? this.records,
      savedAt: savedAt ?? this.savedAt,
      allowance: allowance ?? this.allowance,
      excessAmount: excessAmount ?? this.excessAmount,
      archived: archived ?? this.archived,
    );
  }
}
