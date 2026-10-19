import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_claim_android/features/invoice/widgets/swipe_action_row.dart';
import 'package:snap_claim_android/features/invoice/widgets/swipe_background.dart';
import 'package:snap_claim_android/features/invoice/widgets/record_row.dart';
import 'package:snap_claim_android/features/invoice/models/record.dart';
import 'package:snap_claim_android/app/theme.dart';

void main() {
  testWidgets('两侧跟手、80px 吸附和按钮点击', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: SwipeActionRow(
                leftAction: SwipeAction(
                  icon: Icons.undo,
                  label: '撤销',
                  from: Colors.blue,
                  to: Colors.blue,
                  removesRow: false,
                  onTriggered: () => calls.add('left'),
                ),
                rightAction: SwipeAction(
                  icon: Icons.delete,
                  label: '删除',
                  from: Colors.red,
                  to: Colors.red,
                  onTriggered: () => calls.add('right'),
                ),
                child: Container(
                  height: 60,
                  color: Colors.white,
                  child: const Center(child: Text('目标行')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final row = find.text('目标行');
    final originalX = tester.getCenter(row).dx;
    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(tester.getCenter(row).dx, greaterThan(originalX + 20));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getCenter(row).dx, closeTo(originalX, 1));

    await tester.drag(row, const Offset(130, 0));
    await tester.pumpAndSettle();
    expect(tester.getCenter(row).dx, closeTo(originalX + 152, 1));
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(tester.getCenter(row).dx, closeTo(originalX, 1));
    expect(calls, ['left']);

    await tester.drag(row, const Offset(-130, 0));
    await tester.pumpAndSettle();
    expect(tester.getCenter(row).dx, closeTo(originalX - 152, 1));
    expect(find.text('删除'), findsOneWidget);
    expect(calls, ['left']);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(calls, ['left', 'right']);
  });

  testWidgets('用车切换只更新类型，回位期间行高、不透明度和下一行位置不变', (tester) async {
    var tripType = CarTripType.city;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 400,
                child: Column(
                  children: [
                    DismissibleRecordRow(
                      record: Record(
                        id: 'car',
                        category: RecordCategory.car,
                        title: '用车明细',
                        subtitle: '',
                        amount: 20,
                        carTripType: tripType,
                      ),
                      dismissKey: const ValueKey('car'),
                      onDismissed: () => fail('切换类型不能删除明细'),
                      onTripTypeChanged: (type) =>
                          setState(() => tripType = type),
                    ),
                    const Text('下一行'),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    final row = find.byType(RecordRow);
    final rest = tester.getRect(row);
    final nextY = tester.getTopLeft(find.text('下一行')).dy;
    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(220, 0));
    await tester.pump();
    final background = tester.getRect(find.byType(SwipeBackground));
    expect(background.left, rest.left);
    expect(background.width, rest.width);
    expect(
      background.contains(Offset(rest.left + 200, rest.center.dy)),
      isTrue,
    );
    await gesture.up();
    await tester.pump();
    expect(tripType, CarTripType.roundTrip);
    expect(find.text('往返交通'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 75));
      expect(tester.getSize(row).height, rest.height);
      expect(tester.getTopLeft(find.text('下一行')).dy, nextY);
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: row, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 1);
    }
    await tester.pumpAndSettle();
    expect(tester.getRect(row), rest);
  });

  testWidgets('过半宽后滑出淡出并收缩，下一行补位', (tester) async {
    var removed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 400,
                child: Column(
                  children: [
                    if (!removed)
                      SwipeActionRow(
                        rightAction: SwipeAction(
                          icon: Icons.delete,
                          label: '删除',
                          from: Colors.red,
                          to: Colors.red,
                          onTriggered: () => setState(() => removed = true),
                        ),
                        bottomSpacing: 10,
                        child: Container(
                          height: 60,
                          color: Colors.white,
                          child: const Text('第一行'),
                        ),
                      ),
                    const SizedBox(height: 60, child: Text('第二行')),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    final secondY = tester.getTopLeft(find.text('第二行')).dy;
    final firstRect = tester.getRect(find.byType(SwipeActionRow));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('第一行')),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.moveBy(const Offset(-220, 0));
    await tester.pump();
    final background = tester.getRect(find.byType(SwipeBackground));
    expect(background.width, firstRect.width);
    expect(background.right, firstRect.right);
    expect(
      background.contains(Offset(firstRect.right - 200, background.center.dy)),
      isTrue,
    );
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getTopLeft(find.text('第二行')).dy, lessThan(secondY));
    expect(removed, isFalse);
    await tester.pumpAndSettle();
    expect(removed, isTrue);
    expect(find.text('第一行'), findsNothing);
  });
}
