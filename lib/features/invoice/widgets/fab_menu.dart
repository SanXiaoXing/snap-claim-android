// 展开式浮动按钮菜单：弹性弹出 + Glassmorphism 遮罩 + 交错级联。
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class FabMenuItem {
  final IconData icon;
  final String label;
  const FabMenuItem({required this.icon, required this.label});
}

class FabMenu extends StatefulWidget {
  final List<FabMenuItem> items;
  final ValueChanged<String> onAction;

  const FabMenu({super.key, required this.items, required this.onAction});

  @override
  State<FabMenu> createState() => _FabMenuState();
}

class _FabMenuState extends State<FabMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _ctrl.forward(from: 0);
    } else {
      _ctrl.reverse();
    }
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    _ctrl.reverse();
  }

  void _select(String label) {
    _close();
    widget.onAction(label);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        // Glassmorphism 背景遮罩：强模糊 + 低浓度色调，
        // 透出后方内容轮廓而非纯黑遮挡。
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_open,
            child: GestureDetector(
              onTap: _close,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(_ctrl.value);
                  return ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 18 * t,
                        sigmaY: 18 * t,
                      ),
                      child: Container(
                        // 用主题色调而非纯黑，保持玻璃通透感。
                        color: (isDark ? Colors.black : Colors.white)
                            .withValues(alpha: (isDark ? 0.12 : 0.10) * t),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 26,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 菜单项：自下而上交错弹性弹出。
              IgnorePointer(
                ignoring: !_open,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < widget.items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AnimatedItem(
                          controller: _ctrl,
                          index: i,
                          total: widget.items.length,
                          child: _PillItem(
                            item: widget.items[i],
                            onTap: () => _select(widget.items[i].label),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 主按钮：弹性旋转 45° + 放大 + 光晕增强。
              GestureDetector(
                onTap: _toggle,
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final t = _ctrl.value;
                    final pop = Curves.elasticOut.transform(t);
                    final shadow = Color.lerp(
                      c.accent.withValues(alpha: 0.5),
                      c.accent.withValues(alpha: 0.72),
                      Curves.easeOut.transform(t),
                    )!;
                    return Transform.scale(
                      scale: 1.0 + 0.12 * pop,
                      child: Container(
                        width: 56,
                        height: 56,
                        transform: Matrix4.identity()
                          ..rotateZ(45 * 3.14159265 / 180 * pop),
                        transformAlignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [c.accent, c.accentLight],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: shadow,
                              blurRadius: 26 + 8 * Curves.easeOut.transform(t),
                              offset: const Offset(0, 10),
                              spreadRadius: -6 + 2 * Curves.easeOut.transform(t),
                            ),
                          ],
                        ),
                        child: Icon(Icons.add, size: 24, color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 玻璃药丸菜单项：BackdropFilter 模糊 + 半透明渐变填充 + 高光描边。
class _PillItem extends StatefulWidget {
  final FabMenuItem item;
  final VoidCallback onTap;

  const _PillItem({required this.item, required this.onTap});

  @override
  State<_PillItem> createState() => _PillItemState();
}

class _PillItemState extends State<_PillItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding:
                  const EdgeInsets.only(left: 6, right: 14, top: 6, bottom: 6),
              decoration: BoxDecoration(
                // 玻璃渐变：顶部高光 → 底部主题色，暗色更透。
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white
                        .withValues(alpha: isDark ? 0.22 : 0.52),
                    c.card.withValues(alpha: isDark ? 0.58 : 0.82),
                  ],
                  stops: const [0, 1],
                ),
                borderRadius: BorderRadius.circular(999),
                // 高光描边：白色半透明，模拟玻璃边缘折射。
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: isDark ? 0.20 : 0.50,
                  ),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(widget.item.icon, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedItem extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final int total;
  final Widget child;

  const _AnimatedItem({
    required this.controller,
    required this.index,
    required this.total,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // p = 0 表示最靠近主按钮的项，最先弹出。
    final p = total - 1 - index;
    final begin = 0.20 + 0.10 * p;
    final end = begin + 0.40;
    final fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(begin, end, curve: Curves.easeOut),
      ),
    );
    final pop = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(begin, end, curve: Curves.elasticOut),
      ),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0.18, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      ),
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(scale: pop, child: child),
      ),
    );
  }
}
