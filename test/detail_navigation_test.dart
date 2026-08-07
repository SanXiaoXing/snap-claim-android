// 详情页导航回归测试：
// - 无改动从编辑页返回应留在详情页（曾误跳两级）；
// - 保存修改后详情页应关闭回到列表。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/app/theme.dart';
import 'package:snap_claim_android/features/invoice/models/claim.dart';
import 'package:snap_claim_android/features/invoice/pages/detail_page.dart';
import 'package:snap_claim_android/features/invoice/pages/editor_page.dart';
import 'package:snap_claim_android/src/rust/frb_generated.dart';

/// 入口页：模拟列表页，push 详情页后形成「列表 → 详情 → 编辑」导航栈。
class _Launcher extends StatelessWidget {
  final Claim claim;
  const _Launcher({required this.claim});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DetailPage(claim: claim, onSave: (_) {}),
            ),
          ),
          child: const Text('打开详情'),
        ),
      ),
    );
  }
}

Claim _claim() => Claim(
      id: 'c1',
      name: '测试报销单',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 3),
      records: const [],
      savedAt: DateTime(2026, 7, 3),
    );

Future<void> _pumpToEditor(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(theme: buildLightTheme(), home: _Launcher(claim: _claim())),
  );
  await tester.tap(find.text('打开详情'));
  await tester.pumpAndSettle();
  expect(find.text('报销详情'), findsOneWidget);
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  expect(find.text('保存'), findsOneWidget);
}

void main() {
  setUpAll(() async => await RustLib.init());

  testWidgets('无改动从编辑页返回时留在详情页，不跳两级', (tester) async {
    await _pumpToEditor(tester);

    // 未做任何修改，直接点返回。
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    // 应回到详情页，而不是直接跳过详情页落到列表。
    expect(find.byType(DetailPage), findsOneWidget);
    expect(find.text('报销详情'), findsOneWidget);
    expect(find.text('打开详情'), findsNothing);
  });

  testWidgets('保存修改后编辑页与详情页依次关闭回到列表', (tester) async {
    await _pumpToEditor(tester);

    // 修改名称使其变为脏状态，然后保存。
    await tester.enterText(find.byType(TextField).first, '改名后的报销单');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 编辑页保存后，详情页应一并关闭，回到列表入口。
    expect(find.byType(EditorPage), findsNothing);
    expect(find.byType(DetailPage), findsNothing);
    expect(find.text('打开详情'), findsOneWidget);
  });
}
