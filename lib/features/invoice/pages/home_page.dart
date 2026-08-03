// 首页：问候 + 圆形创建入口 + 最近报销单。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../models/claim.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/claim_card.dart';
import '../widgets/create_cta.dart';
import '../widgets/empty_hint.dart';
import 'detail_page.dart';
import 'editor_page.dart';

class HomePage extends StatelessWidget {
  final List<Claim> claims;
  final ValueChanged<Claim> onSaveClaim;
  final VoidCallback onSeeAll;

  const HomePage({
    super.key,
    required this.claims,
    required this.onSaveClaim,
    required this.onSeeAll,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return '凌晨好';
    if (h < 9) return '早上好';
    if (h < 12) return '上午好';
    if (h < 14) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final recent = claims.take(3).toList();
    return Column(
      children: [
        AppTopBar(title: 'SnapClaim', displayFont: true),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${_greeting()}，又到给钱包回血的时候了！',
                  style: TextStyle(fontSize: 13, color: c.fgMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  '新建报销',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.fg,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: CreateCta(onTap: () => _openEditor(context)),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      '最近单子',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.fg,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onSeeAll,
                      child: Text(
                        '查看全部',
                        style: TextStyle(fontSize: 12, color: c.fgSoft),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (recent.isEmpty)
                  const EmptyHint(
                    icon: Icons.inbox_outlined,
                    text: '还没报销单，点上方按钮开启搞钱模式！',
                    card: true,
                  )
                else
                  Column(
                    children: [
                      for (final claim in recent) ...[
                        ClaimCard(
                          claim: claim,
                          onTap: () => _openDetail(context, claim),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openEditor(BuildContext context) {
    final now = DateTime.now();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorPage(
          claim: Claim(
            id: '${now.microsecondsSinceEpoch}',
            name: '',
            startDate: now,
            endDate: now,
            records: const [],
            savedAt: now,
          ),
          onSave: onSaveClaim,
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, Claim claim) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailPage(claim: claim, onSave: onSaveClaim),
      ),
    );
  }
}
