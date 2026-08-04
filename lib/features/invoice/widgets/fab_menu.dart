// 展开式浮动按钮菜单：扇形(Speed Dial)展开 + Glassmorphism 遮罩 + 交错级联。
import 'dart:math' as math;
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

  // 布局常量。
  static const double _fabSize = 56;
  static const double _itemSize = 48;
  static const double _fabRight = 18;
  static const double _fabBottom = 26;
  // 主按钮中心 → 子按钮中心的距离:相邻 45° 夹角子项弦长 ≈ 296sin(22.5°) ≈ 73px,
  // 大于 48px 按钮直径 + 间距,展开后不重叠。
  static const double _arcRadius = 96;

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

  // 给定子项索引,返回其圆心在主按钮坐标系内的角度(度)。
  // 0° 指右,90° 指上,180° 指左(数学惯例)。
  // 单项时直接朝正上方,多项时在 [_fanHalfSpread, 180 - _fanHalfSpread] 区间均分。
  double _angleFor(int i, int n) {
    if (n <= 1) return 90;
    // 在 [90°(正上), 180°(正左)] 区间均分:避开屏幕右/下边缘,间距足够不重叠。
    return 90 + 90 * (i / (n - 1));
  }

  // 根据角度,把"子按钮圆心应处于的右/下偏移"换算成 Positioned 的 right / bottom。
  // Positioned.right 是 widget 右边到屏幕右边的距离,越小越靠右。
  // 主按钮圆心 right = fabRight + fabSize/2,bottom = fabBottom + fabSize/2。
  ({double right, double bottom}) _positionFor(double angleDeg) {
    final rad = angleDeg * math.pi / 180;
    final dx = _arcRadius * math.cos(rad); // 屏幕坐标:正=右
    final dy = -_arcRadius * math.sin(rad); // 屏幕坐标:负=上(Flutter Y 轴朝下)
    final fabCenterRight = _fabRight + _fabSize / 2;
    final fabCenterBottom = _fabBottom + _fabSize / 2;
    return (
      right: fabCenterRight - dx - _itemSize / 2,
      bottom: fabCenterBottom - dy - _itemSize / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final n = widget.items.length;
    return Stack(
      children: [
        // Glassmorphism 背景遮罩:强模糊 + 低浓度色调,
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
        // 扇形子项:从主按钮中心向弧线终点弹开,带交错级联。
        for (int i = 0; i < n; i++)
          _buildFanItem(
            context,
            index: i,
            total: n,
            color: c,
            isDark: isDark,
          ),
        // 主按钮:弹性旋转 45° + 放大 + 光晕增强。
        Positioned(
          right: _fabRight,
          bottom: _fabBottom,
          child: GestureDetector(
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
                    width: _fabSize,
                    height: _fabSize,
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
                    child: Icon(Icons.add, size: 26, color: Colors.white),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFanItem(
    BuildContext context, {
    required int index,
    required int total,
    required AppColorScheme color,
    required bool isDark,
  }) {
    final angleDeg = _angleFor(index, total);
    final pos = _positionFor(angleDeg);
    return Positioned(
      right: pos.right,
      bottom: pos.bottom,
      child: IgnorePointer(
        ignoring: !_open,
        child: _AnimatedFanItem(
          controller: _ctrl,
          index: index,
          total: total,
          angleDeg: angleDeg,
          arcRadius: _arcRadius,
          child: _FabAction(
            item: widget.items[index],
            onTap: () => _select(widget.items[index].label),
            color: color,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

/// 扇形子项:48px 圆形图标按钮,从主按钮中心向弧线终点弹开。
class _FabAction extends StatefulWidget {
  final FabMenuItem item;
  final VoidCallback onTap;
  final AppColorScheme color;
  final bool isDark;

  const _FabAction({
    required this.item,
    required this.onTap,
    required this.color,
    required this.isDark,
  });

  @override
  State<_FabAction> createState() => _FabActionState();
}

class _FabActionState extends State<_FabAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final isDark = widget.isDark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.accent, c.accentLight],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.accent.withValues(alpha: 0.40),
                blurRadius: 18,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.white.withValues(
                  alpha: isDark ? 0.12 : 0.30,
                ),
                blurRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            widget.item.icon,
            size: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// 扇形子项动画:
/// - 从主按钮中心向弧线终点平移 + 弹性放大 + 淡入,关闭时反向;
/// - 多个子项按 index 自下而上交错级联(p=0 最靠近主按钮,最先弹出)。
class _AnimatedFanItem extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final int total;
  final double angleDeg;
  final double arcRadius;
  final Widget child;

  const _AnimatedFanItem({
    required this.controller,
    required this.index,
    required this.total,
    required this.angleDeg,
    required this.arcRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final rad = angleDeg * math.pi / 180;
    // 起始偏移:从主按钮中心附近出发,方向指向弧线终点。
    // 行程取半径的 45%,子项不会全程穿过主按钮中心,减少动画中段的互相重叠。
    final beginDx = -math.cos(rad) * (arcRadius * 0.45);
    final beginDy = math.sin(rad) * (arcRadius * 0.45); // 屏幕 Y 向下为正
    // p=0 最靠近主按钮,最先弹出。
    final p = total - 1 - index;
    final begin = 0.18 + 0.10 * p;
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
      begin: Offset(beginDx, beginDy),
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
