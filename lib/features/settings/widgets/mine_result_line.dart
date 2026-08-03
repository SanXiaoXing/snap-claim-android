// 扫码 / OCR 结果对话框中的单行键值。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class ResultLine extends StatelessWidget {
  final String label;
  final String value;

  const ResultLine({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: c.fgMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.fg,
            ),
          ),
        ),
      ],
    );
  }
}
