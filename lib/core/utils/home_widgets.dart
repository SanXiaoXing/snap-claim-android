// 桌面小组件基座：数据写入 home_widget + 点击 URI 注入统一入口。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../features/invoice/models/claim.dart';
import 'app_shortcuts.dart';
import 'entry_action.dart';
import 'format.dart';
import 'owed_widget.dart';

class HomeWidgets {
  HomeWidgets._();

  static const owedProviderName = 'OwedWidgetProvider';
  static const quickProviderName = 'QuickActionsWidgetProvider';

  /// 快捷操作卡最多 2 行（1 单 + 新建）；键名与 Kotlin Provider 一致。
  static const kQuickMaxRows = 2;

  static StreamSubscription<Uri?>? _clickSub;
  static bool _coldLaunchChecked = false;

  static void bindEntryActions() {
    _clickSub ??= HomeWidget.widgetClicked.listen(_handleUri);
    if (_coldLaunchChecked) return;
    _coldLaunchChecked = true;
    unawaited(() async {
      try {
        final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
        _handleUri(uri);
      } catch (e) {
        debugPrint('读取小组件冷启动 URI 失败: $e');
      }
    }());
  }

  static void _handleUri(Uri? uri) {
    final action = parseHomeWidgetEntryUri(uri);
    if (action == null) return;
    EntryActionReceiver.emit(action);
  }

  static Future<void> refreshAll(List<Claim> claims) async {
    await Future.wait([
      refreshOwed(claims),
      refreshQuickActions(claims),
    ]);
  }

  /// 刷新「公司欠我」金额卡。
  static Future<void> refreshOwed(List<Claim> claims) async {
    final total = owedTotal(claims);
    try {
      await HomeWidget.saveWidgetData<String>('owed_amount_text', fmtMoney(total));
      await HomeWidget.saveWidgetData<bool>('owed_is_positive', total > 0);
      await HomeWidget.updateWidget(name: owedProviderName);
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
      for (var i = 0; i < kQuickMaxRows; i++) {
        if (i < items.length) {
          final item = items[i];
          await HomeWidget.saveWidgetData<String>('quick_${i}_title', item.title);
          await HomeWidget.saveWidgetData<String>(
            'quick_${i}_amount',
            item.amountText ?? '',
          );
          await HomeWidget.saveWidgetData<String>('quick_${i}_action', item.action);
          await HomeWidget.saveWidgetData<bool>('quick_${i}_visible', true);
        } else {
          await HomeWidget.saveWidgetData<bool>('quick_${i}_visible', false);
        }
      }
      await HomeWidget.updateWidget(name: quickProviderName);
    } catch (e) {
      debugPrint('更新桌面快捷操作小组件失败: $e');
    }
  }
}
