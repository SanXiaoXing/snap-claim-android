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

/// 日期胶囊的统一样式外壳：bgSecondary 底 + 圆角 + 边框，内容为一行。
Widget _datePillShell(AppColorScheme c, List<Widget> children) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.bgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );

/// 日期范围胶囊；提供 [onTap] 时可点击一次选择起止日期，否则只读展示。
class DateRangePill extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final VoidCallback? onTap;

  const DateRangePill({
    super.key,
    required this.start,
    required this.end,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pill = _datePillShell(c, [
      Icon(Icons.calendar_today_outlined, size: 14, color: c.accent),
      const SizedBox(width: 6),
      Text(
        fmtMd(start),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: c.fg,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.arrow_forward, size: 12, color: c.fgSoft),
      ),
      Text(
        fmtMd(end),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: c.fg,
        ),
      ),
    ]);
    final onTap = this.onTap;
    return onTap == null ? pill : PressScale(onTap: onTap, child: pill);
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
    final pill = _datePillShell(c, [
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
    ]);
    final onTap = this.onTap;
    return onTap == null ? pill : PressScale(onTap: onTap, child: pill);
  }
}
