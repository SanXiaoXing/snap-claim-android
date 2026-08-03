// 报销单详情页：只读展示表单 / 汇总 / 明细。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../models/claim.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/chips.dart';
import '../widgets/field_widgets.dart';
import '../widgets/record_row.dart';
import '../widgets/summary_card.dart';
import 'claim_share_page.dart';
import 'editor_page.dart';

class DetailPage extends StatelessWidget {
  final Claim claim;
  final ValueChanged<Claim>? onSave;

  const DetailPage({super.key, required this.claim, this.onSave});

  /// 进入编辑页；保存后关闭详情页回到列表，避免展示过期数据。
  Future<void> _edit(BuildContext context) async {
    final save = onSave;
    if (save == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorPage(claim: claim, onSave: save),
      ),
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  /// 进入分享页：渲染分享卡片 → 抓图 → 调起系统分享面板。
  Future<void> _share(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ClaimSharePage(claim: claim)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          AppTopBar(
            leading: AppIconButton(
              icon: Icons.chevron_left,
              onTap: () => Navigator.of(context).pop(),
            ),
            title: '报销详情',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onSave != null)
                  AppIconButton(
                    icon: Icons.edit_outlined,
                    size: 18,
                    onTap: () => _edit(context),
                  ),
                AppIconButton(
                  icon: Icons.ios_share,
                  size: 18,
                  onTap: () => _share(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 表单卡片（只读）。
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: cardDecoration(c),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FieldLabel('报销单名称'),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            claim.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.fg,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FieldLabel('出差日期'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            DatePill(
                                date: claim.startDate, label: '开始'),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              child: Icon(Icons.arrow_forward,
                                  size: 14, color: c.fgSoft),
                            ),
                            DatePill(
                                date: claim.endDate, label: '结束'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SummaryCard(claim: claim),
                  const SizedBox(height: 16),
                  Text(
                    '明细记录（${claim.records.length}）',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.fg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TagSummary(counts: claim.tagCounts),
                  Column(
                    children: [
                      for (final r in claim.records) ...[
                        RecordRow(record: r),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
