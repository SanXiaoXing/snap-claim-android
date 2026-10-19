import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_claim_android/app/theme.dart';
import 'package:snap_claim_android/features/invoice/models/claim.dart';
import 'package:snap_claim_android/features/invoice/widgets/claim_card.dart';

void main() {
  testWidgets('最后七天卡片提醒，长按标记待打款后隐藏提醒', (tester) async {
    final now = DateTime.now();
    var claim = Claim(
      id: 'status-test',
      name: '测试出差',
      startDate: now.subtract(const Duration(days: 25)),
      endDate: now.subtract(const Duration(days: 24)),
      records: const [],
      savedAt: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ClaimCard(
                claim: claim,
                onSaveClaim: (updated) => setState(() => claim = updated),
              );
            },
          ),
        ),
      ),
    );

    expect(find.textContaining('剩余 6 天'), findsOneWidget);
    await tester.longPress(find.text('测试出差'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已提交财务 · 待打款'));
    await tester.pumpAndSettle();
    expect(claim.submittedToFinance, isTrue);
    expect(find.text('待打款'), findsOneWidget);
    expect(find.textContaining('剩余 6 天'), findsNothing);
  });
}
