import 'package:flutter_test/flutter_test.dart';
import 'package:snap_claim_android/core/utils/claim_deadline.dart';
import 'package:snap_claim_android/features/invoice/models/claim.dart';

Claim claimEnding(
  DateTime end, {
  bool archived = false,
  bool submitted = false,
}) => Claim(
  id: 'deadline',
  name: '出差',
  startDate: end,
  endDate: end,
  records: const [],
  savedAt: end,
  archived: archived,
  submittedToFinance: submitted,
);

void main() {
  test('出差结束后第 30 天截止，第 23 天开始提醒', () {
    final claim = claimEnding(DateTime(2026, 1, 31));
    expect(claimDeadline(claim), DateTime(2026, 3, 2));
    expect(claimDaysLeft(claim, DateTime(2026, 2, 22)), 8);
    expect(claimNeedsWarning(claim, DateTime(2026, 2, 22)), isFalse);
    expect(claimDaysLeft(claim, DateTime(2026, 2, 23)), 7);
    expect(claimNeedsWarning(claim, DateTime(2026, 2, 23)), isTrue);
    expect(claimDaysLeft(claim, DateTime(2026, 3, 3)), -1);
    expect(claimNeedsWarning(claim, DateTime(2026, 3, 3)), isTrue);
  });

  test('已提交财务或已报销停止期限警告', () {
    final end = DateTime(2026, 1, 31);
    final today = DateTime(2026, 3, 3);
    expect(
      claimNeedsWarning(claimEnding(end, submitted: true), today),
      isFalse,
    );
    expect(claimNeedsWarning(claimEnding(end, archived: true), today), isFalse);
  });
}
