// 桌面入口统一 action：解析字符串协议 + 待处理/事件接收器。
import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// 底部导航 tab 序号，与 [MainShell] 中 0首页 / 1历史 / 2我的 对应。
const int kTabIndexHome = 0;
const int kTabIndexMine = 2;

const String kOpenMineAction = 'open_mine';
const String kNewClaimAction = 'new_claim';
const String kEditClaimPrefix = 'edit_claim:';

/// 入口动作种类；`editClaim` 时用 [EntryAction.claimId]。
enum EntryActionKind { openMine, newClaim, editClaim }

/// 解析后的入口动作。
class EntryAction {
  final EntryActionKind kind;

  /// 仅 [EntryActionKind.editClaim] 有值。
  final String? claimId;

  const EntryAction(this.kind, {this.claimId});
}

/// 解析入口 action 字符串；非法 / 无法识别返回 null。
EntryAction? parseEntryAction(String raw) {
  final action = raw.trim();
  if (action == kOpenMineAction) {
    return const EntryAction(EntryActionKind.openMine);
  }
  if (action == kNewClaimAction) {
    return const EntryAction(EntryActionKind.newClaim);
  }
  if (action.startsWith(kEditClaimPrefix)) {
    final id = action.substring(kEditClaimPrefix.length);
    if (id.isNotEmpty) return EntryAction(EntryActionKind.editClaim, claimId: id);
  }
  return null;
}

/// 入口 action 接收器：冷启动 pending + 热启动事件流。
class EntryActionReceiver {
  EntryActionReceiver._();

  static final Queue<EntryAction> _pending = Queue<EntryAction>();
  static final StreamController<EntryAction> _actions =
      StreamController<EntryAction>.broadcast();

  static Stream<EntryAction> get onAction => _actions.stream;

  static void emit(String raw) {
    final parsed = parseEntryAction(raw);
    if (parsed == null) {
      debugPrint('忽略非法入口 action: ${raw.trim()}');
      return;
    }
    if (_actions.hasListener) {
      _actions.add(parsed);
    } else {
      _pending.add(parsed);
    }
  }

  static List<EntryAction> takePending() {
    final list = _pending.toList();
    _pending.clear();
    return list;
  }
}
