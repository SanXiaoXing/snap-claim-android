// MainShell 入口 tab 控制（issue #7）：initialTab + selectTab 切到「我的」。
// 三个页面常驻 Stack（仅 opacity/IgnorePointer），用底部 SlidingPill 的 left
// 断言当前 tab。首页 CTA 有循环呼吸动画，不能 pumpAndSettle。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/features/invoice/models/claim.dart';
import 'package:snap_claim_android/features/invoice/pages/main_shell.dart';
import 'package:snap_claim_android/features/invoice/widgets/sliding_pill.dart';

Claim _claim() => Claim(
      id: 'c1',
      name: '测试报销单',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 3),
      records: const [],
      savedAt: DateTime(2026, 7, 3),
    );

Widget _shell({
  Key? key,
  GlobalKey<MainShellState>? shellKey,
  int initialTab = 0,
}) {
  return MaterialApp(
    // 用 key 强制重建 State，避免二次 pumpWidget 复用旧 _index。
    home: MainShell(
      key: shellKey ?? key,
      claims: [_claim()],
      onSaveClaim: (_) {},
      onArchiveClaim: (_) {},
      onRestoreClaim: (_) {},
      onDeleteClaim: (_) {},
      themeMode: ThemeMode.system,
      onChangeThemeMode: (_) {},
      onDataRestored: () async {},
      initialTab: initialTab,
    ),
  );
}

/// 底部导航胶囊：MainShell 默认 radius=28；历史分段 tab 用 radius=16。
double _bottomPillLeft(WidgetTester tester) {
  final pills = tester
      .widgetList<SlidingPill>(find.byType(SlidingPill))
      .where((p) => p.radius == 28)
      .toList();
  expect(pills, isNotEmpty, reason: '底部导航应有 radius=28 的 SlidingPill');
  return pills.first.left;
}

Future<void> _pumpFrames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('initialTab=2 启动时胶囊停在「我的」', (tester) async {
    await tester.pumpWidget(_shell(key: const ValueKey('tab0'), initialTab: 0));
    await _pumpFrames(tester);
    final homeLeft = _bottomPillLeft(tester);

    await tester.pumpWidget(_shell(key: const ValueKey('tab2'), initialTab: 2));
    await _pumpFrames(tester);
    expect(_bottomPillLeft(tester), greaterThan(homeLeft));
  });

  testWidgets('selectTab(2) 把胶囊从首页移到「我的」', (tester) async {
    final key = GlobalKey<MainShellState>();
    await tester.pumpWidget(_shell(shellKey: key, initialTab: 0));
    await _pumpFrames(tester);
    final homeLeft = _bottomPillLeft(tester);

    key.currentState!.selectTab(2);
    await _pumpFrames(tester);
    final mineLeft = _bottomPillLeft(tester);
    expect(mineLeft, greaterThan(homeLeft));

    key.currentState!.selectTab(0);
    await _pumpFrames(tester);
    // 回到首页后 left 回到初始量级（弹簧可能未完全收敛，只比较量级）。
    expect(_bottomPillLeft(tester), lessThan(mineLeft));
  });

  testWidgets('selectTab 越界忽略，胶囊不动', (tester) async {
    final key = GlobalKey<MainShellState>();
    await tester.pumpWidget(_shell(shellKey: key, initialTab: 0));
    await _pumpFrames(tester);
    final homeLeft = _bottomPillLeft(tester);

    key.currentState!.selectTab(-1);
    key.currentState!.selectTab(99);
    await _pumpFrames(tester);
    expect(_bottomPillLeft(tester), homeLeft);
  });
}
