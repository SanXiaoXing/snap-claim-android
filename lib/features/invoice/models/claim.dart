// 报销单模型。
import 'package:flutter/foundation.dart';

import 'record.dart';

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
    this.archived = false,
  });

  double get recordsTotal =>
      records.fold(0.0, (s, r) => s + r.amount);

  /// 出差天数与差补金额现由 Rust 核心库计算（见 core/utils/allowance.dart），
  /// 报销单只持有编辑页算好并存入的 [allowance] 字段。

  double get total => recordsTotal + allowance;

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

  /// 退补金额 = 火车总额 + 差补。
  double get balanceAmount =>
      (categoryTotals[RecordCategory.train] ?? 0) + allowance;

  /// 报销汇总的八行明细（火车 / 飞机 / 酒店 / 市内交通 / 往返交通 / 差补 / 预借金额 / 退补金额）。
  List<({String label, double amount})> get summaryRows {
    final totals = categoryTotals;
    final roundTrip = roundTripTotal;
    return [
      (label: '火车', amount: totals[RecordCategory.train] ?? 0),
      (label: '飞机', amount: totals[RecordCategory.flight] ?? 0),
      (label: '酒店', amount: totals[RecordCategory.hotel] ?? 0),
      // 市内交通 = 用车总额 - 往返交通。
      (label: '市内交通', amount: (totals[RecordCategory.car] ?? 0) - roundTrip),
      (label: '往返交通', amount: roundTrip),
      (label: '差补', amount: allowance),
      // 预借金额 = 飞机 + 酒店 + 用车。
      (
        label: '预借金额',
        amount: (totals[RecordCategory.flight] ?? 0) +
            (totals[RecordCategory.hotel] ?? 0) +
            (totals[RecordCategory.car] ?? 0),
      ),
      // 退补金额 = 火车 + 差补。
      (label: '退补金额', amount: balanceAmount),
    ];
  }

  Claim copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    List<Record>? records,
    DateTime? savedAt,
    double? allowance,
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
      archived: archived ?? this.archived,
    );
  }
}
