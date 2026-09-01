// 报销汇总卡片：总额 + 人民币大写 + 六行分类明细。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../models/claim.dart';
import 'summary_pill.dart';

class SummaryCard extends StatelessWidget {
  final Claim claim;

  const SummaryCard({super.key, required this.claim});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '报销汇总',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.fg,
                ),
              ),
              const Spacer(),
              Icon(Icons.calculate_outlined, size: 16, color: c.fgMuted),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            fmtMoney(claim.total),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.03,
              color: c.accent,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            toChineseCurrency(claim.total),
            style: TextStyle(fontSize: 14, color: c.fgMuted),
          ),
          const SizedBox(height: 10),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 34,
              crossAxisSpacing: 12,
              mainAxisSpacing: 10,
            ),
            children: [
              for (final row in claim.summaryRows)
                SummaryPill(
                  label: row.label,
                  amount: row.amount,
                  icon: row.icon,
                  color: row.color,
                  c: c,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
