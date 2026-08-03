// 分类标签：实心（卡片用）/ 描边带圆点（汇总用）/ 徽章（明细行用）。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../models/record.dart';

/// 明细行右侧的小徽章，例如「火车」。
class CategoryBadge extends StatelessWidget {
  final RecordCategory category;

  const CategoryBadge({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: category.badgeBg(b),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: category.badgeBorder(b)),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: category.badgeFg(b),
        ),
      ),
    );
  }
}

/// 分类标签胶囊。
/// [solid] 为 true 时使用实心品牌色（首页 / 历史卡片），
/// 为 false 时使用描边 + 圆点（编辑 / 详情汇总）。
class CategoryTagChip extends StatelessWidget {
  final RecordCategory category;
  final int count;
  final bool solid;

  const CategoryTagChip({
    super.key,
    required this.category,
    required this.count,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (solid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
        decoration: BoxDecoration(
          color: category.base,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${category.label} $count',
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.02,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.bgSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: category.base,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${category.label} $count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡片中实心标签行。
class RecTagsRow extends StatelessWidget {
  final Map<RecordCategory, int> counts;

  const RecTagsRow({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final cat in RecordCategory.values)
            if (counts[cat] != null)
              CategoryTagChip(category: cat, count: counts[cat]!, solid: true),
        ],
      ),
    );
  }
}

/// 编辑 / 详情页顶部的描边标签汇总。
class TagSummary extends StatelessWidget {
  final Map<RecordCategory, int> counts;

  const TagSummary({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final cat in RecordCategory.values)
            if (counts[cat] != null)
              CategoryTagChip(category: cat, count: counts[cat]!, solid: false),
        ],
      ),
    );
  }
}
