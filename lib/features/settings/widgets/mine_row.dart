// 「我的」页列表行组件：行 / 卡片头部 / 分隔线 / 右箭头。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// 列表行：图标 + 标题（+ 副标题）+ 尾部控件。
class MineRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const MineRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.bgSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: c.fgMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.fg,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 12, color: c.fgMuted),
                      ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// 卡片头部：图标 + 标题（如「偏好设置」）。
class MineHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const MineHeader({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.bgSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: c.fgMuted),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// 列表行分隔线。
class MineDivider extends StatelessWidget {
  const MineDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Divider(
      height: 1,
      thickness: 1,
      color: c.border,
      indent: 16,
      endIndent: 16,
    );
  }
}
