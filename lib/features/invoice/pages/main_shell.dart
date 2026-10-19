// 底部外壳：主菜单胶囊（首页 / 历史 / 我的）+ 右侧独立 AI 小球圆钮。
// 布局对齐 askAI blobOnly 触发器形态：小球与主菜单
// 物理分隔，不并入同一胶囊。背景使用 BackdropFilter 模糊下方内容。
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../settings/pages/mine_page.dart';
import '../models/claim.dart';
import '../widgets/ai_mascot.dart';
import '../widgets/ai_sheet.dart';
import '../widgets/sliding_pill.dart';
import 'history_page.dart';
import 'home_page.dart';

/// 底部导航菜单项：图标 + 选中态图标 + 文案。
typedef _TabItem = ({IconData icon, IconData activeIcon, String label});

class MainShell extends StatefulWidget {
  final List<Claim> claims;
  final ValueChanged<Claim> onSaveClaim;
  final ValueChanged<Claim> onArchiveClaim;
  final ValueChanged<Claim> onRestoreClaim;
  final ValueChanged<Claim> onDeleteClaim;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChangeThemeMode;

  /// 备份导入替换数据库后，重新从数据库加载报销单。
  final Future<void> Function() onDataRestored;

  /// 初始 tab（0 首页 / 1 历史 / 2 我的）；冷启动入口可在外壳挂载前指定。
  final int initialTab;

  const MainShell({
    super.key,
    required this.claims,
    required this.onSaveClaim,
    required this.onArchiveClaim,
    required this.onRestoreClaim,
    required this.onDeleteClaim,
    required this.themeMode,
    required this.onChangeThemeMode,
    required this.onDataRestored,
    this.initialTab = 0,
  });

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab.clamp(0, 2);
  }

  /// 外部（入口 action 分发）切换 tab；越界值忽略。
  void selectTab(int index) {
    if (index < 0 || index > 2) return;
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      // extendBody 让 body 内容延伸到 bottomNavigationBar 下方，
      // 使 BackdropFilter 能模糊后方内容，实现真正的 Liquid Glass。
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildPage(
            0,
            HomePage(
              claims: widget.claims,
              onSaveClaim: widget.onSaveClaim,
              onSeeAll: () => setState(() => _index = 1),
            ),
          ),
          _buildPage(
            1,
            HistoryPage(
              claims: widget.claims,
              onSaveClaim: widget.onSaveClaim,
              onArchiveClaim: widget.onArchiveClaim,
              onRestoreClaim: widget.onRestoreClaim,
              onDeleteClaim: widget.onDeleteClaim,
            ),
          ),
          _buildPage(
            2,
            MinePage(
              claims: widget.claims,
              themeMode: widget.themeMode,
              onChangeThemeMode: widget.onChangeThemeMode,
              onDataRestored: widget.onDataRestored,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _GlassTabBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
        onAiTap: () => _showAiSheet(context),
      ),
    );
  }

  /// 带切换动画的页面：当前页淡入原位，其余页淡出并朝切换方向微移。
  Widget _buildPage(int i, Widget page) {
    final selected = i == _index;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final offset = selected
        ? Offset.zero
        : Offset(_index < i ? 0.06 : -0.06, 0);
    return IgnorePointer(
      ignoring: !selected,
      child: AnimatedOpacity(
        opacity: selected ? 1 : 0,
        // 减少动态：仅保留瞬时切换，不做位移动画。
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: reduceMotion ? Offset.zero : offset,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: page,
        ),
      ),
    );
  }

  /// AI 小球入口：打开「情况说明」生成弹层（配置在「我的 → AI 设置」）。
  void _showAiSheet(BuildContext context) {
    showAiSituationSheet(context);
  }
}

/// 底部悬浮菜单栏：左侧 Liquid Glass 主胶囊 + 右侧独立 AI 小球。
/// - 主胶囊：圆角 32px 全胶囊外壳（高度 64）+ 高光描边 + 柔和投影。
/// - BackdropFilter 模糊下方内容，营造真正悬浮在内容之上的玻璃质感。
/// - 选中态浮动胶囊用 accent 填充，与外壳内壁四周留 2px 缝隙。
/// - AI 小球：与主胶囊留 12px 缝隙的独立圆钮（58px，垂直居中），
///   玻璃壳 + 水滴/叶片形变的 askAI blob。
/// - 选中项图标实心 / 文字反色为白；未选中保持 muted 灰。
class _GlassTabBar extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback? onAiTap;

  const _GlassTabBar({
    required this.index,
    required this.onChanged,
    this.onAiTap,
  });

  static const _items = <_TabItem>[
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: '首页'),
    (
      icon: Icons.archive_outlined,
      activeIcon: Icons.archive_rounded,
      label: '历史',
    ),
    (icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: '我的'),
  ];

  @override
  State<_GlassTabBar> createState() => _GlassTabBarState();
}

class _GlassTabBarState extends State<_GlassTabBar> {
  // 与历史记录分段栏使用相同的位移和甩动判定。
  static const _flingVelocity = 300.0;

  bool _dragging = false;
  double _dragDx = 0;

  void _onTap(int index) {
    if (index == widget.index) return;
    widget.onChanged(index);
  }

  void _onDragStart() {
    setState(() {
      _dragging = true;
      _dragDx = 0;
    });
  }

  void _onDragUpdate(double dx) {
    setState(() => _dragDx += dx);
  }

  void _onDragCancel() {
    setState(() {
      _dragging = false;
      _dragDx = 0;
    });
  }

  void _onDragEnd(DragEndDetails details, double slot) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    var target = widget.index;
    if (_dragDx.abs() > slot / 2) {
      target += _dragDx > 0 ? 1 : -1;
    } else if (velocity.abs() > _flingVelocity) {
      target += velocity > 0 ? 1 : -1;
    }
    target = target.clamp(0, _GlassTabBar._items.length - 1);
    _onDragCancel();
    if (target != widget.index) {
      widget.onChanged(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: SizedBox(
        // 固定高度 = 胶囊 / 圆钮 + 底部留白：与内容对齐，避免贴死手势区。
        height: 64 + 16,
        child: Padding(
          // 左右收进 20：左侧主胶囊可伸缩，右侧固定 AI 圆钮（58）+ 12 缝隙。
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              // 主菜单胶囊（可伸缩），与 AI 小球物理分隔。
              Expanded(
                child: ClipRRect(
                  // 外壳高度 64 → 圆角取半高 32，做成完全胶囊。
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        // 液态玻璃：单一半透明纯色，按明暗自适应表面色 + 不透明度。
                        // - 亮色模式：c.bgSecondary（slate-50，#F8FAFC）+ 0.92 alpha。
                        //   跟页面纯白 c.bg（#FFFFFF）形成清晰的高度差，不再融成一片。
                        // - 暗色模式：自定的暖灰（#2A2722）+ 0.78 alpha，跟 c.bg（#141210）拉开对比。
                        // 两个模式都配 1px 描边 + 投影，让"悬浮"边界更明确。
                        color: isDark
                            ? const Color(0xFF2A2722).withValues(alpha: 0.78)
                            : const Color(0xFFF8FAFC).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(32),
                        // 1px 描边：亮色用深灰低透明（避免白边看不见），
                        // 暗色用白色低透明（玻璃边缘高光）。
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : const Color(0xFFCBD5E1).withValues(alpha: 0.6),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.55 : 0.22,
                            ),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      // 用 LayoutBuilder 取得容器宽度，让 Stack 内的
                      // SlidingPill 能直接拿到每格 / 胶囊宽度。
                      // LayoutBuilder 必须在 Stack 外层，否则 Positioned
                      // 会失去 StackParentData 报错。
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // 每格宽度 = 容器内宽 / itemCount。
                          final slot =
                              constraints.maxWidth / _GlassTabBar._items.length;
                          // 胶囊左右各内缩 2px，与上下留白一致。
                          final pillWidth = slot - 4;
                          final reduceMotion =
                              MediaQuery.maybeOf(context)?.disableAnimations ??
                              false;
                          final restLeft = widget.index * slot + 2;
                          final pillLeft = _dragging && !reduceMotion
                              ? (restLeft + _dragDx)
                                    .clamp(2.0, constraints.maxWidth - slot + 2)
                                    .toDouble()
                              : restLeft;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart: (_) => _onDragStart(),
                            onHorizontalDragUpdate: (d) =>
                                _onDragUpdate(d.delta.dx),
                            onHorizontalDragEnd: (d) => _onDragEnd(d, slot),
                            onHorizontalDragCancel: _onDragCancel,
                            child: Stack(
                              children: [
                                // 选中态浮动胶囊：在内容之上覆盖，跟随选中项平滑滑动。
                                SlidingPill(
                                  left: pillLeft,
                                  width: pillWidth,
                                  top: 2,
                                  bottom: 2,
                                  // 拖动时直接跟手，松手后复用历史记录的弹簧。
                                  animate: !_dragging && !reduceMotion,
                                ),
                                // 三个菜单项（图标 + 文字上下排列）。
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < _GlassTabBar._items.length;
                                      i++
                                    )
                                      _GlassTab(
                                        icon: _GlassTabBar._items[i].icon,
                                        activeIcon:
                                            _GlassTabBar._items[i].activeIcon,
                                        label: _GlassTabBar._items[i].label,
                                        position: i,
                                        selectedIndex: widget.index,
                                        onTap: () => _onTap(i),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // 与主胶囊明确分隔（对齐参考图中「圆钮独立在外」）。
              const SizedBox(width: 12),
              AiBallButton(onTap: widget.onAiTap),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单个菜单项：图标 + 文字上下排列。选中态切换实心图标 + 文字反色为白。
class _GlassTab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int position;
  final int selectedIndex;
  final VoidCallback onTap;

  const _GlassTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.position,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = position == selectedIndex;
    // 选中态文字 / 图标反色为白，未选中保持 muted 灰。
    final fgColor = selected ? Colors.white : c.fgMuted;
    final iconData = selected ? activeIcon : icon;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标：选中用实心，未选中用描边；颜色由 fgColor 驱动。
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: Icon(
                  iconData,
                  key: ValueKey(selected),
                  size: 22,
                  color: fgColor,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                  letterSpacing: 0.1,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
