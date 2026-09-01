// 底部三栏外壳：首页 / 历史 / 我的。底部导航为悬浮 Liquid Glass 壳 +
// 选中态 accent 胶囊滑动的胶状菜单栏。背景使用 BackdropFilter 模糊下方内容。
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

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
  final ValueChanged<ThemeMode> onChangeThemeMode;

  /// 备份导入替换数据库后，重新从数据库加载报销单。
  final Future<void> Function() onDataRestored;

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
              onChangeThemeMode: widget.onChangeThemeMode,
              onDataRestored: widget.onDataRestored,
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
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final offset = selected
        ? Offset.zero
        : Offset(_index < i ? 0.06 : -0.06, 0);
    return IgnorePointer(
      ignoring: !selected,
      child: AnimatedOpacity(
        opacity: selected ? 1 : 0,
        // 减少动态：仅保留瞬时切换，不做位移动画。
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: reduceMotion ? Offset.zero : offset,
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: page,
        ),
      ),
    );
  }
}

/// 底部悬浮菜单栏：Liquid Glass 壳 + 选中态浮动胶囊在三项之间平滑滑动。
/// - 圆角 32px 全胶囊外壳（高度 64 的半高）+ 高光描边 + 柔和投影。
/// - BackdropFilter 模糊下方内容，营造真正悬浮在内容之上的玻璃质感。
/// - 选中态浮动胶囊用 accent 填充，与外壳内壁仅留 2px（左右）/ 4px（上下）缝隙，
///   圆角同为半高 28，与外壳构成同心圆角。
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
              // 外壳高度 64 → 圆角取半高 32，做成完全胶囊（原来的 28 留了直边）。
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
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
                      // 每格宽度 = 容器宽 / itemCount（已扣 horizontal padding 8）。
                      final slot = constraints.maxWidth / _items.length;
                      // 胶囊与外壳内壁只留 2px 缝隙（原 4px），选中态更饱满贴边。
                      final pillWidth = slot - 4;
                      return Stack(
                        children: [
                          // 选中态浮动胶囊：在内容之上覆盖，跟随选中项平滑滑动。
                          _SelectedPill(
                            // LayoutBuilder 坐标系已从容器内边距之后开始，
                            // 不能再加 padding 4，否则胶囊会整体右偏、盖不准。
                            left: index * slot + 2,
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
///
/// 位置/宽度用临界阻尼弹簧驱动（Apple 移动/重定位默认：damping 1.0、
/// response ≈ 0.4s）：每次切换从当前屏幕值（而非目标值）出发，
/// 途中可被下一次切换随时打断并重定向，不会跳变。
class _SelectedPill extends StatefulWidget {
  final double left;
  final double width;

  const _SelectedPill({required this.left, required this.width});

  @override
  State<_SelectedPill> createState() => _SelectedPillState();
}

class _SelectedPillState extends State<_SelectedPill>
    with SingleTickerProviderStateMixin {
  // 临界阻尼弹簧：stiffness 246 → response ≈ 2π/√246 ≈ 0.40s，无过冲。
  // 临界阻尼 damping = 2√(stiffness·mass) ≈ 31.4。
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 246,
    damping: 31.4,
  );

  late final AnimationController _ctrl;
  double _left = 0;
  double _width = 0;
  // 本次弹簧的起点（屏幕当前值）与目标值。
  double _fromLeft = 0, _toLeft = 0;
  double _fromWidth = 0, _toWidth = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _left = widget.left;
    _width = widget.width;
    _ctrl = AnimationController.unbounded(vsync: this)
      ..addListener(_onSpringTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 减少动态需在依赖就绪后读取（initState 内不允许查 MediaQuery）。
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void didUpdateWidget(_SelectedPill old) {
    super.didUpdateWidget(old);
    if (old.left == widget.left && old.width == widget.width) return;
    if (_reduceMotion) {
      // 减少动态：不做位移动画，直接落到目标位置。
      _ctrl.stop();
      _left = widget.left;
      _width = widget.width;
      return;
    }
    // 从当前屏幕值（presentation value）出发向新目标弹簧运动。
    // animateWith 会先停掉旧模拟再启动新模拟，快速连续切换也能
    // 安全打断重定向，不会触发「Ticker 已激活」断言。
    _fromLeft = _left;
    _fromWidth = _width;
    _toLeft = widget.left;
    _toWidth = widget.width;
    _ctrl.animateWith(SpringSimulation(_spring, 0, 1, 0));
  }

  void _onSpringTick() {
    setState(() {
      if (!_ctrl.isAnimating) {
        // 弹簧收敛后精确落到目标，避免浮点残留。
        _left = _toLeft;
        _width = _toWidth;
        return;
      }
      final t = _ctrl.value; // 0→1 弹簧进度（临界阻尼单调无过冲）。
      _left = _fromLeft + (_toLeft - _fromLeft) * t;
      _width = _fromWidth + (_toWidth - _fromWidth) * t;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Positioned(
      left: _left,
      // 上下内缩 4（原 8）、左右内缩 2（原 4），选中胶囊更贴外壳；
      // 胶囊高度 56 → 圆角取半高 28，与外壳（32）构成同心圆角。
      top: 4,
      bottom: 4,
      width: _width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // 单色 accent，去掉之前的三段渐变（白高光 → accentLight → accent）。
          color: c.accent,
          borderRadius: BorderRadius.circular(28),
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
