// AI 小球：移植 docs/design/askAI.md 中的 AIMascot 形象。
// 视觉：主色 blob + 两颗竖椭圆眼；blob 圆角缓慢形变，眼睛周期性眨眼。
// 减少动态时停形变、停眨眼，仅保留静态小球。
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

enum MascotGaze { up, down, left, right }

/// askAI 风格的 AI 小球形象。
class AIMascot extends StatefulWidget {
  /// 是否「醒着」：醒着时眼睛看向 [gaze]，并轻微上扬放大。
  final bool awake;

  /// 醒着时视线方向（指向弹层时用）。
  final MascotGaze? gaze;

  /// 小球直径。
  final double size;

  const AIMascot({
    super.key,
    this.awake = false,
    this.gaze,
    this.size = 32,
  });

  @override
  State<AIMascot> createState() => _AIMascotState();
}

class _AIMascotState extends State<AIMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blobCtrl;

  @override
  void initState() {
    super.initState();
    _blobCtrl = AnimationController(
      vsync: this,
      // 形变整圈 7.2s：花 / 叶 / 三角 / 菱形轮播，比纯 blob 更有戏。
      duration: const Duration(milliseconds: 7200),
    );
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
  }

  void _syncMotion() {
    final reduce =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _blobCtrl.stop();
      _blobCtrl.value = 0.35;
    } else {
      if (!_blobCtrl.isAnimating) _blobCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    super.dispose();
  }

  Offset get _eyeShift {
    if (!widget.awake) {
      return const Offset(0.5, -0.5);
    }
    return switch (widget.gaze) {
      MascotGaze.down => const Offset(0.5, 2),
      MascotGaze.left => const Offset(-2, -0.5),
      MascotGaze.right => const Offset(2, -0.5),
      MascotGaze.up || null => const Offset(0.5, -2),
    };
  }

  /// 眨眼：4.5s 周期，约 38%–42% 处眨眼（比原先 6.5s 更明快）。
  double _blinkScale(double seconds) {
    final phase = (seconds % 4.5) / 4.5;
    if (phase >= 0.38 && phase <= 0.42) {
      final t = (phase - 0.38) / 0.04;
      final mid = t < 0.5 ? t * 2 : (1 - t) * 2;
      return 1 - 0.90 * mid;
    }
    return 1;
  }

  BorderRadius _blobRadius(double t) {
    // 全程接近圆的软有机形：轻微不对称呼吸，无尖角。
    // 关键帧比例都落在 0.44–0.56，视觉上始终像圆球在轻轻「呼吸」。
    BorderRadius nearCircle = BorderRadius.only(
      topLeft: Radius.elliptical(0.52, 0.50),
      topRight: Radius.elliptical(0.48, 0.52),
      bottomRight: Radius.elliptical(0.50, 0.48),
      bottomLeft: Radius.elliptical(0.50, 0.50),
    );
    BorderRadius softFlower = BorderRadius.only(
      topLeft: Radius.elliptical(0.54, 0.46),
      topRight: Radius.elliptical(0.46, 0.54),
      bottomRight: Radius.elliptical(0.54, 0.46),
      bottomLeft: Radius.elliptical(0.46, 0.54),
    );
    BorderRadius softLeaf = BorderRadius.only(
      topLeft: Radius.elliptical(0.56, 0.48),
      topRight: Radius.elliptical(0.44, 0.56),
      bottomRight: Radius.elliptical(0.52, 0.44),
      bottomLeft: Radius.elliptical(0.48, 0.52),
    );
    BorderRadius softDrop = BorderRadius.only(
      topLeft: Radius.elliptical(0.46, 0.54),
      topRight: Radius.elliptical(0.54, 0.46),
      bottomRight: Radius.elliptical(0.48, 0.54),
      bottomLeft: Radius.elliptical(0.52, 0.46),
    );
    BorderRadius ease = BorderRadius.only(
      topLeft: Radius.elliptical(0.50, 0.52),
      topRight: Radius.elliptical(0.50, 0.48),
      bottomRight: Radius.elliptical(0.54, 0.50),
      bottomLeft: Radius.elliptical(0.46, 0.50),
    );

    BorderRadius scale(BorderRadius r, double s) => BorderRadius.only(
          topLeft: Radius.elliptical(r.topLeft.x * s, r.topLeft.y * s),
          topRight: Radius.elliptical(r.topRight.x * s, r.topRight.y * s),
          bottomRight:
              Radius.elliptical(r.bottomRight.x * s, r.bottomRight.y * s),
          bottomLeft:
              Radius.elliptical(r.bottomLeft.x * s, r.bottomLeft.y * s),
        );

    final s = widget.size;
    // 五段：近圆 → 轻花 → 叶 → 水滴 → 过渡 → 近圆
    final frames = [
      scale(nearCircle, s),
      scale(softFlower, s),
      scale(softLeaf, s),
      scale(softDrop, s),
      scale(ease, s),
      scale(nearCircle, s),
    ];
    final seg = t * (frames.length - 1);
    final i = seg.floor().clamp(0, frames.length - 2);
    return BorderRadius.lerp(frames[i], frames[i + 1], seg - i)!;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final ball = widget.size;
    final eyeH = ball * 0.225;
    final eyeW = ball * 0.10;
    final eyeGap = ball * 0.175;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _blobCtrl,
        builder: (context, _) {
          final blink = reduce ? 1.0 : _blinkScale(
            DateTime.now().millisecondsSinceEpoch / 1000,
          );
          final t = _blobCtrl.value;
          final awakeScale = widget.awake ? 1.05 : 1.0;
          final rotate = (widget.awake ? 6 : -7) * math.pi / 180;
          final shift = _eyeShift;

          return Transform.rotate(
            angle: reduce ? 0 : rotate,
            child: Transform.scale(
              scale: reduce ? 1 : awakeScale,
              child: Container(
                width: ball,
                height: ball,
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: reduce
                      ? BorderRadius.circular(ball * 0.48)
                      : _blobRadius(t),
                ),
                child: Center(
                  child: Transform.translate(
                    offset: reduce ? Offset.zero : shift,
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
          );
        },
      ),
    );
  }

  Widget _eye(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(h),
      ),
    );
  }
}

/// 菜单栏右侧的独立 AI 圆钮：玻璃圆壳 + 内嵌小球。
/// 与主菜单胶囊物理分隔，对应 askAI 的 blobOnly 触发器形态。
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
    // 与主胶囊高度一致（MainShell 胶囊 64）。
    const size = 64.0;
    final mascotSize = 40.0;

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
                    gaze: MascotGaze.left,
                    size: mascotSize,
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
