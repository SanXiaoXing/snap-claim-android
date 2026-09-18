// AI 小球：移植 docs/design/askAI.md 中的 AIMascot 形象。
// 视觉：主色 blob + 两颗竖椭圆眼；blob 圆角缓慢形变，眼睛周期性眨眼。
// phase：generating→searching 摆动；success→celebrate 转圈 + 轻跳。
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

enum MascotPhase { idle, searching, celebrate }

/// askAI 风格的 AI 小球形象。
class AIMascot extends StatefulWidget {
  final bool awake;

  /// 醒着时眼睛是否看向左侧（底栏圆钮用）。
  final bool lookLeft;

  final double size;

  /// 生成中 searching，生成完成 celebrate；切入 celebrate 时播一次转圈。
  final MascotPhase phase;

  const AIMascot({
    super.key,
    this.awake = false,
    this.lookLeft = false,
    this.size = 32,
    this.phase = MascotPhase.idle,
  });

  @override
  State<AIMascot> createState() => _AIMascotState();
}

class _AIMascotState extends State<AIMascot>
    with TickerProviderStateMixin {
  late final AnimationController _blobCtrl;
  late final AnimationController _spinCtrl;
  MascotPhase _phase = MascotPhase.idle;

  // 近圆软 blob 关键帧 [tlx,tly,trx,try,brx,bry,blx,bly]
  static const _blobFrames = <List<double>>[
    [0.52, 0.50, 0.48, 0.52, 0.50, 0.48, 0.50, 0.50],
    [0.54, 0.46, 0.46, 0.54, 0.54, 0.46, 0.46, 0.54],
    [0.56, 0.48, 0.44, 0.56, 0.52, 0.44, 0.48, 0.52],
    [0.46, 0.54, 0.54, 0.46, 0.48, 0.54, 0.52, 0.46],
    [0.50, 0.52, 0.50, 0.48, 0.54, 0.50, 0.46, 0.50],
  ];

  @override
  void initState() {
    super.initState();
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    );
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _phase = widget.phase;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant AIMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
    if (widget.phase != _phase) {
      final enteringCelebrate = widget.phase == MascotPhase.celebrate;
      _phase = widget.phase;
      if (enteringCelebrate && !_reduce) _spinCtrl.forward(from: 0);
    }
  }

  bool get _reduce =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _syncMotion() {
    if (_reduce) {
      _blobCtrl.stop();
      _blobCtrl.value = 0.35;
    } else if (!_blobCtrl.isAnimating) {
      _blobCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  /// spinBounce：前 65% 一圈，后 35% 阻尼回弹。
  ({double angle, double hopY, double scale, double eyeBoost}) _spinPose() {
    final t = _spinCtrl.value;
    if (t <= 0) {
      return (angle: 0, hopY: 0, scale: 1, eyeBoost: 1);
    }
    if (t < 0.65) {
      final p = t / 0.65;
      final hop = math.sin(p * math.pi);
      return (
        angle: Curves.easeOutCubic.transform(p) * 2 * math.pi,
        hopY: -hop * widget.size * 0.14,
        scale: 1 + hop * 0.08,
        eyeBoost: 1 + hop * 0.06,
      );
    }
    final p = (t - 0.65) / 0.35;
    final decay = (1 - p) * (1 - p);
    final wobble = math.sin(p * math.pi * 2);
    return (
      angle: wobble * 0.14 * decay,
      hopY: wobble * widget.size * 0.03 * decay,
      scale: 1 + wobble * 0.03 * decay,
      eyeBoost: 1,
    );
  }

  ({double angle, double tx, double ty, double eyeBoost, Offset eyeShift})
  _phasePose(double seconds) {
    final s = widget.size / 40.0;
    switch (widget.phase) {
      case MascotPhase.searching:
        final et = math.sin(seconds * 1.3);
        return (
          angle: et * 13 * math.pi / 180,
          tx: et * 6.5 * s,
          ty: math.sin(seconds * 1.7) * 2.5 * s,
          eyeBoost: 1.04,
          eyeShift: Offset(et * 2.8 * s, math.sin(seconds * 2.1) * 1.1 * s),
        );
      case MascotPhase.celebrate:
        return (
          angle: 0,
          tx: math.sin(seconds * 0.9) * 1.2 * s,
          ty: -math.sin(seconds * 1.6).abs() * 2.2 * s,
          eyeBoost: 1.08,
          eyeShift: Offset(0.5 * s, -1.8 * s),
        );
      case MascotPhase.idle:
        return (
          angle: 0,
          tx: 0,
          ty: 0,
          eyeBoost: 1,
          eyeShift: Offset.zero,
        );
    }
  }

  Offset get _baseEyeShift => !widget.awake
      ? const Offset(0.5, -0.5)
      : widget.lookLeft
          ? const Offset(-2, -0.5)
          : const Offset(0.5, -2);

  double _blink(double seconds, double period, double a, double b, double depth) {
    final p = (seconds % period) / period;
    if (p < a || p > b) return 1;
    final t = (p - a) / (b - a);
    return 1 - depth * (t < 0.5 ? t * 2 : (1 - t) * 2);
  }

  double _blinkScale(double seconds) => widget.phase == MascotPhase.searching
      ? _blink(seconds, 6.2, 0.55, 0.58, 0.75)
      : _blink(seconds, 4.5, 0.38, 0.42, 0.90);

  BorderRadius _blobRadius(double t) {
    final s = widget.size;
    BorderRadius br(List<double> f) => BorderRadius.only(
          topLeft: Radius.elliptical(f[0] * s, f[1] * s),
          topRight: Radius.elliptical(f[2] * s, f[3] * s),
          bottomRight: Radius.elliptical(f[4] * s, f[5] * s),
          bottomLeft: Radius.elliptical(f[6] * s, f[7] * s),
        );
    final frames = [for (final f in _blobFrames) br(f), br(_blobFrames.first)];
    final seg = t * (frames.length - 1);
    final i = seg.floor().clamp(0, frames.length - 2);
    return BorderRadius.lerp(frames[i], frames[i + 1], seg - i)!;
  }

  Widget _ball({required double ball, required double eyeW, required double eyeH, required double eyeGap}) {
    final c = context.colors;
    return Container(
      width: ball,
      height: ball,
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(ball * 0.48),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _eye(eyeW, eyeH),
            SizedBox(width: eyeGap),
            _eye(eyeW, eyeH),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduce;
    final ball = widget.size;
    final eyeH = ball * 0.225;
    final eyeW = ball * 0.10;
    final eyeGap = ball * 0.175;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_blobCtrl, _spinCtrl]),
        builder: (context, _) {
          if (reduce) return _ball(ball: ball, eyeW: eyeW, eyeH: eyeH, eyeGap: eyeGap);

          final seconds = DateTime.now().millisecondsSinceEpoch / 1000;
          final spin = _spinPose();
          final phase = _phasePose(seconds);
          final rotate = (widget.awake ? 6 : -7) * math.pi / 180 + spin.angle + phase.angle;
          final shift = phase.eyeShift == Offset.zero ? _baseEyeShift : phase.eyeShift;
          final scale = (widget.awake ? 1.05 : 1.0) * spin.scale;
          final blink = _blinkScale(seconds) * spin.eyeBoost * phase.eyeBoost;
          final c = context.colors;

          return Transform.translate(
            offset: Offset(phase.tx, phase.ty + spin.hopY),
            child: Transform.rotate(
              angle: rotate,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: ball,
                  height: ball,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: _blobRadius(_blobCtrl.value),
                  ),
                  child: Center(
                    child: Transform.translate(
                      offset: shift,
                      child: Transform.scale(
                        scaleY: blink,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _eye(eyeW, eyeH),
                            SizedBox(width: eyeGap),
                            _eye(eyeW, eyeH),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _eye(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(h),
        ),
      );
}

/// 菜单栏右侧的独立 AI 圆钮：玻璃圆壳 + 内嵌小球。
class AiBallButton extends StatefulWidget {
  final VoidCallback? onTap;

  const AiBallButton({super.key, this.onTap});

  @override
  State<AiBallButton> createState() => _AiBallButtonState();
}

class _AiBallButtonState extends State<AiBallButton> {
  bool _awake = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const size = 64.0;

    return Semantics(
      button: true,
      label: 'AI 情况说明',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _awake = true),
        onTapCancel: () => setState(() => _awake = false),
        onTap: () {
          setState(() => _awake = false);
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: _awake ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A2722).withValues(alpha: 0.78)
                      : const Color(0xFFF8FAFC).withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : const Color(0xFFCBD5E1).withValues(alpha: 0.6),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.55 : 0.22),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Center(
                  child: AIMascot(
                    awake: _awake,
                    lookLeft: true,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
