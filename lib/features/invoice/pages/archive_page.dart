// 归档页面：存放已归档（已报销）的报销单。
// 右滑撤销归档（无需二次确认）；左滑删除数据库数据（需二次确认）。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../models/claim.dart';
import '../models/record.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/claim_card.dart';
import '../widgets/empty_hint.dart';

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
    setState(() => _claims.removeWhere((e) => e.id == claim.id));
    widget.onRestore(claim);
  }

  /// 删除：本地移除 + 上层回调（已二次确认）。
  void _delete(Claim claim) {
    setState(() => _claims.removeWhere((e) => e.id == claim.id));
    widget.onDelete(claim);
  }

  /// 左滑删除的二次确认。
  Future<bool> _confirmDelete(BuildContext context, Claim claim) async {
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '删除报销单',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.fg,
          ),
        ),
        content: Text(
          '确定删除「${claim.name}」吗？将同时删除其全部明细，此操作不可恢复。',
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
    final sorted = [..._claims]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
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
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final claim = sorted[i];
                      return Dismissible(
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
                        background: _RestoreBackground(c: c),
                        secondaryBackground: _DeleteBackground(c: c),
                        child: ClaimCard(claim: claim),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 右滑撤销归档背景（绿色，左侧）。
class _RestoreBackground extends StatelessWidget {
  final AppColorScheme c;
  const _RestoreBackground({required this.c});

  @override
  Widget build(BuildContext context) {
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
          Icon(Icons.undo, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '撤销归档',
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

/// 左滑删除背景（红色，右侧）。
class _DeleteBackground extends StatelessWidget {
  final AppColorScheme c;
  const _DeleteBackground({required this.c});

  @override
  Widget build(BuildContext context) {
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
}
