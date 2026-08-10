// 报销单汇总模型单测：
// - 退补金额 = 火车 + 高速费 + 地铁费 + 差补；
// - 汇总行金额为 0 时（没有对应内容）不显示该标签。
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/features/invoice/models/claim.dart';
import 'package:snap_claim_android/features/invoice/models/record.dart';

Record _record(String id, RecordCategory category, double amount) => Record(
      id: id,
      category: category,
      title: '明细$id',
      subtitle: '',
      amount: amount,
    );

void main() {
  test('退补金额 = 火车 + 高速费 + 地铁费 + 差补', () {
    final claim = Claim(
      id: 'c1',
      name: '测试',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 3),
      allowance: 200,
      records: [
        _record('r1', RecordCategory.train, 553),
        _record('r2', RecordCategory.highway, 35),
        _record('r3', RecordCategory.subway, 8),
      ],
      savedAt: DateTime(2026, 7, 3),
    );
    expect(claim.balanceAmount, 796);
  });

  test('汇总行没有对应内容（金额为 0）时不显示标签', () {
    final claim = Claim(
      id: 'c1',
      name: '测试',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 3),
      records: [
        _record('r1', RecordCategory.highway, 35),
        _record('r2', RecordCategory.subway, 8),
      ],
      savedAt: DateTime(2026, 7, 3),
    );
    final rows = claim.summaryRows;
    final labels = rows.map((r) => r.label).toList();
    // 无飞机/酒店/用车/差补内容，对应标签不出现。
    expect(labels, isNot(contains('飞机')));
    expect(labels, isNot(contains('酒店')));
    expect(labels, isNot(contains('市内交通')));
    expect(labels, isNot(contains('往返交通')));
    expect(labels, isNot(contains('差补')));
    expect(labels, isNot(contains('预借金额')));
    // 有内容与派生行仍展示。
    expect(labels, contains('高速费'));
    expect(labels, contains('地铁费'));
    expect(labels, contains('退补金额'));
    // 高速费 35 + 地铁费 8，退补金额 = 43。
    final balanceRow = rows.firstWhere((r) => r.label == '退补金额');
    expect(balanceRow.amount, 43);
  });
}
