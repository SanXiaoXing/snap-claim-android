// 滑动分段 tab：轨道 + accent 弹簧胶囊（复用 SlidingPill）+ 标签（可带数量）。
//
// 交互：
// - 点按任一标签 → 立即回传 onChanged。
// - 按住 tab 栏横向拖动 → 胶囊实时跟手（SlidingPill(animate: false)），
//   松手按「位移过半格 或 甩动速度足够」决定切到相邻项，否则回弹。
// - 减少动态（disableAnimations）→ 不做跟手位移与弹簧，直接切换。
// - 触感：**仅在真正发生 tab 切换时** selectionClick；拖动未过阈值回弹不给反馈。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../app/theme.dart';
import 'sliding_pill.dart';

class SlidingSegmentedTabs extends StatefulWidget {
  /// 当前选中下标（由父级持有，本组件不私存真相）。
  final int index;

  /// 各分段文案。
  final List<String> labels;

  /// 各分段数量（可选），显示在文案右侧；长度不足的项不显示。
  final List<int>? counts;

  /// 切换回调（点按命中 / 拖动过阈值 / 甩动命中都会触发）。
  final ValueChanged<int> onChanged;

  const SlidingSegmentedTabs({
    super.key,
    required this.index,
    required this.labels,
    this.counts,
    required this.onChanged,
  });

  @override
  State<SlidingSegmentedTabs> createState() => _SlidingSegmentedTabsState();
}

class _SlidingSegmentedTabsState extends State<SlidingSegmentedTabs> {
  /// 轨道高度（含 1px 上下描边）。
  static const _trackHeight = 38.0;

  /// 胶囊相对轨道的四周内缩：轨道圆角 19，胶囊圆角 16，二者构成同心圆角。
  static const _pillInset = 3.0;

  /// 甩动判定速度（逻辑像素/秒）：超过则按方向切一格（配合「位移过半格」）。
  static const _flingVelocity = 300.0;

  bool _dragging = false;
  double _dragDx = 0;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  void _onTap(int i) {
    if (i == widget.index) return;
    HapticFeedback.selectionClick();
    widget.onChanged(i);
  }

  void _onDragStart() {
    setState(() {
      _dragging = true;
      _dragDx = 0;
    });
  }

  void _onDragUpdate(double dx) {
    setState(() => _dragDx += dx);
  }

  void _onDragEnd(DragEndDetails details, double slot) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    var target = widget.index;
    if (_dragDx.abs() > slot / 2) {
      // 位移过半格 → 按拖动方向切一格。
      target = widget.index + (_dragDx > 0 ? 1 : -1);
    } else if (velocity.abs() > _flingVelocity) {
      // 位移不足但甩动够快 → 按甩动方向切一格。
      target = widget.index + (velocity > 0 ? 1 : -1);
    }
    target = target.clamp(0, widget.labels.length - 1);
    final changed = target != widget.index;
    setState(() {
      _dragging = false;
      _dragDx = 0;
    });
    // 未过阈值 → 只回弹，不发触感；真正切换才给 selectionClick。
    if (changed) {
      HapticFeedback.selectionClick();
      widget.onChanged(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
          final slot = trackWidth / widget.labels.length;
          final restLeft = widget.index * slot + _pillInset;
          // 跟手：拖拽（且非减少动态）时胶囊左缘 = 静止位置 + 累计位移，
          // 并夹在轨道内，避免拖出边界。
          final pillLeft = _dragging && !_reduceMotion
              ? (restLeft + _dragDx)
                  .clamp(_pillInset, trackWidth - slot + _pillInset)
                  .toDouble()
              : restLeft;
          return GestureDetector(
            // 整条轨道接收横向拖动；标签自身的 onTap 与外层拖动手势同台竞技，
            // 无位移时 tap 胜出、有位移时 drag 胜出。
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _onDragStart(),
            onHorizontalDragUpdate: (d) => _onDragUpdate(d.delta.dx),
            onHorizontalDragEnd: (d) => _onDragEnd(d, slot),
            child: Stack(
              children: [
                SlidingPill(
                  left: pillLeft,
                  width: slot - _pillInset * 2,
                  top: _pillInset,
                  bottom: _pillInset,
                  radius: 16,
                  // 拖拽跟手 / 减少动态 → 不做弹簧；否则弹簧收敛。
                  animate: !_dragging && !_reduceMotion,
                ),
                Row(
                  children: [
                    for (var i = 0; i < widget.labels.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _onTap(i),
                          child: _TabLabel(
                            text: widget.labels[i],
                            count: (widget.counts != null &&
                                    i < widget.counts!.length)
                                ? widget.counts![i]
                                : null,
                            selected: i == widget.index,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
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
