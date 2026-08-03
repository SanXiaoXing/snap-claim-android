// 历史记录：按月分组的报销单列表（未归档）；右上角进入归档页面。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../models/claim.dart';
import '../models/record.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/claim_card.dart';
import '../widgets/empty_hint.dart';
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
                            background: _ArchiveBackground(c: c),
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

/// 左滑归档背景（绿色，右侧），提示归档即已报销。
class _ArchiveBackground extends StatelessWidget {
  final AppColorScheme c;
  const _ArchiveBackground({required this.c});

  @override
  Widget build(BuildContext context) {
    final base = RecordCategory.car.base;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
          Icon(Icons.archive_outlined, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '归档',
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
