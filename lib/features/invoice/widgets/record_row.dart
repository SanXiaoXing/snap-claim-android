// 明细记录行；编辑页用 Dismissible 包裹以支持左滑删除（滑出后弹确认框）。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../models/record.dart';
import 'chips.dart';

class RecordRow extends StatelessWidget {
  final Record record;

  const RecordRow({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: record.category.iconBg(b),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(record.category.icon, size: 18, color: record.category.iconFg(b)),
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
                    fontSize: 14,
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
                  style: TextStyle(fontSize: 12, color: c.fgMuted),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.fg,
                ),
              ),
              const SizedBox(height: 4),
              CategoryBadge(category: record.category),
            ],
          ),
        ],
      ),
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
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '删除明细',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.fg,
          ),
        ),
        content: Text(
          '确定删除「${widget.record.title}」吗？此操作不可恢复。',
          style: TextStyle(fontSize: 14, color: c.fgMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消', style: TextStyle(fontSize: 14, color: c.fgMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '删除',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.danger,
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
          widget.onTripTypeChanged?.call(swapTarget);
          return false;
        }
        return _confirmDelete();
      },
      onDismissed: (_) => widget.onDismissed(),
      background: canSwapTrip
          ? _buildSwapBackground(c, swapTarget.label)
          : _buildDeleteBackground(c),
      secondaryBackground:
          canSwapTrip ? _buildDeleteBackground(c) : null,
      child: RecordRow(record: widget.record),
    );
  }

  /// 左滑删除背景（右侧，品牌危险色渐变），与归档页删除效果保持一致。
  Widget _buildDeleteBackground(AppColorScheme c) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.danger,
            Color.lerp(c.danger, c.dangerBg, 0.3)!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '删除',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 右滑切换背景（左侧，用车品牌色），与归档撤销效果保持一致，
  /// 图标在前、文字在后，文案提示切换目标类型。
  Widget _buildSwapBackground(AppColorScheme c, String targetLabel) {
    final base = RecordCategory.car.base;
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            base,
            Color.lerp(base, c.card, 0.35)!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_horiz, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '切换为$targetLabel',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
