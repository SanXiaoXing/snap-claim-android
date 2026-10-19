// MainShell 入口 tab 控制（issue #7）：initialTab + selectTab 切到「我的」。
// 三个页面常驻 Stack（仅 opacity/IgnorePointer），用底部 SlidingPill 的 left
// 断言当前 tab。首页 CTA 有循环呼吸动画，不能 pumpAndSettle。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/features/invoice/models/claim.dart';
import 'package:snap_claim_android/features/invoice/pages/main_shell.dart';
import 'package:snap_claim_android/features/invoice/widgets/ai_mascot.dart';
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

  testWidgets('底部导航拖拽时胶囊跟手，松手后切到相邻页', (tester) async {
    await tester.pumpWidget(_shell(initialTab: 1));
    await _pumpFrames(tester);
    final rest = _bottomPillLeft(tester);

    final gesture = await tester.startGesture(tester.getCenter(find.text('历史')));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(55, 0));
    await tester.pump();
    final midway = _bottomPillLeft(tester);
    expect(midway, greaterThan(rest + 30));

    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(_bottomPillLeft(tester), greaterThan(midway + 70));
    await gesture.up();
    await _pumpFrames(tester);
    expect(_bottomPillLeft(tester), greaterThan(rest + 100));
    expect(find.text('我的'), findsWidgets);
  });

  testWidgets('底部导航小幅慢拖后回弹，不切换页面', (tester) async {
    await tester.pumpWidget(_shell(initialTab: 1));
    await _pumpFrames(tester);
    final rest = _bottomPillLeft(tester);

    await tester.timedDrag(
      find.text('历史'),
      const Offset(45, 0),
      const Duration(milliseconds: 600),
    );
    await _pumpFrames(tester);
    expect(_bottomPillLeft(tester), closeTo(rest, 0.5));
  });

  testWidgets('AI 球按触点转向并眨眼，取消触碰后恢复待机', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: AiBallButton()))),
    );
    final ball = find.byType(AiBallButton);
    final left = await tester.startGesture(
      tester.getCenter(ball) + const Offset(-14, 0),
    );
    var minEyeScale = 1.0;
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final transforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(AIMascot),
          matching: find.byType(Transform),
        ),
      ).toList();
      final eyeScale = transforms.last.transform.storage[5];
      if (eyeScale < minEyeScale) minEyeScale = eyeScale;
    }
    expect(tester.widget<AIMascot>(find.byType(AIMascot)).awake, isTrue);
    expect(tester.widget<AIMascot>(find.byType(AIMascot)).lookLeft, isTrue);
    expect(minEyeScale, lessThan(0.4), reason: '触碰时应眨一次眼');

    await left.cancel();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<AIMascot>(find.byType(AIMascot)).awake, isFalse);

    final right = await tester.startGesture(
      tester.getCenter(ball) + const Offset(14, 0),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<AIMascot>(find.byType(AIMascot)).lookLeft, isFalse);
    await right.cancel();
  });
}
