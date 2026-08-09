// 扫描线组件：在轨道内自上而下移动的发光高亮线，
// 用于 OCR 识别进度弹窗、二维码扫描取景框等“识别中 / 扫描中”反馈场景。
import 'package:flutter/material.dart';

/// 横向扫描线：随 [progress]（0→1）在 [trackHeight] 高的轨道内上下移动，
/// 边缘渐变淡出 + 底部柔光。需置于 Stack 内使用。
class ScanLine extends StatelessWidget {
  final Animation<double> progress;
  final double trackHeight;
  final Color color;

  const ScanLine({
    super.key,
    required this.progress,
    required this.trackHeight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final top = trackHeight * progress.value - 1;
        return Positioned(
          top: top,
          left: 0,
          right: 0,
          height: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0),
                  color,
                  color,
                  color.withValues(alpha: 0),
                ],
                stops: const [0, 0.2, 0.8, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
