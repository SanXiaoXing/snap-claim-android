// 首次使用引导：基于 tutorial_coach_mark 的分页引导。
// 首页（创建报销单）→ 编辑页（扫码/图片识别/手动添加/左滑删除）→ 详情页（修改）。
// 每个页面首次访问时展示一次对应功能点的引导气泡，用 SharedPreferences 记录已展示；
// 读取失败（如测试环境无插件）一律视为已展示，避免在测试中弹出引导层。
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../app/theme.dart';

/// 引导模块。
class AppTutorial {
  AppTutorial._();

  static const _homeShownKey = 'tutorial_home_shown_v2';
  static const _editorShownKey = 'tutorial_editor_shown_v2';
  static const _detailShownKey = 'tutorial_detail_shown_v2';

  static Future<bool> _isShown(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (_) {
      // 读取失败视为已展示（如测试环境），避免反复弹出或打断测试。
      return true;
    }
  }

  static Future<void> _markShown(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (_) {}
  }

  /// 等待页面入场转场结束后再弹引导：
  /// tutorial_coach_mark 在展示时用 localToGlobal 计算目标位置并缓存，
  /// 若在转场动画中间弹出，会把转场位移算进坐标，导致高亮偏移（如
  /// 详情页「修改」高亮错指到「分享」按钮）。等转场完成后位置才稳定。
  /// 用动画值轮询（带超时）而非 route.completed，兼容测试环境。
  static Future<void> _showAfterRouteSettle(
    BuildContext context,
    String shownKey,
    List<TargetFocus> targets,
  ) async {
    final anim = ModalRoute.of(context)?.animation;
    if (anim != null) {
      // 最多等待 1.5s 转场结束（转场位移归零），避免异常情况下无限等待。
      for (var i = 0; i < 100 && anim.value < 1.0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
    }
    if (!context.mounted) return;
    _run(context, targets, shownKey);
  }

  /// 首页引导：创建报销单入口。
  static Future<void> maybeShowHome(
    BuildContext context,
    GlobalKey createKey,
  ) async {
    if (await _isShown(_homeShownKey)) return;
    if (!context.mounted) return;
    final c = context.colors;
    await _showAfterRouteSettle(
      context,
      _homeShownKey,
      [
        _target(
          key: createKey,
          shape: ShapeLightFocus.Circle,
          align: ContentAlign.bottom,
          icon: Icons.add_circle_outline,
          color: c.accent,
          title: '创建报销单',
          desc: '点击圆形按钮新建一张报销单，扫码、拍照识别和手动录入都能往里填。',
        ),
      ],
    );
  }

  /// 编辑页引导：右下角 + 号（扫码/图片识别/手动添加）、左滑删除与右上角保存。
  static Future<void> maybeShowEditor(
    BuildContext context,
    GlobalKey fabKey,
    GlobalKey swipeHintKey,
    GlobalKey saveKey,
  ) async {
    if (await _isShown(_editorShownKey)) return;
    if (!context.mounted) return;
    final c = context.colors;
    await _showAfterRouteSettle(
      context,
      _editorShownKey,
      [
        _target(
          key: fabKey,
          shape: ShapeLightFocus.Circle,
          align: ContentAlign.top,
          icon: Icons.add,
          color: c.accent,
          title: '添加明细',
          desc: '点右下角 + 展开菜单：扫码添加二维码、拍照/选图 OCR 识别、手动录入金额。',
        ),
        _target(
          key: swipeHintKey,
          shape: ShapeLightFocus.RRect,
          align: ContentAlign.bottom,
          icon: Icons.swipe_left_outlined,
          color: c.danger,
          title: '删除明细',
          desc: '在明细行上左滑可删除；用车记录右滑还能切换市内交通 / 往返交通。',
        ),
        _target(
          key: saveKey,
          shape: ShapeLightFocus.RRect,
          align: ContentAlign.bottom,
          icon: Icons.check,
          color: c.accent,
          title: '保存报销单',
          desc: '填完名称、日期与明细后，点右上角「保存」提交，报销单会出现在首页列表。',
        ),
      ],
    );
  }

  /// 详情页引导：修改报销单。
  static Future<void> maybeShowDetail(
    BuildContext context,
    GlobalKey editKey,
  ) async {
    if (await _isShown(_detailShownKey)) return;
    if (!context.mounted) return;
    final c = context.colors;
    await _showAfterRouteSettle(
      context,
      _detailShownKey,
      [
        _target(
          key: editKey,
          shape: ShapeLightFocus.RRect,
          align: ContentAlign.bottom,
          icon: Icons.edit_outlined,
          color: c.accent,
          title: '修改报销单',
          desc: '点这里进入编辑页，修改名称、日期与明细，改完保存即可。',
        ),
      ],
    );
  }

  static void _run(
    BuildContext context,
    List<TargetFocus> targets,
    String shownKey,
  ) {
    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.6,
      textSkip: '跳过',
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      alignSkip: Alignment.topLeft,
      showSkipInLastTarget: true,
      useSafeArea: true,
      // 引导真正结束 / 被跳过时才标记「已展示」：
      // 若提前标记而引导因故未弹出，将永远不再显示（此前首页引导即因此消失）。
      onFinish: () => _markShown(shownKey),
      onSkip: () {
        _markShown(shownKey);
        return true;
      },
    ).show(context: context);
  }

  static TargetFocus _target({
    required GlobalKey key,
    required ShapeLightFocus shape,
    required ContentAlign align,
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return TargetFocus(
      identify: title,
      keyTarget: key,
      shape: shape,
      radius: 10,
      contents: [
        TargetContent(
          align: align,
          child: _TutorialCard(
            icon: icon,
            color: color,
            title: title,
            desc: desc,
          ),
        ),
      ],
    );
  }
}

/// 引导气泡卡片：品牌色图标 + 标题 + 说明，跟随当前主题配色。
class _TutorialCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;

  const _TutorialCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(fontSize: 12.5, color: c.fgMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
