// 报销统计「类别占比」的计算口径。
//
// 背景：这里必须复用 Claim.summaryRows / Claim.balanceAmount 的同一套规则，
// 不能另起一套按明细类别裸汇总的算法，否则统计页会出现与报销汇总、
// 数据库内容对不上的第二套口径（例如把预借的飞机/酒店/用车算进报销金额，
// 又漏掉差补与超标金额）。
//
// 拆分方式：
//   · 退补构成 = 火车 + 高速费 + 地铁费 + 差补 − 超标金额（与累计退补金额一致）
//   · 预借构成 = 飞机 + 酒店 + 用车（用车按市内交通 / 往返交通拆分）
import 'package:flutter/foundation.dart';

import '../../invoice/models/claim.dart';
import '../../invoice/models/record.dart';

/// 构成分析中的一行（如「火车」「差补」「市内交通」）。
///
/// [label] 与 Claim.summaryRows 的行名保持一致，渲染层直接复用
/// summaryRowStyles[label] 取图标与品牌色，保证与报销汇总卡片配色统一。
@immutable
class StatsSlice {
  final String label;
  final double amount;

  /// 笔数；差补等非明细项没有笔数，为 0。
  final int count;

  /// 占所属分组分母的真实比例（0~1）。
  final double ratio;

  const StatsSlice({
    required this.label,
    required this.amount,
    required this.count,
    required this.ratio,
  });

  /// 百分比文本，例如 69.3%。
  String get percentText => '${(ratio * 100).toStringAsFixed(1)}%';
}

/// 一组构成分析（退补构成 / 预借构成）。
@immutable
class StatsGroup {
  final String title;

  /// 口径说明，写清这组包含什么、是否计入报销。
  final String hint;
  final List<StatsSlice> slices;

  /// 计算占比用的分母：组内各项金额之和（扣减前的毛额）。
  final double denominator;

  /// 扣减项金额（超标金额），仅退补组使用，为 0 表示无扣减。
  final double deduction;
  final String deductionLabel;

  const StatsGroup({
    required this.title,
    required this.hint,
    required this.slices,
    required this.denominator,
    this.deduction = 0,
    this.deductionLabel = '超标金额',
  });

  /// 扣减前的毛额（即占比分母）。
  double get gross => denominator;

  /// 该组最终合计（毛额 − 扣减项），退补组即「累计退补金额」。
  double get net => denominator - deduction;

  /// 扣减项占毛额的比例（用于展示「超标扣掉多少」），无扣减时为 0。
  double get deductionRatio =>
      denominator > 0 ? (deduction / denominator).clamp(0.0, 1.0) : 0.0;

  bool get hasDeduction => deduction != 0;

  bool get isEmpty => slices.isEmpty && !hasDeduction;
}

/// 一年的构成分析：退补 + 预借两组。
@immutable
class StatsBreakdown {
  /// 退补构成（计入报销的部分）。
  final StatsGroup balance;

  /// 预借构成（公司预借，不计入报销）。
  final StatsGroup advance;

  const StatsBreakdown({required this.balance, required this.advance});

  /// 按 [claims] 实时计算（传入的一般是当年报销单）。
  /// 各类别金额/笔数直接聚合 Claim 已有的 categoryTotals / tagCounts，
  /// 不再重走一遍明细（口径与报销汇总保持一致）。
  factory StatsBreakdown.compute(List<Claim> claims) {
    final totals = <RecordCategory, double>{};
    final counts = <RecordCategory, int>{};
    var roundTripCount = 0;
    var roundTrip = 0.0;
    var allowance = 0.0;
    var excess = 0.0;

    for (final cl in claims) {
      allowance += cl.allowance;
      excess += cl.excessAmount;
      roundTrip += cl.roundTripTotal;
      cl.categoryTotals.forEach((k, v) => totals[k] = (totals[k] ?? 0) + v);
      cl.tagCounts.forEach((k, v) => counts[k] = (counts[k] ?? 0) + v);
      // 往返用车笔数 Claim 未拆分，需遍历明细统计。
      for (final r in cl.records) {
        if (r.isRoundTripCar) roundTripCount++;
      }
    }

    final carTotal = totals[RecordCategory.car] ?? 0;
    final cityCarCount = (counts[RecordCategory.car] ?? 0) - roundTripCount;

    // 退补构成：只有火车 / 高速费 / 地铁费 / 差补计入报销，
    // 超标金额是不予报销的部分，作为扣减项单独展示。
    final balanceItems = <_RawItem>[
      _RawItem(
        '火车',
        totals[RecordCategory.train] ?? 0,
        counts[RecordCategory.train] ?? 0,
      ),
      _RawItem(
        '高速费',
        totals[RecordCategory.highway] ?? 0,
        counts[RecordCategory.highway] ?? 0,
      ),
      _RawItem(
        '地铁费',
        totals[RecordCategory.subway] ?? 0,
        counts[RecordCategory.subway] ?? 0,
      ),
      // 差补按天计算，没有明细笔数，count 传 0（渲染层不展示「0 笔」）。
      _RawItem('差补', allowance, 0),
    ];
    final balanceGross = balanceItems.fold(0.0, (s, e) => s + e.amount);

    // 预借构成：飞机 / 酒店 / 用车由公司预借，不计入退补金额；
    // 用车按市内交通 / 往返交通拆分，与报销汇总卡片的口径一致。
    final advanceItems = <_RawItem>[
      _RawItem(
        '飞机',
        totals[RecordCategory.flight] ?? 0,
        counts[RecordCategory.flight] ?? 0,
      ),
      _RawItem(
        '酒店',
        totals[RecordCategory.hotel] ?? 0,
        counts[RecordCategory.hotel] ?? 0,
      ),
      _RawItem('市内交通', carTotal - roundTrip, cityCarCount),
      _RawItem('往返交通', roundTrip, roundTripCount),
    ];
    final advanceGross = advanceItems.fold(0.0, (s, e) => s + e.amount);

    return StatsBreakdown(
      balance: StatsGroup(
        title: '退补构成',
        hint: '火车 / 高速费 / 地铁费 / 差补',
        slices: _toSlices(balanceItems, balanceGross),
        denominator: balanceGross,
        deduction: excess,
        deductionLabel: '超标金额',
      ),
      advance: StatsGroup(
        title: '预借构成',
        hint: '飞机 / 酒店 / 用车由公司预借，不计入退补金额',
        slices: _toSlices(advanceItems, advanceGross),
        denominator: advanceGross,
      ),
    );
  }

  /// 两组都没有内容（当年没有任何报销数据）。
  bool get isEmpty => balance.isEmpty && advance.isEmpty;
}

/// 计算占比前的中间项：名称 + 金额 + 笔数。
class _RawItem {
  final String label;
  final double amount;
  final int count;

  const _RawItem(this.label, this.amount, this.count);
}

/// 过滤金额为 0 的项（与报销汇总一致：没有对应内容就不显示），
/// 按金额降序排列，并计算每项占 [denominator] 的真实比例。
List<StatsSlice> _toSlices(List<_RawItem> items, double denominator) {
  final kept = [
    for (final e in items)
      if (e.amount != 0) e,
  ];
  kept.sort((a, b) => b.amount.compareTo(a.amount));
  return [
    for (final e in kept)
      StatsSlice(
        label: e.label,
        amount: e.amount,
        count: e.count,
        ratio: denominator > 0 ? (e.amount / denominator).clamp(0.0, 1.0) : 0.0,
      ),
  ];
}
