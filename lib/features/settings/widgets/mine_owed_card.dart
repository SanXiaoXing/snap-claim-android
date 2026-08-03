// 公司还欠我卡片：渐变背景 + 大字金额，置于「我的」页顶部。
import 'package:flutter/material.dart';

import '../../../core/utils/format.dart';

class OwedCard extends StatelessWidget {
  final double total;

  const OwedCard({super.key, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: total > 0
              ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
              : [const Color(0xFF10B981), const Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                total > 0 ? Icons.pending_actions : Icons.check_circle,
                color: Colors.white.withValues(alpha: 0.9),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '公司欠我',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            fmtMoney(total),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.03,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            total > 0 ? '待报销即未归档的退补金额总和' : '公司还清了报销款！！！',
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
