// 版本信息页：产品信息、开发者彩蛋、技术栈与 GitHub 反馈入口。
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/backup/backup.dart';
import '../../invoice/widgets/app_top_bar.dart';

/// GitHub 问题反馈链接（新建 issue）。
const String kFeedbackUrl =
    'https://github.com/SanXiaoXing/snap-claim-android/issues/new';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _openFeedback(BuildContext context) async {
    final uri = Uri.parse(kFeedbackUrl);

    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!ok && context.mounted) {
        showAppSnack(context, '无法打开链接，请手动访问：$kFeedbackUrl');
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnack(context, '无法打开链接，请手动访问：$kFeedbackUrl');
      }
    }
  }

  Widget _sectionTitle(
      BuildContext context,
      String title,
      IconData icon,
      ) {
    final c = context.colors;

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: c.accent,
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.fg,
          ),
        ),
      ],
    );
  }

  Widget _card(
      BuildContext context,
      Widget child,
      ) {
    final c = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(c),
      child: child,
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
            title: '关于 SnapClaim',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ----------------------------------------------------------
                  // App 标识
                  // ----------------------------------------------------------
                  _card(
                    context,
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/icon/logo.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'SnapClaim',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: c.fg,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '把发票交给我，剩下的交给时间。',
                          style: TextStyle(
                            fontSize: 13,
                            color: c.fgMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: c.accentBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'v$kAppVersion',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: c.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ----------------------------------------------------------
                  // 产品宣言
                  // ----------------------------------------------------------
                  _card(
                    context,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          context,
                          '关于这个 App',
                          Icons.auto_awesome_outlined,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '报销这件事已经够严肃了。',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.fg,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '所以 SnapClaim 决定轻松一点。',
                          style: TextStyle(
                            fontSize: 14,
                            color: c.fgMuted,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '它负责把那些散落在相册、邮箱和聊天记录里的发票，'
                              '一点一点捡回来，整理好，最后交给报销系统。',
                          style: TextStyle(
                            fontSize: 14,
                            color: c.fgMuted,
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ----------------------------------------------------------
                  // 开发者彩蛋
                  // ----------------------------------------------------------
                  _card(
                    context,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          context,
                          '幕后真相',
                          Icons.theater_comedy_outlined,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '这个 App 是 AI 写的。',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.fg,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '人类负责提需求、改需求、再改需求，'
                              '以及在 AI 说“应该没问题”的时候亲自验证。',
                          style: TextStyle(
                            fontSize: 14,
                            color: c.fgMuted,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.accentBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '🤖 AI：我觉得可以。\n'
                                '👨‍💻 人类：那我试一下。\n'
                                '💥 App：我觉得不可以。',
                            style: TextStyle(
                              fontSize: 13,
                              color: c.fg,
                              height: 1.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ----------------------------------------------------------
                  // 产品理念
                  // ----------------------------------------------------------
                  _card(
                    context,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          context,
                          '我们相信',
                          Icons.favorite_border,
                        ),
                        const SizedBox(height: 12),
                        _belief(
                          context,
                          '01',
                          '发票应该被拍下来，而不是被遗忘。',
                        ),
                        const SizedBox(height: 10),
                        _belief(
                          context,
                          '02',
                          '报销应该花几分钟，而不是一个下午。',
                        ),
                        const SizedBox(height: 10),
                        _belief(
                          context,
                          '03',
                          '软件可以认真工作，但没必要一直板着脸。',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ----------------------------------------------------------
                  // 技术栈
                  // ----------------------------------------------------------
                  _card(
                    context,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          context,
                          '幕后工作人员',
                          Icons.build_outlined,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _techItem(
                                context,
                                'Flutter',
                                '负责长相',
                                Icons.phone_android_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _techItem(
                                context,
                                'Rust',
                                '负责干活',
                                Icons.memory_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '还有一些没出现在这里的依赖，它们正在安静地工作。',
                          style: TextStyle(
                            fontSize: 11,
                            color: c.fgSoft,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ----------------------------------------------------------
                  // GitHub
                  // ----------------------------------------------------------
                  Material(
                    color: c.card,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => _openFeedback(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: cardDecoration(c),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: c.accentBg,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.code_outlined,
                                size: 19,
                                color: c.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'GitHub',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: c.fg,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '发现 Bug？有想法？欢迎来投喂 Issue。',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.fgMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: c.fgSoft,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ----------------------------------------------------------
                  // Footer
                  // ----------------------------------------------------------
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'SnapClaim',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.fgMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Copyright © 2026 SanXiaoXing. All rights reserved.',
                          style: TextStyle(
                            fontSize: 10,
                            color: c.fgSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _belief(
      BuildContext context,
      String number,
      String text,
      ) {
    final c = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: c.fgMuted,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _techItem(
      BuildContext context,
      String name,
      String description,
      IconData icon,
      ) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: c.accent,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 10,
                    color: c.fgSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}