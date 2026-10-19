// 桌面小组件数据经平台通道交给 Android RemoteViews。
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/invoice/models/claim.dart';
import 'app_shortcuts.dart';
import 'format.dart';
import 'owed_widget.dart';

class HomeWidgets {
  HomeWidgets._();

  static const _channel = MethodChannel('snap_claim/launcher');

  static Future<void> refreshAll(List<Claim> claims) async {
    await Future.wait([refreshOwed(claims), refreshQuickActions(claims)]);
  }

  /// 刷新「公司欠我」金额卡。
  static Future<void> refreshOwed(List<Claim> claims) async {
    final total = owedTotal(claims);
    try {
      await _channel.invokeMethod<void>('updateOwedWidget', {
        'amount': fmtMoney(total),
        'positive': total > 0,
      });
    } catch (e) {
      debugPrint('更新桌面金额小组件失败: $e');
    }
  }

  /// 刷新「快捷操作」卡片行。
  static Future<void> refreshQuickActions(List<Claim> claims) async {
    final items = buildEntryItems(
      claims,
      maxClaims: kQuickWidgetMaxClaims,
      withAmounts: true,
    );
    try {
      await _channel.invokeMethod<void>('updateQuickWidget', {
        'items': [
          for (final item in items)
            {
              'title': item.title,
              'amount': item.amountText ?? '',
              'action': item.action,
            },
        ],
      });
    } catch (e) {
      debugPrint('更新桌面快捷操作小组件失败: $e');
    }
  }
}
