// 版本信息中的单行键值展示。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class MineInfoLine extends StatelessWidget {
  final String label;
  final String value;

  const MineInfoLine({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: c.fgMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.fg,
            ),
          ),
        ),
      ],
    );
  }
}
