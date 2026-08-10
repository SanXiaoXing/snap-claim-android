// 报销统计：年度数据可视化 + 趣味指标。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../../invoice/models/claim.dart';
import '../../invoice/models/record.dart';
import '../../invoice/widgets/app_top_bar.dart';

class StatsPage extends StatelessWidget {
  final List<Claim> claims;

  const StatsPage({super.key, required this.claims});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();

    // 仅统计今年的报销单。
    final yearClaims = claims
        .where((cl) => cl.startDate.year == now.year)
        .toList();
    final allRecords = yearClaims.expand((cl) => cl.records).toList();
    final allTotal = yearClaims.fold(0.0, (s, cl) => s + cl.total);
    // 累计退补金额 = 今年报销单的退补金额之和（退补金额 = 火车 + 高速费 + 地铁费 + 差补）。
    final totalBalance =
        yearClaims.fold(0.0, (s, cl) => s + cl.balanceAmount);
    final allDays = yearClaims.fold(0, (s, cl) {
      final d = cl.endDate.difference(cl.startDate).inDays + 1;
      return s + (d > 0 ? d : 1);
    });

    // 最高单笔。
    final maxRecord = allRecords.isEmpty
        ? null
        : allRecords.reduce((a, b) => a.amount > b.amount ? a : b);

    // 最忙月份。
    final monthCounts = <int, int>{};
    for (final cl in yearClaims) {
      final m = cl.startDate.month;
      monthCounts[m] = (monthCounts[m] ?? 0) + 1;
    }
    final busiest = monthCounts.isEmpty
        ? null
        : monthCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    final busiestMonth = busiest?.key;
    final busiestCount = busiest?.value ?? 0;

    // 各类别统计。
    final catCounts = <RecordCategory, int>{};
    final catTotals = <RecordCategory, double>{};
    for (final r in allRecords) {
      catCounts[r.category] = (catCounts[r.category] ?? 0) + 1;
      catTotals[r.category] =
          (catTotals[r.category] ?? 0) + r.amount;
    }
    // 类别占比条的统一最大值（提前算好，避免循环内重复计算）。
    final maxCatTotal = catTotals.values.fold(0.0, (a, b) => a > b ? a : b);

    // 最常出行方式。
    final topEntry = catCounts.isEmpty
        ? null
        : catCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    final topCat = topEntry?.key;
    final topCatCount = topEntry?.value ?? 0;

    // 最贵的一次出差。
    final priciestClaim = yearClaims.isEmpty
        ? null
        : yearClaims.reduce((a, b) => a.total > b.total ? a : b);

    // 平均每张报销单金额。
    final avgPerClaim =
        yearClaims.isNotEmpty ? allTotal / yearClaims.length : 0.0;

    // 日均差补。
    final totalAllowance =
        yearClaims.fold(0.0, (s, cl) => s + cl.allowance);
    final avgDailyAllowance =
        allDays > 0 ? totalAllowance / allDays : 0.0;

    // 火车出行次数（环保指标）。
    final trainCount = catCounts[RecordCategory.train] ?? 0;

    // 月份分布柱状图数据。
    final monthlyTotals = List.filled(12, 0.0);
    for (final cl in yearClaims) {
      final m = cl.startDate.month - 1;
      monthlyTotals[m] += cl.total;
    }
    final maxMonthly = monthlyTotals.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          AppTopBar(
            leading: AppIconButton(
              icon: Icons.chevron_left,
              onTap: () => Navigator.of(context).pop(),
            ),
            title: '报销统计',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                children: [
                  // 年度总览大卡片。
                  _HeroCard(
                    year: now.year,
                    claimCount: yearClaims.length,
                    recordCount: allRecords.length,
                    total: totalBalance,
                  ),
                  const SizedBox(height: 16),

                  // 核心指标 2×2 网格。
                  _SectionTitle(title: '核心指标'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MetricCard(
                        icon: Icons.receipt_long_outlined,
                        iconColor: c.accent,
                        label: '提交票据',
                        value: '${allRecords.length} 张',
                        foot: '${yearClaims.length} 张报销单',
                      ),
                      const SizedBox(width: 10),
                      _MetricCard(
                        icon: Icons.account_balance_wallet_outlined,
                        iconColor: c.accent,
                        label: '累计退补',
                        value: fmtMoney(totalBalance),
                        foot: '日均 ${fmtMoney(avgDailyAllowance)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MetricCard(
                        icon: maxRecord?.category.icon ?? Icons.star,
                        iconColor:
                            maxRecord?.category.base ?? c.accent,
                        label: '最高单笔',
                        value: maxRecord != null
                            ? fmtMoney(maxRecord.amount)
                            : '¥0',
                        foot: maxRecord != null
                            ? maxRecord.category.label
                            : '暂无',
                      ),
                      const SizedBox(width: 10),
                      _MetricCard(
                        icon: Icons.calendar_month_outlined,
                        iconColor: c.accent,
                        label: '最忙月份',
                        value: busiestMonth != null
                            ? '$busiestMonth 月'
                            : '暂无',
                        foot: busiestMonth != null
                            ? '$busiestCount 张报销单'
                            : '',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 趣味指标。
                  _SectionTitle(title: '数据统计'),
                  const SizedBox(height: 10),
                  _FunCard(
                    icon: Icons.flight_takeoff,
                    iconColor: RecordCategory.flight.base,
                    title: '出差达人',
                    value: '$allDays 天',
                    desc: '今年累计出差天数，相当于地球自转 ${(allDays * 40000 / 40075).toStringAsFixed(1)} 圈',
                  ),
                  const SizedBox(height: 10),
                  _FunCard(
                    icon: topCat?.icon ?? Icons.category,
                    iconColor: topCat?.base ?? c.accent,
                    title: '最常出行方式',
                    value: topCat?.label ?? '暂无',
                    desc: topCat != null
                        ? '$topCatCount 次，花费 ${fmtMoney(catTotals[topCat] ?? 0)}'
                        : '快去出差吧',
                  ),
                  const SizedBox(height: 10),
                  _FunCard(
                    icon: Icons.eco_outlined,
                    iconColor: RecordCategory.train.base,
                    title: '环保贡献',
                    value: '$trainCount 次火车',
                    desc: trainCount > 0
                        ? '相比飞机减少约 ${(trainCount * 0.12).toStringAsFixed(1)} 吨碳排放'
                        : '试试火车出行，更环保',
                  ),
                  const SizedBox(height: 10),
                  _FunCard(
                    icon: Icons.trending_up,
                    iconColor: c.accent,
                    title: '单张之王',
                    value: priciestClaim != null
                        ? fmtMoney(priciestClaim.total)
                        : '¥0',
                    desc: priciestClaim != null
                        ? '「${priciestClaim.name}」最花钱'
                        : '暂无报销单',
                  ),
                  const SizedBox(height: 10),
                  _FunCard(
                    icon: Icons.balance_outlined,
                    iconColor: c.accent,
                    title: '平均消费',
                    value: fmtMoney(avgPerClaim),
                    desc: '每张报销单平均金额',
                  ),
                  const SizedBox(height: 16),

                  // 月份分布。
                  _SectionTitle(title: '月度分布'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: cardDecoration(c),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var m = 0; m < 12; m++) ...[
                          _MonthBar(
                            month: m + 1,
                            amount: monthlyTotals[m],
                            maxAmount: maxMonthly,
                          ),
                          if (m < 11) const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 类别占比。
                  _SectionTitle(title: '类别占比'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: cardDecoration(c),
                    child: Column(
                      children: [
                        for (final cat in RecordCategory.values)
                          if (catCounts[cat] != null) ...[
                            _CategoryBar(
                              category: cat,
                              count: catCounts[cat]!,
                              total: catTotals[cat] ?? 0,
                              maxTotal: maxCatTotal,
                            ),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 年度总览大卡片：渐变背景 + 核心数字。
class _HeroCard extends StatelessWidget {
  final int year;
  final int claimCount;
  final int recordCount;
  final double total;

  const _HeroCard({
    required this.year,
    required this.claimCount,
    required this.recordCount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: Colors.white.withValues(alpha: 0.9), size: 18),
              const SizedBox(width: 6),
              Text(
                '$year 年度账单',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            fmtMoney(total),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.03,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '累计退补金额 · $claimCount 张报销单 · $recordCount 条明细',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.fg,
          ),
        ),
      ],
    );
  }
}

/// 核心指标卡片（2×2 网格中的单个）。
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String foot;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.foot,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(c),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.fgMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.fg,
                letterSpacing: -0.02,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              foot,
              style: TextStyle(fontSize: 11, color: c.fgMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// 趣味数据卡片：图标 + 标题 + 大数字 + 描述。
class _FunCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String desc;

  const _FunCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(c),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.fgMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 11, color: c.fgMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 月度柱状条。
class _MonthBar extends StatelessWidget {
  final int month;
  final double amount;
  final double maxAmount;

  const _MonthBar({
    required this.month,
    required this.amount,
    required this.maxAmount,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ratio = maxAmount > 0 ? (amount / maxAmount).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            '$month 月',
            style: TextStyle(fontSize: 11, color: c.fgMuted),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 20,
                decoration: BoxDecoration(
                  color: c.bgSecondary,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            amount > 0 ? fmtMoneyShort(amount) : '-',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: amount > 0 ? c.fg : c.fgSoft,
            ),
          ),
        ),
      ],
    );
  }
}

/// 类别占比条。
class _CategoryBar extends StatelessWidget {
  final RecordCategory category;
  final int count;
  final double total;
  final double maxTotal;

  const _CategoryBar({
    required this.category,
    required this.count,
    required this.total,
    required this.maxTotal,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final b = Theme.of(context).brightness;
    final ratio =
        maxTotal > 0 ? (total / maxTotal).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: category.iconBg(b),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(category.icon, size: 16, color: category.base),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    category.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.fg,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$count 笔',
                    style: TextStyle(fontSize: 11, color: c.fgMuted),
                  ),
                  const Spacer(),
                  Text(
                    fmtMoney(total),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.fg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: c.bgSecondary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: category.base,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
