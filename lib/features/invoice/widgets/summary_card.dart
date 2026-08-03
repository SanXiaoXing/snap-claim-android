// 报销汇总卡片：总额 + 人民币大写 + 六行分类明细。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../models/claim.dart';

class SummaryCard extends StatelessWidget {
  final Claim claim;

  const SummaryCard({super.key, required this.claim});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
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
            style: TextStyle(fontSize: 12, color: c.fgMuted),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 6,
            crossAxisSpacing: 28,
            mainAxisSpacing: 10,
            children: [
              for (final row in claim.summaryRows)
                Row(
                  children: [
                    Text(
                      row.label,
                      style: TextStyle(fontSize: 12, color: c.fgMuted),
                    ),
                    const Spacer(),
                    Text(
                      fmtMoney(row.amount),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.fg,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
