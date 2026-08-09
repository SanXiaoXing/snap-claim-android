// 首页圆形创建按钮，带呼吸光环动画，对应原型 .create-cta。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class CreateCta extends StatefulWidget {
  final VoidCallback onTap;

  const CreateCta({super.key, required this.onTap});

  @override
  State<CreateCta> createState() => _CreateCtaState();
}

class _CreateCtaState extends State<CreateCta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  // 按下态：pointer-down 立即反馈（缩小），抬起/取消恢复。
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 减少动态：不做呼吸光环动画（避免持续性慢速振荡）。
    // 需在依赖就绪后读取 MediaQuery（initState 内不允许查询）。
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            // 按下立即缩小 0.94，抬起回弹（反馈活在按下的那一刻）。
            scale: _pressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 外层 accentBg 光晕底环。
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: c.accentBg,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // 呼吸光环（减少动态时不重复，光环静置于初值）。
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, child) {
                      final t = _ctrl.value;
                      return Transform.scale(
                        scale: 1 + 0.65 * t,
                        child: Opacity(
                          opacity: (1 - t) * 0.8,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.accent.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  // 主按钮。
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [c.accent, c.accentLight],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: c.accent.withValues(alpha: 0.45),
                          blurRadius: 36,
                          offset: const Offset(0, 16),
                          spreadRadius: -12,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, size: 44, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: [
            Text(
              '创建报销单',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.fg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '扫码 · OCR · 手动录入',
              style: TextStyle(fontSize: 11, color: c.fgMuted),
            ),
          ],
        ),
      ],
    );
  }
}
