import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'swipe_background.dart';

/// 横向跟手的列表行。小幅滑动回位，中幅滑动露出按钮，超过半宽提交。
class SwipeAction {
  final IconData icon;
  final String label;
  final Color from;
  final Color to;
  final Future<bool> Function()? confirm;
  final VoidCallback onTriggered;
  final bool removesRow;

  const SwipeAction({
    required this.icon,
    required this.label,
    required this.from,
    required this.to,
    required this.onTriggered,
    this.confirm,
    this.removesRow = true,
  });
}

class SwipeActionRow extends StatefulWidget {
  final Widget child;

  /// 右滑时露在左侧的操作。
  final SwipeAction? leftAction;

  /// 左滑时露在右侧的操作。
  final SwipeAction? rightAction;
  final double bottomSpacing;

  const SwipeActionRow({
    super.key,
    required this.child,
    this.leftAction,
    this.rightAction,
    this.bottomSpacing = 0,
  });

  @override
  State<SwipeActionRow> createState() => _SwipeActionRowState();
}

class _SwipeActionRowState extends State<SwipeActionRow>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 300);
  static const _revealThreshold = 80.0;
  static const _buttonWidth = 152.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  )..addListener(_tick);
  double _fromOffset = 0;
  double _targetOffset = 0;
  double _fromExit = 0;
  double _targetExit = 0;
  double _offset = 0;
  double _width = 0;
  double _exitProgress = 0;
  bool _busy = false;
  bool _thresholdFeedbackSent = false;
  double _feedbackSide = 0;

  double get _commitThreshold =>
      (_width / 2).clamp(_revealThreshold, double.infinity);

  void _updateHaptics(double offset) {
    final distance = offset.abs();
    if (offset.sign != _feedbackSide || distance < _commitThreshold - 12) {
      // 明确回拖后才允许重新提醒，避免临界点附近抖动造成连续震动。
      _thresholdFeedbackSent = false;
    }
    _feedbackSide = offset.sign;
    if (distance >= _commitThreshold && !_thresholdFeedbackSent) {
      _thresholdFeedbackSent = true;
      HapticFeedback.mediumImpact();
    }
  }

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tick() {
    final t = Curves.easeOutCubic.transform(_controller.value);
    setState(() {
      _offset = _fromOffset + (_targetOffset - _fromOffset) * t;
      _exitProgress = _fromExit + (_targetExit - _fromExit) * t;
    });
  }

  Future<void> _animateTo(double target, {bool exiting = false}) async {
    _controller.stop();
    _fromOffset = _offset;
    _targetOffset = target;
    _fromExit = _exitProgress;
    _targetExit = exiting ? 1 : 0;
    if (_reduceMotion) {
      setState(() {
        _offset = target;
        _exitProgress = _targetExit;
      });
      return;
    }
    _controller.reset();
    await _controller.forward();
  }

  Future<void> _trigger(SwipeAction action, double direction) async {
    if (_busy) return;
    _busy = true;
    final approved = await (action.confirm?.call() ?? Future.value(true));
    if (!mounted) return;
    if (!approved) {
      _busy = false;
      _animateTo(0);
      return;
    }
    if (!action.removesRow) {
      // 类型切换只更新内容，整行保持高度和不透明度，然后收起操作区。
      action.onTriggered();
      if (!mounted) return;
      await _animateTo(0);
      if (mounted) setState(() => _busy = false);
      return;
    }
    await _animateTo(direction * _width, exiting: true);
    if (!mounted) return;
    action.onTriggered();
  }

  void _dragStart(DragStartDetails details) {
    if (_busy) return;
    _controller.stop();
    _thresholdFeedbackSent = _offset.abs() >= _commitThreshold;
    _feedbackSide = _offset.sign;
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (_busy) return;
    final next = (_offset + details.delta.dx).clamp(-_width, _width);
    if ((next > 0 && widget.leftAction == null) ||
        (next < 0 && widget.rightAction == null)) {
      return;
    }
    _updateHaptics(next);
    setState(() => _offset = next);
  }

  void _dragEnd(DragEndDetails details) {
    if (_busy) return;
    final distance = _offset.abs();
    final action = _offset > 0 ? widget.leftAction : widget.rightAction;
    if (action == null || distance < _revealThreshold) {
      _animateTo(0);
    } else if (distance >= _commitThreshold) {
      _trigger(action, _offset.sign);
    } else {
      _animateTo(_offset.sign * _buttonWidth.clamp(0, _width));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        final action = _offset >= 0 ? widget.leftAction : widget.rightAction;
        final side = _offset >= 0
            ? Alignment.centerLeft
            : Alignment.centerRight;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1 - _exitProgress,
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.bottomSpacing),
              child: SizedBox(
                width: constraints.maxWidth,
                child: Stack(
                  children: [
                    if (action != null)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: _busy
                              ? null
                              : () => _trigger(action, _offset.sign),
                          child: SwipeBackground(
                            icon: action.icon,
                            label: action.label,
                            from: action.from,
                            to: action.to,
                            alignment: side,
                          ),
                        ),
                      ),
                    Transform.translate(
                      offset: Offset(_offset, 0),
                      child: Opacity(
                        opacity: 1 - _exitProgress,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: _dragStart,
                          onHorizontalDragUpdate: _dragUpdate,
                          onHorizontalDragEnd: _dragEnd,
                          onHorizontalDragCancel: () {
                            if (_busy) return;
                            _animateTo(0);
                          },
                          child: widget.child,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
