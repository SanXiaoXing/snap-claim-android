import 'dart:ui' show PointerDeviceKind, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';

const double _rowHeight = 48;
const double _wheelHeight = _rowHeight * 5;

/// 24 小时制提醒时间选择器。小时和分钟独立循环。
Future<TimeOfDay?> showWheelTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _WheelTimePickerSheet(initialTime: initialTime),
  );
}

class _WheelTimePickerSheet extends StatefulWidget {
  const _WheelTimePickerSheet({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_WheelTimePickerSheet> createState() => _WheelTimePickerSheetState();
}

class _WheelTimePickerSheetState extends State<_WheelTimePickerSheet> {
  late int _hour = widget.initialTime.hour;
  late int _minute = widget.initialTime.minute;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final minutes = [for (var m = 0; m < 60; m++) m];
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  '报销提醒时间',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: c.fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '到期前 7 天发送一次提醒',
                  style: TextStyle(fontSize: 12, color: c.fgMuted),
                ),
                const SizedBox(height: 24),
                Center(
                  child: SizedBox(
                    width: 276,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Center(
                                child: Text(
                                  '小时',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.fgMuted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 28),
                            Expanded(
                              child: Center(
                                child: Text(
                                  '分钟',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.fgMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: _wheelHeight,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                top: _rowHeight * 2,
                                bottom: _rowHeight * 2,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: c.bgSecondary,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: c.border),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _WheelColumn(
                                      label: '小时',
                                      values: const [
                                        0,
                                        1,
                                        2,
                                        3,
                                        4,
                                        5,
                                        6,
                                        7,
                                        8,
                                        9,
                                        10,
                                        11,
                                        12,
                                        13,
                                        14,
                                        15,
                                        16,
                                        17,
                                        18,
                                        19,
                                        20,
                                        21,
                                        22,
                                        23,
                                      ],
                                      selected: _hour,
                                      reducedMotion: reducedMotion,
                                      autofocus: true,
                                      onChanged: (value) =>
                                          setState(() => _hour = value),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 28,
                                    child: Center(
                                      child: Text(
                                        ':',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: c.fg,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _WheelColumn(
                                      label: '分钟',
                                      values: minutes,
                                      selected: _minute,
                                      reducedMotion: reducedMotion,
                                      onChanged: (value) =>
                                          setState(() => _minute = value),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(TimeOfDay(hour: _hour, minute: _minute)),
                        child: const Text('确定'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WheelColumn extends StatefulWidget {
  const _WheelColumn({
    required this.label,
    required this.values,
    required this.selected,
    required this.reducedMotion,
    required this.onChanged,
    this.autofocus = false,
  });

  final String label;
  final List<int> values;
  final int selected;
  final bool reducedMotion;
  final ValueChanged<int> onChanged;
  final bool autofocus;

  @override
  State<_WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<_WheelColumn> {
  late final FixedExtentScrollController _controller;
  final FocusNode _focusNode = FocusNode();
  late int _selected = widget.selected;
  late final int _initialItem =
      widget.values.length * 1000 + widget.values.indexOf(widget.selected);

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _initialItem);
  }

  @override
  void didUpdateWidget(covariant _WheelColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != _selected) {
      _selected = widget.selected;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToItem(_nearestItemFor(widget.selected));
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int _nearestItemFor(int value) {
    final current = _controller.hasClients
        ? _controller.selectedItem
        : _initialItem;
    final count = widget.values.length;
    final logical = widget.values.indexOf(value);
    return (((current - logical) / count).round() * count + logical).clamp(
      0,
      1 << 30,
    );
  }

  void _goToItem(int item) {
    _focusNode.requestFocus();
    if (!_controller.hasClients) return;
    if (widget.reducedMotion) {
      _controller.jumpToItem(item);
    } else {
      _controller.animateToItem(
        item,
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _moveBy(int amount) {
    if (_controller.hasClients) {
      _goToItem(_controller.selectedItem + amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selectedIndex = widget.values.indexOf(_selected);
    final next = widget.values[(selectedIndex + 1) % widget.values.length];
    final previous =
        widget.values[(selectedIndex - 1 + widget.values.length) %
            widget.values.length];
    return Semantics(
      label: widget.label,
      value: _selected.toString().padLeft(2, '0'),
      increasedValue: next.toString().padLeft(2, '0'),
      decreasedValue: previous.toString().padLeft(2, '0'),
      onIncrease: () => _moveBy(1),
      onDecrease: () => _moveBy(-1),
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _moveBy(-1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _moveBy(1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ExcludeSemantics(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0, 0.18, 0.82, 1],
            ).createShader(bounds),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                scrollbars: false,
                overscroll: false,
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ListWheelScrollView.useDelegate(
                key: ValueKey('${widget.label}-wheel'),
                controller: _controller,
                itemExtent: _rowHeight,
                diameterRatio: widget.reducedMotion ? 100 : 1.55,
                perspective: widget.reducedMotion ? 0 : 0.003,
                physics: const _SoftSnapPhysics(),
                onSelectedItemChanged: (index) {
                  final value = widget.values[index % widget.values.length];
                  if (value == _selected) return;
                  setState(() => _selected = value);
                  widget.onChanged(value);
                  if (!widget.reducedMotion) HapticFeedback.selectionClick();
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (context, index) {
                    if (index < 0) return null;
                    final value = widget.values[index % widget.values.length];
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _goToItem(index),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final center = _controller.hasClients
                              ? _controller.offset / _rowHeight
                              : _initialItem.toDouble();
                          final distance = (center - index)
                              .abs()
                              .clamp(0.0, 2.5)
                              .toDouble();
                          final visualDistance = widget.reducedMotion
                              ? distance.roundToDouble()
                              : distance;
                          final opacity = (1 - visualDistance * 0.28).clamp(
                            0.30,
                            1.0,
                          );
                          return Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: widget.reducedMotion
                                  ? 1
                                  : 1 - visualDistance * 0.055,
                              child: Center(
                                child: Text(
                                  value.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: lerpDouble(
                                      27,
                                      22,
                                      (visualDistance / 2).clamp(0, 1),
                                    ),
                                    fontWeight: visualDistance < 0.6
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: c.fg,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftSnapPhysics extends FixedExtentScrollPhysics {
  const _SoftSnapPhysics({super.parent});

  @override
  _SoftSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _SoftSnapPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 1, stiffness: 240, damping: 29);
}
