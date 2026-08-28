// 报销统计页回归测试：月度分布必须使用「退补金额」口径，
// 与页面累计退补金额一致，且基于当前数据实时计算。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/app/theme.dart';
import 'package:snap_claim_android/features/invoice/models/claim.dart';
import 'package:snap_claim_android/features/invoice/models/record.dart';
import 'package:snap_claim_android/features/settings/pages/stats_page.dart';

/// 一张混合报销单：明细含预借金额（飞机/酒店/用车）与超标金额，
/// 使 total（总金额）与 balanceAmount（退补金额）产生明显差异，
/// 用于断言月度分布按退补金额统计。
Claim _mixedClaim(
  String id,
  int month, {
  double excess = 0,
  double allowance = 0,
}) {
  final now = DateTime.now();
  return Claim(
    id: id,
    name: '报销单$id',
    startDate: DateTime(now.year, month, 5),
    endDate: DateTime(now.year, month, 7),
    savedAt: DateTime(now.year, month, 7),
    allowance: allowance,
    excessAmount: excess,
    records: [
      Record(
        id: 'r$id-train',
        category: RecordCategory.train,
        title: '火车票',
        subtitle: '',
        amount: 553,
      ),
      Record(
        id: 'r$id-highway',
        category: RecordCategory.highway,
        title: '高速费',
        subtitle: '',
        amount: 35,
      ),
      Record(
        id: 'r$id-subway',
        category: RecordCategory.subway,
        title: '地铁费',
        subtitle: '',
        amount: 10,
      ),
      // 预借金额：不计入退补金额，但计入总金额。
      Record(
        id: 'r$id-flight',
        category: RecordCategory.flight,
        title: '机票',
        subtitle: '',
        amount: 800,
      ),
      Record(
        id: 'r$id-hotel',
        category: RecordCategory.hotel,
        title: '酒店',
        subtitle: '',
        amount: 300,
      ),
      Record(
        id: 'r$id-car',
        category: RecordCategory.car,
        title: '用车',
        subtitle: '',
        amount: 50,
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, StatsPage page) async {
  await tester.pumpWidget(
    MaterialApp(theme: buildLightTheme(), home: page),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('月度分布按退补金额统计，而非总金额', (tester) async {
    final now = DateTime.now();
    // 7 月：明细 1748（含预借 1150）+ 差补 200 + 超标 100
    //   → total 2048，退补金额 = 553+35+10+200-100 = 698
    final claim = _mixedClaim('c1', 7, excess: 100, allowance: 200);
    await _pump(tester, StatsPage(claims: [claim]));

    // 退补金额口径：7 月显示 ¥698。
    expect(find.text('¥698'), findsOneWidget);
    // 总金额口径（含预借/超标）不应出现。
    expect(find.text('¥2,048'), findsNothing);
    // 若使用 total 口径，7 月会显示 ¥2,048，且不会出现 ¥698。
    expect(claim.total, 2048.0);
    expect(claim.balanceAmount, 698.0);
    // 统计页按当前年份过滤，保证测试数据确实在统计范围内。
    expect(now.year, DateTime(now.year, 7, 5).year);
  });

  testWidgets('多个月份：月度分布与累计退补金额同口径', (tester) async {
    final now = DateTime.now();
    // 7 月退补 698；8 月：火车 553 + 差补 100 → 退补 653，total = 1053。
    final july = _mixedClaim('c7', 7, excess: 100, allowance: 200);
    final aug = Claim(
      id: 'c8',
      name: '8月报销',
      startDate: DateTime(now.year, 8, 2),
      endDate: DateTime(now.year, 8, 3),
      savedAt: DateTime(now.year, 8, 3),
      allowance: 100,
      records: [
        Record(
          id: 'r8-train',
          category: RecordCategory.train,
          title: '火车票',
          subtitle: '',
          amount: 553,
        ),
        // 预借金额：计入总金额但不计入退补金额。
        Record(
          id: 'r8-flight',
          category: RecordCategory.flight,
          title: '机票',
          subtitle: '',
          amount: 400,
        ),
      ],
    );
    expect(aug.balanceAmount, 653.0);
    expect(aug.total, 1053.0);

    await _pump(tester, StatsPage(claims: [july, aug]));

    expect(find.text('¥698'), findsOneWidget);
    expect(find.text('¥653'), findsOneWidget);
    // 总金额口径的数值不应出现在月度分布中。
    expect(find.text('¥1,053'), findsNothing);
    expect(find.text('¥2,048'), findsNothing);
    // 累计退补 = 698 + 653 = 1351，与月度分布合计一致（同口径）。
    // 该金额同时展示在年度大卡片与「累计退补」指标卡两处。
    expect(find.text('¥1,351.00'), findsNWidgets(2));
  });

  testWidgets('删除归档数据后统计随最新数据重算', (tester) async {
    final kept = _mixedClaim('keep', 7, excess: 100, allowance: 200);
    final deleted = _mixedClaim('gone', 8, excess: 0, allowance: 100);
    var claims = [kept, deleted];
    await _pump(tester, StatsPage(claims: claims));

    // 删除前：7 月 ¥698、8 月 ¥698（deleted 退补 = 553+35+10+100 = 698）。
    expect(find.text('¥698'), findsNWidgets(2));

    // 模拟归档页删除后上层更新数据，重新进入统计页。
    claims = [kept];
    await _pump(tester, StatsPage(claims: claims));

    // 删除后：只剩 7 月 ¥698，8 月金额消失。
    expect(find.text('¥698'), findsOneWidget);
  });
}
