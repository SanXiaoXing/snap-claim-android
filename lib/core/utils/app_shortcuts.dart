// 桌面入口项组装：长按快捷方式（#8）与快捷操作小组件（#10）共用同一模型。
import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../features/invoice/models/claim.dart';
import 'entry_action.dart';
import 'format.dart';

/// 一条桌面入口（长按菜单行 / 小组件行）。
@immutable
class EntryItem {
  /// 可被 [parseEntryAction] 解析的 action。
  final String action;

  /// 主文案：单据名称或「新建报销单」。
  final String title;

  /// 副文案：退补 `fmtMoneyShort`；长按菜单与新建行为 null。
  final String? amountText;

  /// Android drawable 资源名；仅长按菜单使用。
  final String? icon;

  const EntryItem({
    required this.action,
    required this.title,
    this.amountText,
    this.icon,
  });
}

/// 报销单入口标题：有名用名，空名用编辑页同款日期区间。
String claimShortcutTitle(Claim claim) {
  final name = claim.name.trim();
  if (name.isNotEmpty) return name;
  return '${fmtDateCompact(claim.startDate)}-${fmtDateCompact(claim.endDate)}';
}

/// 长按菜单展示的报销单条数（其后固定追加「新建」）。
const int kMaxClaimShortcuts = 2;

/// 桌面快捷操作卡的报销单条数（1 单 + 新建，共 2 条目）。
const int kQuickWidgetMaxClaims = 1;

/// 最近保存的未归档报销单（savedAt 降序）。
List<Claim> recentUnarchivedClaims(List<Claim> claims, {int limit = kMaxClaimShortcuts}) {
  final unarchived = claims.where((c) => !c.archived).toList()
    ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  return unarchived.take(limit).toList();
}

/// 组装入口列表：最近未归档单 +「新建报销单」。
/// [withIcons] 为 true 时填充长按菜单图标；[withAmounts] 为 true 时填充金额副文案。
List<EntryItem> buildEntryItems(
  List<Claim> claims, {
  int maxClaims = kMaxClaimShortcuts,
  bool withIcons = false,
  bool withAmounts = false,
}) {
  return [
    for (final claim in recentUnarchivedClaims(claims, limit: maxClaims))
      EntryItem(
        action: '$kEditClaimPrefix${claim.id}',
        title: claimShortcutTitle(claim),
        amountText: withAmounts ? fmtMoneyShort(claim.balanceAmount) : null,
        icon: withIcons ? 'ic_shortcut_claim' : null,
      ),
    EntryItem(
      action: kNewClaimAction,
      title: '新建报销单',
      icon: withIcons ? 'ic_shortcut_new' : null,
    ),
  ];
}

/// 长按动态快捷方式：封装 `quick_actions`。
class AppShortcuts {
  AppShortcuts._();

  static const _plugin = QuickActions();
  static bool _bound = false;

  /// 注册点击回调（冷启动/热启动共用）；幂等。
  static Future<void> bind() async {
    if (_bound) return;
    _bound = true;
    try {
      await _plugin.initialize(EntryActionReceiver.emit);
    } catch (e) {
      debugPrint('初始化长按快捷方式失败: $e');
    }
  }

  /// 按当前报销单列表刷新启动器长按菜单。
  static Future<void> refresh(List<Claim> claims) async {
    final items = buildEntryItems(claims, withIcons: true);
    try {
      await _plugin.setShortcutItems([
        for (final s in items)
          ShortcutItem(
            type: s.action,
            localizedTitle: s.title,
            icon: s.icon ?? 'ic_shortcut_new',
          ),
      ]);
    } catch (e) {
      debugPrint('更新长按快捷方式失败: $e');
    }
  }
}
