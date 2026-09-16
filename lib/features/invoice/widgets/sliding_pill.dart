// 选中态滑动胶囊：accent 纯色填充 + 柔和 accent 阴影。
//
// 由一个原先内嵌在 main_shell.dart 的私有 `_SelectedPill` 提取而来，
// 行为与视觉逐像素保持一致，供「底部菜单栏 / 分段 tab」等共用：
// - **必须作为 Stack 的直接子节点**：内部用 `Positioned` 定位，依赖
//   `StackParentData`；left / width 由父级 LayoutBuilder 算好后传入。
// - 位置 / 宽度用**临界阻尼弹簧**驱动（Apple 移动 / 重定位默认：damping 1.0、
//   response ≈ 0.4s）：每次切换从当前屏幕值（而非目标值）出发，
//   途中可被下一次切换随时打断并重定向，不会跳变。
// - `animate = false` 时不做弹簧，直接跟随目标值：供「按住拖动、胶囊实时跟手」
//   的场景使用——跟手要求无滞后，若走弹簧会让胶囊甩在手指后面。
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../app/theme.dart';

class SlidingPill extends StatefulWidget {
  /// 胶囊左边缘（相对 Stack 坐标系）。
  final double left;

  /// 胶囊宽度。
  final double width;

  /// 相对 Stack 上 / 下的内缩，默认 4（与外壁构成同心圆角）。
  final double top;
  final double bottom;

  /// 圆角半径，默认 28（对应半高胶囊）。
  final double radius;

  /// 是否用弹簧动画收敛；为 false 时立即跟随 [left] / [width]（拖拽跟手用）。
  final bool animate;

  const SlidingPill({
    super.key,
    required this.left,
    required this.width,
    this.top = 4,
    this.bottom = 4,
    this.radius = 28,
    this.animate = true,
  });

  @override
  State<SlidingPill> createState() => _SlidingPillState();
}

class _SlidingPillState extends State<SlidingPill>
    with SingleTickerProviderStateMixin {
  // 临界阻尼弹簧：stiffness 246 → response ≈ 2π/√246 ≈ 0.40s，无过冲。
  // 临界阻尼 damping = 2√(stiffness·mass) ≈ 31.4。
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 246,
    damping: 31.4,
  );

  late final AnimationController _ctrl;
  double _left = 0;
  double _width = 0;
  // 本次弹簧的起点（屏幕当前值）与目标值。
  double _fromLeft = 0, _toLeft = 0;
  double _fromWidth = 0, _toWidth = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _left = widget.left;
    _width = widget.width;
    _toLeft = widget.left;
    _toWidth = widget.width;
    _ctrl = AnimationController.unbounded(vsync: this)
      ..addListener(_onSpringTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 减少动态需在依赖就绪后读取（initState 内不允许查 MediaQuery）。
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void didUpdateWidget(SlidingPill old) {
    super.didUpdateWidget(old);
    final targetChanged = old.left != widget.left || old.width != widget.width;
    final animateToggled = old.animate != widget.animate;
    if (!targetChanged && !animateToggled) return;

    // 立即跟随路径（拖拽跟手 / 减少动态）：停掉弹簧，直接落到目标值。
    if (!widget.animate || _reduceMotion) {
      _ctrl.stop();
      _left = widget.left;
      _width = widget.width;
      _toLeft = widget.left;
      _toWidth = widget.width;
      return;
    }

    // 从当前屏幕值（presentation value）出发，向新目标弹簧运动。
    // animateWith 会先停掉旧模拟再启动新模拟，快速连续切换也能
    // 安全打断重定向，不会触发「Ticker 已激活」断言。
    _fromLeft = _left;
    _fromWidth = _width;
    _toLeft = widget.left;
    _toWidth = widget.width;
    _ctrl.animateWith(SpringSimulation(_spring, 0, 1, 0));
  }

  void _onSpringTick() {
    setState(() {
      if (!_ctrl.isAnimating) {
        // 弹簧收敛后精确落到目标，避免浮点残留。
        _left = _toLeft;
        _width = _toWidth;
        return;
      }
      final t = _ctrl.value; // 0→1 弹簧进度（临界阻尼单调无过冲）。
      _left = _fromLeft + (_toLeft - _fromLeft) * t;
      _width = _fromWidth + (_toWidth - _fromWidth) * t;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Positioned(
      left: _left,
      top: widget.top,
      bottom: widget.bottom,
      width: _width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // 单色 accent 填充（沿用 main_shell 原实现）。
          color: c.accent,
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      ),
    );
  }
}
