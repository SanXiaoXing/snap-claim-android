// 报销单卡片，用于首页「最近报销单」、历史记录与归档页面。
// 金额统一显示退补金额（= 火车 + 差补）；已归档（已报销）显示「已报销」徽章。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../models/claim.dart';
import '../models/record.dart';
import 'chips.dart';

class ClaimCard extends StatelessWidget {
  final Claim claim;
  final VoidCallback? onTap;

  const ClaimCard({super.key, required this.claim, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
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
                    RecTagsRow(counts: claim.tagCounts),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fmtMoneyShort(claim.balanceAmount),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.accent,
                    ),
                  ),
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
