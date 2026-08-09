// 滑动操作背景：Dismissible 滑动时露出的渐变底（图标 + 文案），
// 供历史页归档、归档页撤销/删除、编辑页明细删除/切换等场景共用。
import 'package:flutter/material.dart';

/// 滑动背景：渐变底色 + 图标 + 文案。
/// [alignment] 决定内容靠左还是靠右，同时决定渐近方向
/// （靠左：右上→左下；靠右：左上→右下）。
class SwipeBackground extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color from;
  final Color to;
  final Alignment alignment;

  const SwipeBackground({
    super.key,
    required this.icon,
    required this.label,
    required this.from,
    required this.to,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      alignment: alignment,
      padding: EdgeInsets.only(
        left: isLeft ? 18 : 0,
        right: isLeft ? 0 : 18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeft ? Alignment.topRight : Alignment.topLeft,
          end: isLeft ? Alignment.bottomLeft : Alignment.bottomRight,
          colors: [from, to],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
