// 汇总胶囊行：彩色图标 + 类别名 + 金额，供报销汇总卡片与分享卡片共用。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';

/// 胶囊形式的汇总行：品牌色图标 + 类别名 + 金额，两端全圆角。
/// [c] 由调用方传入（分享卡片强制浅色配色，不能依赖当前主题）。
/// 图标与品牌色由调用方从 [Claim.summaryRows] / [summaryRowStyles] 取好传入。
class SummaryPill extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final AppColorScheme c;

  const SummaryPill({
    super.key,
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = c == AppColorScheme.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: color.withValues(alpha: isDark ? 0.30 : 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
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
