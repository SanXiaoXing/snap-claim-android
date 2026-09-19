// 桌面入口项组装：长按快捷方式（#8）与快捷操作小组件（#10）共用同一模型。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../features/invoice/models/claim.dart';
import 'entry_action.dart';
import 'format.dart';

/// 「打开报销单」图标：mipmap adaptive（中性深底 + 单据字形）。
const String kShortcutIconClaim = 'ic_shortcut_claim';

/// 「新建报销单」图标：mipmap adaptive（品牌绿底 + 加号字形）。
/// 与报销单图标用不同底色，长按菜单里一眼能区分「打开」与「新建」。
const String kShortcutIconNew = 'ic_shortcut_new';

/// 部分 OEM 解析自定义图标失败时的兜底。
const String kShortcutIconFallback = 'ic_launcher';

/// 一条桌面入口（长按菜单行 / 小组件行）。
@immutable
class EntryItem {
  /// 可被 [parseEntryAction] 解析的 action。
  final String action;

  /// 主文案：单据名称或「新建报销单」。
  final String title;

  /// 副文案：退补 `fmtMoneyShort`；长按菜单与新建行为 null。
  final String? amountText;

  /// Android mipmap 资源名；仅长按菜单使用。
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
/// 「新建」恒为最后一条——长按菜单要求它落在最下面（静态快捷方式会被系统前插，
/// 所以不能走 Manifest）。
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
        icon: withIcons ? kShortcutIconClaim : null,
      ),
    EntryItem(
      action: kNewClaimAction,
      title: '新建报销单',
      icon: withIcons ? kShortcutIconNew : null,
    ),
  ];
}

/// 长按动态快捷方式：封装 `quick_actions`。
class AppShortcuts {
  AppShortcuts._();

  static const _plugin = QuickActions();
  static bool _bound = false;

  static Timer? _refreshDebounce;
  static List<Claim> _pendingClaims = const [];

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
  /// 菜单 = 最近报销单（最多 [kMaxClaimShortcuts] 条）+ 末尾「新建报销单」。
  static Future<void> refresh(List<Claim> claims) {
    _pendingClaims = List.of(claims);
    _refreshDebounce?.cancel();
    final completer = Completer<void>();
    _refreshDebounce = Timer(const Duration(milliseconds: 400), () {
      _refreshNow(_pendingClaims).whenComplete(() {
        if (!completer.isCompleted) completer.complete();
      });
    });
    return completer.future;
  }

  static Future<void> _refreshNow(List<Claim> claims) async {
    // 整组都走动态（含末尾「新建」）：静态快捷方式在系统侧恒定排在动态项之前，
    // 一旦把「新建」写进 Manifest，它就跑到菜单顶部，无法满足“放最下面”。
    // 失败时降级：换兜底图标 → 更少报销单 → 仅剩「新建」，避免出现空菜单。
    final full = buildEntryItems(claims, withIcons: true);
    final oneClaim = buildEntryItems(claims, maxClaims: 1, withIcons: true);
    final onlyNew = buildEntryItems(const [], withIcons: true);
    List<EntryItem> withIcon(List<EntryItem> items, String icon) => [
          for (final s in items) EntryItem(action: s.action, title: s.title, icon: icon),
        ];

    final candidates = <List<EntryItem>>[
      full,
      withIcon(full, kShortcutIconFallback),
      oneClaim,
      withIcon(oneClaim, kShortcutIconFallback),
      onlyNew, // 兜底：至少保留「新建报销单」
    ];
    for (var i = 0; i < candidates.length; i++) {
      final items = candidates[i];
      try {
        await _plugin.setShortcutItems([
          for (final s in items)
            ShortcutItem(
              type: s.action,
              localizedTitle: s.title,
              icon: s.icon ?? kShortcutIconClaim,
            ),
        ]);
        return;
      } catch (e) {
        debugPrint('更新长按快捷方式失败（尝试 ${i + 1}/${candidates.length}）: $e');
      }
    }
  }
}
