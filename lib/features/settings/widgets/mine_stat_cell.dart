// 统计格子：标签 + 大数字 + 脚注，用于「我的」页统计概览。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class StatCell extends StatelessWidget {
  final String label;
  final String value;
  final String foot;

  const StatCell({
    super.key,
    required this.label,
    required this.value,
    required this.foot,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: c.bgSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.02,
                color: c.fg,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              foot,
              style: TextStyle(
                fontSize: 11,
                color: c.fgMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
