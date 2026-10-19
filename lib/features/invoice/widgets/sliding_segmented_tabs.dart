// 分段 tab：轨道 + accent 弹簧胶囊（复用 SlidingPill）+ 标签（可带数量）。
//
// 点按标签切换，横向拖动不切换；仅在切换时触发 selectionClick。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../app/theme.dart';
import 'sliding_pill.dart';

class SlidingSegmentedTabs extends StatelessWidget {
  /// 当前选中下标（由父级持有，本组件不私存真相）。
  final int index;

  /// 各分段文案。
  final List<String> labels;

  /// 各分段数量（可选），显示在文案右侧；长度不足的项不显示。
  final List<int>? counts;

  /// 点按切换回调。
  final ValueChanged<int> onChanged;

  const SlidingSegmentedTabs({
    super.key,
    required this.index,
    required this.labels,
    this.counts,
    required this.onChanged,
  });

  /// 轨道高度（含 1px 上下描边）。
  static const _trackHeight = 38.0;

  /// 胶囊相对轨道的四周内缩：轨道圆角 19，胶囊圆角 16，二者构成同心圆角。
  static const _pillInset = 3.0;

  void _onTap(int i) {
    if (i == index) return;
    HapticFeedback.selectionClick();
    onChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      height: _trackHeight,
      decoration: BoxDecoration(
        color: c.bgSecondary,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: c.border, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          final slot = trackWidth / labels.length;
          final pillLeft = index * slot + _pillInset;
          return Stack(
            children: [
              SlidingPill(
                left: pillLeft,
                width: slot - _pillInset * 2,
                top: _pillInset,
                bottom: _pillInset,
                radius: 16,
                animate: !reduceMotion,
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _onTap(i),
                        child: _TabLabel(
                          text: labels[i],
                          count: (counts != null && i < counts!.length)
                              ? counts![i]
                              : null,
                          selected: i == index,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 单个标签：文案（选中白 / 未选 muted）+ 可选数量，颜色与字重用
/// AnimatedDefaultTextStyle 平滑过渡。
class _TabLabel extends StatelessWidget {
  final String text;
  final int? count;
  final bool selected;

  const _TabLabel({required this.text, required this.selected, this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // 选中态反白（与 _GlassTab 同款：accent 底上的固定白字对比组合）。
    final fg = selected ? Colors.white : c.fgMuted;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: fg,
            ),
            child: Text(text),
          ),
          if (count != null) ...[
            const SizedBox(width: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : c.fgSoft,
              ),
              child: Text('$count'),
            ),
          ],
        ],
      ),
    );
  }
}
