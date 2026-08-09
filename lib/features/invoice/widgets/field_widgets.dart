// 表单通用小组件：字段小标题 + 日期胶囊。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import 'press_scale.dart';

/// 表单字段小标题。
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: c.fgMuted,
      ),
    );
  }
}

/// 日期胶囊；提供 [onTap] 时可点击选择日期，否则只读展示。
class DatePill extends StatelessWidget {
  final DateTime date;
  final String label;
  final VoidCallback? onTap;

  const DatePill({
    super.key,
    required this.date,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.bgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, size: 14, color: c.accent),
          const SizedBox(width: 6),
          Text(
            fmtMd(date),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.fg,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 13, color: c.fgSoft)),
        ],
      ),
    );
    final onTap = this.onTap;
    return onTap == null ? pill : PressScale(onTap: onTap, child: pill);
  }
}
