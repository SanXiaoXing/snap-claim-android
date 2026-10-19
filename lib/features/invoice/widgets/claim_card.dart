// 报销单卡片，用于首页「最近报销单」与历史记录页（「未报销」/「已报销」两个 tab）。
// 金额统一显示退补金额（= 火车 + 高速费 + 地铁费 + 差补）；已归档（已报销）显示「已报销」徽章。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/claim_deadline.dart';
import '../models/claim.dart';
import '../models/record.dart';
import 'chips.dart';

class ClaimCard extends StatelessWidget {
  final Claim claim;
  final VoidCallback? onTap;
  final ValueChanged<Claim>? onSaveClaim;

  const ClaimCard({
    super.key,
    required this.claim,
    this.onTap,
    this.onSaveClaim,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final daysLeft = claimDaysLeft(claim, DateTime.now());
    final warning = claimNeedsWarning(claim, DateTime.now());
    final warningColor = c == AppColorScheme.dark
        ? const Color(0xFF382719)
        : const Color(0xFFFFF1DC);
    return Material(
      color: warning ? warningColor : c.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onSaveClaim == null || claim.archived
            ? null
            : () => _chooseStatus(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: warning
              ? cardDecoration(c).copyWith(
                  color: warningColor,
                  border: Border.all(color: const Color(0xFFF4BA73)),
                )
              : cardDecoration(c),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.accentBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.work_outline, size: 20, color: c.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      claim.name,
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
                      '${claim.records.length} 张票据 · ${fmtSaved(claim.savedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.fgMuted),
                    ),
                    if (warning) ...[
                      const SizedBox(height: 4),
                      Text(
                        daysLeft < 0
                            ? '已逾期 ${-daysLeft} 天 · 长按更新状态'
                            : daysLeft == 0
                            ? '今天截止 · 长按更新状态'
                            : '剩余 $daysLeft 天 · 长按更新状态',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB45F08),
                        ),
                      ),
                    ],
                    RecTagsRow(counts: claim.tagCounts),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!claim.archived && claim.submittedToFinance) ...[
                    const _SubmittedBadge(),
                    const SizedBox(height: 5),
                  ],
                  Text(
                    fmtMoneyShort(claim.balanceAmount),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.accent,
                    ),
                  ),
                  // 超标金额（人工填写）以胶囊形式展示在金额下方，超标部分不予以报销。
                  if (claim.excessAmount > 0) ...[
                    const SizedBox(height: 4),
                    _ExcessAmountPill(claim: claim, c: c),
                  ],
                  if (claim.archived) ...[
                    const SizedBox(height: 4),
                    const _ReimbursedBadge(),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseStatus(BuildContext context) async {
    final status = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('报销流程状态')),
            ListTile(
              leading: const Icon(Icons.pending_actions_outlined),
              title: const Text('流程未完成'),
              trailing: !claim.submittedToFinance
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(sheetContext, false),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: const Text('已提交财务 · 待打款'),
              trailing: claim.submittedToFinance
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(sheetContext, true),
            ),
          ],
        ),
      ),
    );
    if (status != null && status != claim.submittedToFinance) {
      onSaveClaim?.call(claim.copyWith(submittedToFinance: status));
    }
  }
}

class _SubmittedBadge extends StatelessWidget {
  const _SubmittedBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF0F9B75),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      '待打款',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

/// 超标金额胶囊：警示色图标 + 金额，与汇总胶囊（SummaryPill）同款样式，
/// 用于在卡片金额下方展示人工填写的超标金额。
class _ExcessAmountPill extends StatelessWidget {
  final Claim claim;
  final AppColorScheme c;

  const _ExcessAmountPill({required this.claim, required this.c});

  @override
  Widget build(BuildContext context) {
    final style = summaryRowStyles['超标金额']!;
    final isDark = c == AppColorScheme.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: style.color.withValues(alpha: isDark ? 0.30 : 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 12, color: style.color),
          const SizedBox(width: 4),
          Text(
            '超标 ${fmtMoneyShort(claim.excessAmount)}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 「已报销」小徽章（归档状态标记）。
class _ReimbursedBadge extends StatelessWidget {
  const _ReimbursedBadge();

  @override
  Widget build(BuildContext context) {
    final base = RecordCategory.car.base;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '已报销',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.02,
        ),
      ),
    );
  }
}
