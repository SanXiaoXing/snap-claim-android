import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_claim_android/app/theme.dart';
import 'package:snap_claim_android/features/invoice/models/claim.dart';
import 'package:snap_claim_android/features/invoice/models/record.dart';
import 'package:snap_claim_android/features/invoice/pages/editor_page.dart';

void main() {
  testWidgets('修改已有明细后保存，保留 ID 并更新所有字段', (tester) async {
    final original = Record(
      id: 'existing',
      category: RecordCategory.train,
      title: '旧标题',
      subtitle: '旧备注',
      amount: 100,
    );
    final claim = Claim(
      id: 'claim',
      name: '测试报销单',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 2),
      records: [original],
      savedAt: DateTime(2026, 7, 2),
    );
    Claim? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: EditorPage(claim: claim, onSave: (value) => saved = value),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('旧标题'));
    await tester.pumpAndSettle();
    expect(find.text('编辑明细'), findsOneWidget);
    await tester.tap(find.text('用车').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('往返交通').last);
    await tester.enterText(find.byType(TextField).at(1), '新标题');
    await tester.enterText(find.byType(TextField).at(2), '新备注');
    await tester.enterText(find.byType(TextField).at(3), '250.5');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('新标题'), findsOneWidget);
    expect(find.text('往返交通 · 新备注'), findsOneWidget);
    expect(saved, isNull);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('保存修改？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    final updated = saved!.records.single;
    expect(updated.id, 'existing');
    expect(updated.category, RecordCategory.car);
    expect(updated.carTripType, CarTripType.roundTrip);
    expect(updated.title, '新标题');
    expect(updated.subtitle, '新备注');
    expect(updated.amount, 250.5);
    expect(saved!.recordsTotal, 250.5);
  });
}
