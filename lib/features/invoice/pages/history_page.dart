// 历史记录：按月分组的报销单列表（未归档）；右上角进入归档页面。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../models/claim.dart';
import '../models/record.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/claim_card.dart';
import '../widgets/empty_hint.dart';
import '../widgets/swipe_background.dart';
import 'archive_page.dart';
import 'detail_page.dart';

class HistoryPage extends StatelessWidget {
  final List<Claim> claims;
  final ValueChanged<Claim> onSaveClaim;

  /// 左滑归档回调（归档 = 已报销，无需二次确认）。
  final ValueChanged<Claim> onArchiveClaim;
  final ValueChanged<Claim> onRestoreClaim;
  final ValueChanged<Claim> onDeleteClaim;

  const HistoryPage({
    super.key,
    required this.claims,
    required this.onSaveClaim,
    required this.onArchiveClaim,
    required this.onRestoreClaim,
    required this.onDeleteClaim,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // 历史列表只展示未归档的报销单，已归档的进入归档页面。
    final visible = claims.where((e) => !e.archived).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    // 按年月分组，保持倒序。
    final groups = <String, List<Claim>>{};
    for (final claim in visible) {
      final key = fmtYm(claim.startDate);
      groups.putIfAbsent(key, () => []).add(claim);
    }

    return Column(
      children: [
        AppTopBar(
          title: '历史记录',
          trailing: AppIconButton(
            icon: Icons.archive_outlined,
            size: 18,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArchivePage(
                  claims: claims.where((e) => e.archived).toList(),
                  onRestore: onRestoreClaim,
                  onDelete: onDeleteClaim,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            child: groups.isEmpty
                ? const EmptyHint(
                    icon: Icons.archive_outlined,
                    text: '暂无历史记录',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 10),
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: c.fgMuted,
                            ),
                          ),
                        ),
                        for (final claim in entry.value) ...[
                          // 左滑直接归档（无二次确认），行滑出后由上层刷新移除。
                          Dismissible(
                            key: ValueKey('archive-${claim.id}'),
                            direction: DismissDirection.endToStart,
                            dismissThresholds: const {
                              DismissDirection.endToStart: 0.35,
                            },
                            onDismissed: (_) => onArchiveClaim(claim),
                            background: SwipeBackground(
                              icon: Icons.archive_outlined,
                              label: '归档',
                              from: RecordCategory.car.base,
                              to: Color.lerp(RecordCategory.car.base, c.card, 0.35)!,
                              alignment: Alignment.centerRight,
                            ),
                            child: ClaimCard(
                              claim: claim,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DetailPage(
                                    claim: claim,
                                    onSave: onSaveClaim,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

