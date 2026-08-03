// 通用空状态占位：图标 + 提示文案，供列表为空时展示。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// 空状态占位：[card] 为 true 时用卡片样式（列表内占位），
/// 否则为页面居中样式（带顶部留白）。
class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool card;

  const EmptyHint({
    super.key,
    required this.icon,
    required this.text,
    this.card = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Column(
      children: [
        Icon(icon, size: card ? 26 : 36, color: c.fgSoft),
        const SizedBox(height: 8),
        Text(text, style: TextStyle(fontSize: 12, color: c.fgMuted)),
      ],
    );
    return card
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: cardDecoration(c),
            child: content,
          )
        : Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: content,
            ),
          );
  }
}
