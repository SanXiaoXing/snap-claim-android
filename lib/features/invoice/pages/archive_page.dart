// 归档页面：存放已归档（已报销）的报销单。
// 右滑撤销归档（无需二次确认）；左滑删除数据库数据（需二次确认）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../app/theme.dart';
import '../models/claim.dart';
import '../models/record.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/claim_card.dart';
import '../widgets/empty_hint.dart';
import '../widgets/swipe_background.dart';

class ArchivePage extends StatefulWidget {
  final List<Claim> claims;
  final ValueChanged<Claim> onRestore;
  final ValueChanged<Claim> onDelete;

  const ArchivePage({
    super.key,
    required this.claims,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  late List<Claim> _claims;

  @override
  void initState() {
    super.initState();
    _claims = [...widget.claims];
  }

  /// 撤销归档：本地移除 + 上层回调（无需二次确认）。
  void _restore(Claim claim) {
    // 滑动撤销是明确的「提交」动作：行滑出与触感同帧。
    HapticFeedback.mediumImpact();
    setState(() => _claims.removeWhere((e) => e.id == claim.id));
    widget.onRestore(claim);
  }

  /// 删除：本地移除 + 上层回调（已二次确认）。
  void _delete(Claim claim) {
    // 删除已弹确认框，触感轻反馈即可，避免过度打扰。
    HapticFeedback.lightImpact();
    setState(() => _claims.removeWhere((e) => e.id == claim.id));
    widget.onDelete(claim);
  }

  /// 左滑删除的二次确认。
  Future<bool> _confirmDelete(BuildContext context, Claim claim) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: '删除报销单',
        content: Text(
          '确定删除「${claim.name}」吗？将同时删除其全部明细，此操作不可恢复。',
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
    final sorted = [..._claims]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    // 按年月分组（保持倒序），排布方式与历史记录页一致。
    final groups = groupClaimsByMonth(sorted);

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          AppTopBar(
            leading: AppIconButton(
              icon: Icons.chevron_left,
              onTap: () => Navigator.of(context).pop(),
            ),
            title: '归档',
          ),
          Expanded(
            child: _claims.isEmpty
                ? const EmptyHint(
                    icon: Icons.inventory_2_outlined,
                    text: '暂无归档记录',
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in groups.entries) ...[
                          // 月份分组标题，样式与历史记录页统一。
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
                            Dismissible(
                              key: ValueKey('restore-${claim.id}'),
                              direction: DismissDirection.horizontal,
                              dismissThresholds: const {
                                DismissDirection.startToEnd: 0.3,
                                DismissDirection.endToStart: 0.35,
                              },
                              confirmDismiss: (direction) async {
                                // 右滑撤销归档：无需确认；左滑删除：二次确认。
                                if (direction == DismissDirection.startToEnd) {
                                  return true;
                                }
                                return _confirmDelete(context, claim);
                              },
                              onDismissed: (direction) {
                                if (direction == DismissDirection.startToEnd) {
                                  _restore(claim);
                                } else {
                                  _delete(claim);
                                }
                              },
                              background: SwipeBackground(
                                icon: Icons.undo,
                                label: '撤销归档',
                                from: RecordCategory.car.base,
                                to: Color.lerp(
                                    RecordCategory.car.base, c.card, 0.35)!,
                                alignment: Alignment.centerLeft,
                              ),
                              secondaryBackground: SwipeBackground(
                                icon: Icons.delete_outline,
                                label: '删除',
                                from: c.danger,
                                to: Color.lerp(c.danger, c.dangerBg, 0.3)!,
                                alignment: Alignment.centerRight,
                              ),
                              child: ClaimCard(claim: claim),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
