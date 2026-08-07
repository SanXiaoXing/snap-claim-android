// 顶部栏与通用按钮，对应原型中的 .topbar / .icon-btn / .text-btn。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// 圆角图标按钮（36×36，bgSecondary 底，border）。
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.bgSecondary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: Icon(icon, size: size, color: c.fg),
        ),
      ),
    );
  }
}

/// 强调色文字按钮（保存等）。
class AppTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const AppTextButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: c.accent,
          ),
        ),
      ),
    );
  }
}

/// 顶部栏：左侧 / 居中标题 / 右侧，左右各占 72 宽以保持标题居中。
/// 需要更宽槽位（如右侧放两个操作按钮）时，可传 [leadingWidth] /
/// [trailingWidth] 覆盖默认 72，左右等宽以保证标题仍居中。
class AppTopBar extends StatelessWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final bool displayFont;
  final double leadingWidth;
  final double trailingWidth;

  const AppTopBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.displayFont = false,
    this.leadingWidth = 72,
    this.trailingWidth = 72,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: Row(
          children: [
            SizedBox(
              width: leadingWidth,
              height: 36,
              child: Align(alignment: Alignment.centerLeft, child: leading ?? const SizedBox()),
            ),
            Expanded(
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: displayFont ? 20 : 18,
                    fontWeight: FontWeight.w800,
                    color: c.fg,
                    letterSpacing: displayFont ? 0.5 : 0,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: trailingWidth,
              height: 36,
              child: Align(alignment: Alignment.centerRight, child: trailing ?? const SizedBox()),
            ),
          ],
        ),
      ),
    );
  }
}
