// 明细记录行；编辑页用 Dismissible 包裹以支持左滑删除（滑出后弹确认框）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../models/record.dart';
import 'chips.dart';
import 'swipe_background.dart';

class RecordRow extends StatelessWidget {
  final Record record;

  /// 紧凑版（分享卡片用）：更小字号、固定浅色配色，且不带卡片容器。
  final bool compact;

  const RecordRow({super.key, required this.record, this.compact = false});

  @override
  Widget build(BuildContext context) {
    // 紧凑版固定浅色配色：分享卡片强制浅色，不能依赖当前主题。
    final c = compact ? AppColorScheme.light : context.colors;
    final b = Theme.of(context).brightness;
    final iconBox = compact ? 28.0 : 40.0;
    final iconSize = compact ? 14.0 : 18.0;
    final row = Row(
      children: [
        Container(
          width: iconBox,
          height: iconBox,
          decoration: BoxDecoration(
            color: compact
                ? record.category.base.withValues(alpha: 0.14)
                : record.category.iconBg(b),
            borderRadius: BorderRadius.circular(compact ? 8 : 12),
          ),
          child: Icon(
            record.category.icon,
            size: iconSize,
            color: compact ? record.category.lightFg : record.category.base,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                record.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  color: c.fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                // 用车记录无备注时，展示「市内交通 / 往返交通」类型标记。
                record.subtitle.isEmpty &&
                        record.category == RecordCategory.car
                    ? (record.carTripType?.label ?? '')
                    : record.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 10 : 12,
                  color: compact ? c.fgSoft : c.fgMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fmtMoney(record.amount),
              style: TextStyle(
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: c.fg,
              ),
            ),
            const SizedBox(height: 4),
            CategoryBadge(category: record.category),
          ],
        ),
      ],
    );
    if (compact) return row;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: cardDecoration(c).copyWith(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: row,
    );
  }
}

/// 可左滑删除 /（用车）右滑切换类型的明细行，对应原型中的 swipe-row。
///
/// 左滑越过阈值后滑出，弹确认框删除；用车记录右滑越过阈值直接切换
/// 市内交通 ↔ 往返交通（行保留回弹）。仅 [onTripTypeChanged] 非空时启用右滑。
/// 滑动背景样式与归档 / 归档删除保持一致：图标 + 文字，无缩放放大动效。
class DismissibleRecordRow extends StatefulWidget {
  final Record record;
  final VoidCallback onDismissed;
  final Key dismissKey;

  /// 切换用车行程类型（市内/往返）；仅用车记录传入，非空时启用右滑。
  final ValueChanged<CarTripType>? onTripTypeChanged;

  const DismissibleRecordRow({
    super.key,
    required this.record,
    required this.onDismissed,
    required this.dismissKey,
    this.onTripTypeChanged,
  });

  @override
  State<DismissibleRecordRow> createState() => _DismissibleRecordRowState();
}

class _DismissibleRecordRowState extends State<DismissibleRecordRow> {
  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: '删除明细',
        content: Text(
          '确定删除「${widget.record.title}」吗？此操作不可恢复。',
          style: TextStyle(fontSize: 14, color: ctx.colors.fgMuted, height: 1.5),
        ),
        actions: [
          appDialogButton(ctx, onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '删除',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ctx.colors.danger,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // 仅用车记录启用右滑切换；右滑目标为当前类型的反向。
    final canSwapTrip = widget.record.category == RecordCategory.car &&
        widget.onTripTypeChanged != null;
    final swapTarget = widget.record.isRoundTripCar
        ? CarTripType.city
        : CarTripType.roundTrip;
    return Dismissible(
      key: widget.dismissKey,
      direction: canSwapTrip
          ? DismissDirection.horizontal
          : DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.35,
        // 右滑切换只需轻滑即可触发，避免拖过半个屏幕。
        DismissDirection.startToEnd: 0.25,
      },
      movementDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 160),
      resizeDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      confirmDismiss: (direction) async {
        // 右滑：切换市内/往返，行保留回弹；左滑：走删除确认。
        if (direction == DismissDirection.startToEnd) {
          // 切换行程类型时给轻微震动反馈，让用户感知切换已生效。
          HapticFeedback.lightImpact();
          widget.onTripTypeChanged?.call(swapTarget);
          return false;
        }
        return _confirmDelete();
      },
      onDismissed: (_) => widget.onDismissed(),
      background: canSwapTrip
          ? SwipeBackground(
              icon: Icons.swap_horiz,
              label: '切换为${swapTarget.label}',
              from: RecordCategory.car.base,
              to: Color.lerp(RecordCategory.car.base, c.card, 0.35)!,
              alignment: Alignment.centerLeft,
            )
          : _deleteBackground(c),
      secondaryBackground: canSwapTrip ? _deleteBackground(c) : null,
      child: RecordRow(record: widget.record),
    );
  }

  /// 左滑删除背景（红色，右侧），与归档页删除效果保持一致。
  Widget _deleteBackground(AppColorScheme c) {
    return SwipeBackground(
      icon: Icons.delete_outline,
      label: '删除',
      from: c.danger,
      to: Color.lerp(c.danger, c.dangerBg, 0.3)!,
      alignment: Alignment.centerRight,
    );
  }
}
