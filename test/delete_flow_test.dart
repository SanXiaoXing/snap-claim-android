// 删除流程回归测试：覆盖归档页 / 历史页 / 编辑页三条删除路径。
// 用 pumpAndSettle 检测「卡死」（无限动画/重建会导致超时抛出），
// 并断言删除后列表正确移除、无异常。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/app/theme.dart';
import 'package:snap_claim_android/features/invoice/models/claim.dart';
import 'package:snap_claim_android/features/invoice/models/record.dart';
import 'package:snap_claim_android/features/invoice/pages/archive_page.dart';
import 'package:snap_claim_android/features/invoice/pages/editor_page.dart';
import 'package:snap_claim_android/features/invoice/pages/history_page.dart';
import 'package:snap_claim_android/src/rust/frb_generated.dart';

Record _record(String id, {RecordCategory category = RecordCategory.train}) =>
    Record(
      id: id,
      category: category,
      title: '明细$id',
      subtitle: '',
      amount: 100,
    );

Claim _claim(String id, {List<Record>? records, bool archived = false}) =>
    Claim(
      id: id,
      name: '报销单$id',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 3),
      records: records ?? [_record('r$id')],
      savedAt: DateTime(2026, 7, 3),
      archived: archived,
    );

Future<void> _pump(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(MaterialApp(theme: buildLightTheme(), home: page));
  await tester.pumpAndSettle();
}

/// 左滑列表项并确认对话框里的「删除」。
Future<void> _swipeAndConfirm(WidgetTester tester, Finder item) async {
  // 编辑页明细在可滚动区域内，先滚动到可见再拖拽。
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.drag(item, const Offset(-600, 0));
  await tester.pumpAndSettle();
  await tester.tap(find.text('删除').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => await RustLib.init());

  testWidgets('编辑页左滑删除明细后行消失且不卡死', (tester) async {
    final deleted = <String>[];
    final claim = _claim('c1', records: [
      _record('r1'),
      _record('r2'),
    ]);
    var saved = false;
    await _pump(
      tester,
      EditorPage(
        claim: claim,
        onSave: (_) => saved = true,
      ),
    );

    expect(find.text('明细r1'), findsOneWidget);
    expect(find.text('明细r2'), findsOneWidget);

    // 左滑第一行 → 确认删除。
    await _swipeAndConfirm(tester, find.text('明细r1'));
    deleted.add('r1');

    expect(find.text('明细r1'), findsNothing);
    expect(find.text('明细r2'), findsOneWidget);
    expect(find.text('明细记录（1）'), findsOneWidget);
    expect(saved, isFalse);
    // pumpAndSettle 已通过 => 无无限动画（不卡死）。
  });

  testWidgets('归档页左滑删除报销单后卡片消失且不卡死', (tester) async {
    final deleted = <String>[];
    await _pump(
      tester,
      ArchivePage(
        claims: [_claim('a1'), _claim('a2')],
        onRestore: (_) {},
        onDelete: (c) => deleted.add(c.id),
      ),
    );

    expect(find.text('报销单a1'), findsOneWidget);
    expect(find.text('报销单a2'), findsOneWidget);

    await _swipeAndConfirm(tester, find.text('报销单a1'));
    deleted.add('a1');

    expect(find.text('报销单a1'), findsNothing);
    expect(find.text('报销单a2'), findsOneWidget);
  });

  testWidgets('历史页左滑归档报销单后卡片消失且不卡死', (tester) async {
    final archived = <String>[];
    await _pump(
      tester,
      HistoryPage(
        claims: [_claim('h1'), _claim('h2')],
        onSaveClaim: (_) {},
        onArchiveClaim: (c) => archived.add(c.id),
        onRestoreClaim: (_) {},
        onDeleteClaim: (_) {},
      ),
    );

    expect(find.text('报销单h1'), findsOneWidget);
    expect(find.text('报销单h2'), findsOneWidget);

    await tester.drag(find.text('报销单h1'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('报销单h1'), findsNothing);
    expect(find.text('报销单h2'), findsOneWidget);
    expect(archived, ['h1']);
  });

  testWidgets('归档页撤销归档（右滑）后卡片消失且不卡死', (tester) async {
    final restored = <String>[];
    await _pump(
      tester,
      ArchivePage(
        claims: [_claim('x1', archived: true), _claim('x2', archived: true)],
        onRestore: (c) => restored.add(c.id),
        onDelete: (_) {},
      ),
    );

    await tester.drag(find.text('报销单x1'), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(find.text('报销单x1'), findsNothing);
    expect(find.text('报销单x2'), findsOneWidget);
    expect(restored, ['x1']);
  });
}
