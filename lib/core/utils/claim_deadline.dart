import '../../features/invoice/models/claim.dart';

/// 出差结束日算第 0 天，第 30 天为提交财务的截止日。
DateTime claimDeadline(Claim claim) =>
    DateTime(claim.endDate.year, claim.endDate.month, claim.endDate.day + 30);

int claimDaysLeft(Claim claim, DateTime now) {
  final deadline = claimDeadline(claim);
  final today = DateTime(now.year, now.month, now.day);
  return DateTime.utc(
    deadline.year,
    deadline.month,
    deadline.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
}

bool claimNeedsWarning(Claim claim, DateTime now) =>
    !claim.archived &&
    !claim.submittedToFinance &&
    claimDaysLeft(claim, now) <= 7;
