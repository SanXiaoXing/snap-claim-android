// 汇总胶囊行：彩色图标 + 类别名 + 金额，供报销汇总卡片与分享卡片共用。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../models/record.dart';

/// 汇总行的图标与品牌色（对应 Claim.summaryRows 的行：
/// 火车 / 飞机 / 酒店 / 市内交通 / 往返交通 / 高速费 / 地铁费 / 差补 / 预借金额 / 退补金额）。
({IconData icon, Color color}) summaryRowStyle(String label) {
  return switch (label) {
    '火车' => (icon: RecordCategory.train.icon, color: RecordCategory.train.base),
    '飞机' =>
      (icon: RecordCategory.flight.icon, color: RecordCategory.flight.base),
    '酒店' =>
      (icon: RecordCategory.hotel.icon, color: RecordCategory.hotel.base),
    '市内交通' =>
      (icon: RecordCategory.car.icon, color: RecordCategory.car.base),
    '往返交通' => (icon: Icons.sync_alt, color: Color(0xFF14B8A6)),
    '高速费' =>
      (icon: RecordCategory.highway.icon, color: RecordCategory.highway.base),
    '地铁费' =>
      (icon: RecordCategory.subway.icon, color: RecordCategory.subway.base),
    '差补' => (icon: Icons.payments_outlined, color: Color(0xFFF43F5E)),
    '预借金额' =>
      (icon: Icons.account_balance_wallet_outlined, color: Color(0xFF06B6D4)),
    '退补金额' => (icon: Icons.currency_exchange, color: Color(0xFFF97316)),
    _ => (icon: Icons.receipt_long_outlined, color: RecordCategory.car.base),
  };
}

/// 胶囊形式的汇总行：品牌色图标 + 类别名 + 金额，两端全圆角。
/// [c] 由调用方传入（分享卡片强制浅色配色，不能依赖当前主题）。
class SummaryPill extends StatelessWidget {
  final String label;
  final double amount;
  final AppColorScheme c;

  const SummaryPill({
    super.key,
    required this.label,
    required this.amount,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final style = summaryRowStyle(label);
    final isDark = c == AppColorScheme.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: style.color.withValues(alpha: isDark ? 0.30 : 0.18)),
      ),
      child: Row(
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.fgMuted,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            fmtMoneyShort(amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: c.fg,
            ),
          ),
        ],
      ),
    );
  }
}
