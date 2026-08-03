// 底部三栏外壳：首页 / 历史 / 我的。底部导航为悬浮 Liquid Glass 壳 +
// 选中态 accent 胶囊滑动的胶状菜单栏。背景使用 BackdropFilter 模糊下方内容。
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../settings/pages/mine_page.dart';
import '../models/claim.dart';
import 'history_page.dart';
import 'home_page.dart';

/// 底部导航菜单项数据。
class MenuItemSpec {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const MenuItemSpec({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class MainShell extends StatefulWidget {
  final List<Claim> claims;
  final ValueChanged<Claim> onSaveClaim;
  final ValueChanged<Claim> onArchiveClaim;
  final ValueChanged<Claim> onRestoreClaim;
  final ValueChanged<Claim> onDeleteClaim;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const MainShell({
    super.key,
    required this.claims,
    required this.onSaveClaim,
    required this.onArchiveClaim,
    required this.onRestoreClaim,
    required this.onDeleteClaim,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

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
              onToggleTheme: widget.onToggleTheme,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _GlassTabBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }

  /// 带切换动画的页面：当前页淡入原位，其余页淡出并朝切换方向微移。
  Widget _buildPage(int i, Widget page) {
    final selected = i == _index;
    final offset = selected
        ? Offset.zero
        : Offset(_index < i ? 0.06 : -0.06, 0);
    return IgnorePointer(
      ignoring: !selected,
      child: AnimatedOpacity(
        opacity: selected ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: offset,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: page,
        ),
      ),
    );
  }
}

/// 底部悬浮菜单栏：Liquid Glass 壳 + 选中态浮动胶囊在三项之间平滑滑动。
/// - 圆角 28px 胶囊容器，三段渐变 + 高光描边 + 柔和投影。
/// - BackdropFilter 模糊下方内容，营造真正悬浮在内容之上的玻璃质感。
/// - 选中态浮动胶囊用 accent 渐变填充，跨选中项宽度居中，左右平滑滑动。
/// - 选中项图标实心 / 文字反色为白；未选中保持 muted 灰。
class _GlassTabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _GlassTabBar({required this.index, required this.onChanged});

  static const _items = [
    MenuItemSpec(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: '首页',
    ),
    MenuItemSpec(
      icon: Icons.archive_outlined,
      activeIcon: Icons.archive_rounded,
      label: '历史',
    ),
    MenuItemSpec(
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: SizedBox(
        // 固定高度 = 胶囊 + 底部留白：Center 在有限高度内不会垂直撑满（贴底），
        // 同时宽度保持有界，内部 Row + Expanded 布局正常。
        height: 64 + 16,
        child: Center(
          child: Padding(
            // 左右留白加大，整体宽度比屏幕收窄 80，胶囊更紧凑。
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    // 液态玻璃：单一半透明纯色，按明暗自适应表面色 + 不透明度。
                    // - 亮色模式：c.bgSecondary（slate-50，#F8FAFC）+ 0.92 alpha。
                    //   跟页面纯白 c.bg（#FFFFFF）形成清晰的高度差，不再融成一片。
                    // - 暗色模式：自定的暖灰（#2A2722）+ 0.78 alpha，跟 c.bg（#141210）拉开对比。
                    // 两个模式都配 1px 描边 + 投影，让"悬浮"边界更明确。
                    color: isDark
                        ? const Color(0xFF2A2722).withValues(alpha: 0.78)
                        : const Color(0xFFF8FAFC).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(28),
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
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.55 : 0.22),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  // 用 LayoutBuilder 取得容器宽度，让 Stack 内的
                  // AnimatedPositioned 能直接拿到每格 / 胶囊宽度。
                  // LayoutBuilder 必须在 Stack 外层，否则 Positioned
                  // 会失去 StackParentData 报错。
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 每格宽度 = 容器宽 / itemCount（已扣 horizontal padding 12）。
                      final slot = constraints.maxWidth / _items.length;
                      // 胶囊比单格稍宽 8，左右各溢出 4，形成选中"膨胀"感。
                      final pillWidth = slot - 8;
                      return Stack(
                        children: [
                          // 选中态浮动胶囊：在内容之上覆盖，跟随选中项平滑滑动。
                          _SelectedPill(
                            // LayoutBuilder 坐标系已从容器内边距之后开始，
                            // 不能再加 padding 6，否则胶囊会整体右偏、盖不准。
                            left: index * slot + 4,
                            width: pillWidth,
                          ),
                          // 三个菜单项（图标 + 文字上下排列）。
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (var i = 0; i < _items.length; i++)
                                _GlassTab(
                                  spec: _items[i],
                                  position: i,
                                  selectedIndex: index,
                                  onTap: () => onChanged(i),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 选中态浮动胶囊：accent 纯色填充 + 软阴影。
/// 必须作为 Stack 的直接子节点使用（依赖 StackParentData），
/// left/width 由父级 LayoutBuilder 算好后传入。
class _SelectedPill extends StatelessWidget {
  final double left;
  final double width;

  const _SelectedPill({
    required this.left,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      left: left,
      top: 8,
      bottom: 8,
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // 单色 accent，去掉之前的三段渐变（白高光 → accentLight → accent）。
          color: c.accent,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个菜单项：图标 + 文字上下排列。选中态切换实心图标 + 文字反色为白。
class _GlassTab extends StatelessWidget {
  final MenuItemSpec spec;
  final int position;
  final int selectedIndex;
  final VoidCallback onTap;

  const _GlassTab({
    required this.spec,
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
                  selected ? spec.activeIcon : spec.icon,
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
                child: Text(spec.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
