// 历史记录页：把原「归档页」并入本页，用滑动分段 tab 切换「未报销 / 已报销」。
//
// 结构：
//   AppTopBar('历史记录')    —— 无返回、无右上角操作（归档入口已并入 tab）
//   SlidingSegmentedTabs     —— 「未报销 / 已报销」+ 数量，支持点按与拖拽
//   PageView                 —— 两个按月分组的列表，onPageChanged 反向同步 tab
//
// ⚠️ 手势竞技场约束（本机实测，确定性行为）：
//   手指落在卡片（Dismissible）上横滑时，**Dismissible 必定赢**，外层 PageView
//   完全拿不到手势（左滑、右滑、小幅拖动后回拖都一样）；只有落在非卡片区域
//   （卡片间距 / 月份标题 / 列表外空白）横滑时，PageView 才能翻页。
//   因此这里**不**为了「内容区横滑切 tab」去改动卡片的 Dismissible——那会破坏
//   归档 / 撤销归档的既有手感。滑动切 tab 的体验改由 **tab 栏自身支持拖拽**来
//   保证（见 SlidingSegmentedTabs）。PageView 仍保留，用于在非卡片区域翻页，
//   并通过 onPageChanged 把下标反向同步回 tab 栏。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../app/theme.dart';
import '../models/claim.dart';
import '../models/record.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/claim_card.dart';
import '../widgets/empty_hint.dart';
import '../widgets/sliding_segmented_tabs.dart';
import '../widgets/swipe_background.dart';
import 'detail_page.dart';

class HistoryPage extends StatefulWidget {
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
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final PageController _ctrl = PageController();
  int _index = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 切到指定 tab：更新高亮并把 PageView 同步过去。
  void _selectTab(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    if (!_ctrl.hasClients) return;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      // 减少动态：不做翻页动画，直接跳转。
      _ctrl.jumpToPage(i);
    } else {
      _ctrl.animateToPage(
        i,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 两个列表都从 widget.claims 现算（单一可信数据源，不私存副本）：
    // 未报销 = archived == false，已报销 = archived == true，各自按日期倒序。
    final unarchived = widget.claims.where((e) => !e.archived).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final archived = widget.claims.where((e) => e.archived).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return Column(
      children: [
        const AppTopBar(title: '历史记录'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SlidingSegmentedTabs(
            index: _index,
            labels: const ['未报销', '已报销'],
            counts: [unarchived.length, archived.length],
            onChanged: _selectTab,
          ),
        ),
        Expanded(
          child: PageView(
            controller: _ctrl,
            // 内容区（非卡片处）横滑翻页 → 反向同步 tab 高亮。
            onPageChanged: (i) => setState(() => _index = i),
            children: [
              _buildList(context, unarchived, archived: false),
              _buildList(context, archived, archived: true),
            ],
          ),
        ),
      ],
    );
  }

  /// 单个 tab 的列表：按月分组 + 卡片。
  /// 未报销可左滑归档；已报销可右滑撤销归档 / 左滑删除。
  Widget _buildList(
    BuildContext context,
    List<Claim> claims, {
    required bool archived,
  }) {
    final c = context.colors;
    // 按年月分组，保持倒序（排布方式与合并前的历史页一致）。
    final groups = groupClaimsByMonth(claims);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      child: groups.isEmpty
          ? EmptyHint(
              icon: archived
                  ? Icons.inventory_2_outlined
                  : Icons.archive_outlined,
              text: archived ? '暂无已报销记录' : '暂无未报销记录',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in groups.entries) ...[
                  // 月份分组标题，样式与合并前统一。
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
                    archived
                        ? _buildRestoreDismissible(context, claim)
                        : _buildArchiveDismissible(context, claim),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
    );
  }

  /// 未报销 tab：左滑归档（无需二次确认，保持合并前手感）。
  Widget _buildArchiveDismissible(BuildContext context, Claim claim) {
    final c = context.colors;
    return Dismissible(
      key: ValueKey('archive-${claim.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.35,
      },
      onDismissed: (_) {
        // 滑动归档是明确的「提交」动作：行滑出与触感同帧。
        HapticFeedback.mediumImpact();
        widget.onArchiveClaim(claim);
      },
      background: SwipeBackground(
        icon: Icons.archive_outlined,
        label: '归档',
        from: RecordCategory.car.base,
        to: Color.lerp(RecordCategory.car.base, c.card, 0.35)!,
        alignment: Alignment.centerRight,
      ),
      child: ClaimCard(
        claim: claim,
        onTap: () => _openDetail(context, claim),
      ),
    );
  }

  /// 已报销 tab：右滑撤销归档（无确认）/ 左滑删除（二次确认）；
  /// 结构与文案从原 archive_page.dart 原样搬来。
  Widget _buildRestoreDismissible(BuildContext context, Claim claim) {
    final c = context.colors;
    return Dismissible(
      key: ValueKey('restore-${claim.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.35,
      },
      confirmDismiss: (direction) async {
        // 右滑撤销归档：无需确认；左滑删除：二次确认。
        if (direction == DismissDirection.startToEnd) return true;
        return _confirmDelete(context, claim);
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          // 滑动撤销是明确的「提交」动作：行滑出与触感同帧。
          HapticFeedback.mediumImpact();
          widget.onRestoreClaim(claim);
        } else {
          // 删除已弹确认框，触感轻反馈即可，避免过度打扰。
          HapticFeedback.lightImpact();
          widget.onDeleteClaim(claim);
        }
      },
      background: SwipeBackground(
        icon: Icons.undo,
        label: '撤销归档',
        from: RecordCategory.car.base,
        to: Color.lerp(RecordCategory.car.base, c.card, 0.35)!,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: SwipeBackground(
        icon: Icons.delete_outline,
        label: '删除',
        from: c.danger,
        to: Color.lerp(c.danger, c.dangerBg, 0.3)!,
        alignment: Alignment.centerRight,
      ),
      child: ClaimCard(
        claim: claim,
        onTap: () => _openDetail(context, claim),
      ),
    );
  }

  void _openDetail(BuildContext context, Claim claim) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailPage(claim: claim, onSave: widget.onSaveClaim),
      ),
    );
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
}
