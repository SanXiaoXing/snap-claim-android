import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_claim_android/app/theme.dart';
import 'package:snap_claim_android/features/settings/widgets/wheel_time_picker.dart';

void main() {
  Future<TimeOfDay?> openPicker(
    WidgetTester tester, {
    TimeOfDay initial = const TimeOfDay(hour: 10, minute: 17),
    bool reducedMotion = false,
    Future<void> Function()? interact,
  }) async {
    TimeOfDay? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  picked = await showWheelTimePicker(
                    context,
                    initialTime: initial,
                  );
                },
                child: const Text('选择时间'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('选择时间'));
    await tester.pumpAndSettle();
    if (interact != null) await interact();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('键盘上下键可调整小时', (tester) async {
    final picked = await openPicker(
      tester,
      interact: () async {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      },
    );
    expect(picked, const TimeOfDay(hour: 11, minute: 17));
  });

  testWidgets('点击可见行跳转，减少动态时也能选择', (tester) async {
    final picked = await openPicker(
      tester,
      reducedMotion: true,
      interact: () async {
        await tester.tap(find.text('12'));
        await tester.pumpAndSettle();
      },
    );
    expect(picked, const TimeOfDay(hour: 12, minute: 17));
  });

  testWidgets('触摸拖拽能改变小时', (tester) async {
    final picked = await openPicker(
      tester,
      initial: const TimeOfDay(hour: 10, minute: 0),
      interact: () async {
        await tester.drag(
          find.byKey(const ValueKey('小时-wheel')),
          const Offset(0, -96),
        );
        await tester.pumpAndSettle();
      },
    );
    expect(picked?.hour, isNot(10));
  });

  testWidgets('小时从零点向上可循环到 23 点', (tester) async {
    final picked = await openPicker(
      tester,
      initial: const TimeOfDay(hour: 0, minute: 58),
      interact: () async {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
      },
    );
    expect(picked, const TimeOfDay(hour: 23, minute: 58));
  });

  testWidgets('鼠标滚轮能改变小时', (tester) async {
    final picked = await openPicker(
      tester,
      initial: const TimeOfDay(hour: 10, minute: 0),
      interact: () async {
        final center = tester.getCenter(find.byKey(const ValueKey('小时-wheel')));
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: center,
            scrollDelta: const Offset(0, 80),
          ),
        );
        await tester.pumpAndSettle();
        final scrollable = tester.state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('小时-wheel')),
            matching: find.byWidgetPredicate((widget) => widget is Scrollable),
          ),
        );
        final remainder = scrollable.position.pixels % 48;
        expect(remainder < 24 ? remainder : 48 - remainder, lessThan(0.5));
      },
    );
    expect(picked?.hour, isNot(10));
  });
}
