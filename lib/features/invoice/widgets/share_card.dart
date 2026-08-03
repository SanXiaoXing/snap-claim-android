// 报销单分享卡片：将报销单渲染为一张适配图片分享的卡片。
// 关键点：固定宽度（360px），自包含配色，不依赖屏幕宽度；
// 被 [RepaintBoundary] 包裹后，可直接 toImage() 转为 PNG 分享。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../models/claim.dart';
import '../models/record.dart';
import 'chips.dart';

/// 报销单分享卡。
///
/// 固定渲染宽度 360，按内容自然撑高。
/// 明细展示前 [maxRecords] 条（默认 8），超出折叠为「…等 N 条」摘要，
/// 避免分享图过长。
class ShareCard extends StatelessWidget {
  final Claim claim;
  final int maxRecords;

  const ShareCard({
    super.key,
    required this.claim,
    this.maxRecords = 8,
  });

  /// 卡片主题：根据当前主题深浅选择底色 + 前景，确保截图美观。
  /// 分享场景通常希望卡片在微信 / 聊天窗里是浅色高对比的，
/// 强制使用浅色配色，避免深色卡片在多数聊天背景中显得突兀。
  AppColorScheme _palette(BuildContext context) => AppColorScheme.light;

  @override
  Widget build(BuildContext context) {
    final c = _palette(context);
    final w = 360.0;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: w,
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(c),
            const SizedBox(height: 16),
            _titleSection(c),
            const SizedBox(height: 18),
            _totalSection(c),
            const SizedBox(height: 18),
            _summaryGrid(c),
            if (claim.records.isNotEmpty) ...[
              const SizedBox(height: 18),
              _recordsSection(c),
            ],
            const SizedBox(height: 16),
            _footer(c),
          ],
        ),
      ),
    );
  }

  // 顶部品牌条：渐变背景 + 应用名 + 报销单类型标签。
  Widget _header(AppColorScheme c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.accent,
            Color.lerp(c.accent, c.accentLight, 0.5)!,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // Logo：应用品牌图标图片（白底圆角容器 + favicon）。
          Container(
            width: 36,
            height: 36,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              'assets/icon/favicon.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SnapClaim · 报销单',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  claim.archived ? '已归档' : '未归档',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 报销单标题 + 日期范围。
  Widget _titleSection(AppColorScheme c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            claim.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: c.fg,
              letterSpacing: -0.02,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: c.fgSoft),
              const SizedBox(width: 4),
              Text(
                '${fmtMd(claim.startDate)} → ${fmtMd(claim.endDate)}',
                style: TextStyle(fontSize: 12, color: c.fgMuted),
              ),
              const Spacer(),
              Icon(Icons.receipt_long_outlined, size: 12, color: c.fgSoft),
              const SizedBox(width: 4),
              Text(
                '${claim.records.length} 条明细',
                style: TextStyle(fontSize: 12, color: c.fgMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 报销总额（最大字号）+ 人民币大写。
  Widget _totalSection(AppColorScheme c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: c.accentBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '报销总额',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.accent,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              fmtMoneyShort(claim.total),
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: c.accent,
                letterSpacing: -0.03,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              toChineseCurrency(claim.total),
              style: TextStyle(fontSize: 11, color: c.fgMuted),
            ),
          ],
        ),
      ),
    );
  }

  // 分类汇总：两列网格，列出来自 Claim.summaryRows 的全部行。
  Widget _summaryGrid(AppColorScheme c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '分项明细',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.fg,
              ),
            ),
            const SizedBox(height: 10),
            for (final row in claim.summaryRows) ...[
              _SummaryRowItem(label: row.label, amount: row.amount, c: c),
              if (row != claim.summaryRows.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  // 明细列表：展示前 maxRecords 条，超出折叠。
  Widget _recordsSection(AppColorScheme c) {
    final shown = claim.records.take(maxRecords).toList();
    final hidden = claim.records.length - shown.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '明细记录',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.fg,
              ),
            ),
            const SizedBox(height: 10),
            for (final r in shown) ...[
              _ShareRecordRow(record: r, c: c),
              if (r != shown.last || hidden > 0) const SizedBox(height: 8),
            ],
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '…等 $hidden 条',
                  style: TextStyle(fontSize: 11, color: c.fgSoft),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 底部署名 + 生成时间。
  Widget _footer(AppColorScheme c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          // 底部品牌小标：favicon 缩略图。
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.asset(
              'assets/icon/favicon.png',
              width: 18,
              height: 18,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '由 SnapClaim 生成',
            style: TextStyle(fontSize: 11, color: c.fgMuted),
          ),
          const Spacer(),
          Text(
            fmtSaved(claim.savedAt),
            style: TextStyle(fontSize: 11, color: c.fgSoft),
          ),
        ],
      ),
    );
  }
}

class _SummaryRowItem extends StatelessWidget {
  final String label;
  final double amount;
  final AppColorScheme c;
  const _SummaryRowItem({
    required this.label,
    required this.amount,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: c.fgMuted),
        ),
        const Spacer(),
        Text(
          fmtMoneyShort(amount),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: amount == 0 ? c.fgSoft : c.fg,
          ),
        ),
      ],
    );
  }
}

class _ShareRecordRow extends StatelessWidget {
  final Record record;
  final AppColorScheme c;
  const _ShareRecordRow({required this.record, required this.c});

  @override
  Widget build(BuildContext context) {
    final subtitle = record.subtitle.isEmpty &&
            record.category == RecordCategory.car
        ? (record.carTripType?.label ?? '')
        : record.subtitle;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: record.category.base.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            record.category.icon,
            size: 14,
            color: record.category.lightFg,
          ),
        ),
        const SizedBox(width: 10),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.fg,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: c.fgSoft),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          fmtMoneyShort(record.amount),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.fg,
          ),
        ),
        // 占位，避免与 chips 中的同名类型冲突。
        const SizedBox(width: 6),
        CategoryBadge(category: record.category),
      ],
    );
  }
}
