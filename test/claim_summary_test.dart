// 报销单汇总模型单测：
// - 退补金额 = 火车 + 高速费 + 地铁费 + 差补 - 超标金额；
// - 总金额 = 明细总额 + 差补 + 超标金额；
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
    expect(claim.total, 796);
  });

  test('超标金额计入总金额并从退补金额中扣除', () {
    final claim = Claim(
      id: 'c1',
      name: '测试',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 3),
      allowance: 200,
      excessAmount: 150,
      records: [
        _record('r1', RecordCategory.train, 553),
        _record('r2', RecordCategory.highway, 35),
        _record('r3', RecordCategory.subway, 8),
      ],
      savedAt: DateTime(2026, 7, 3),
    );
    // 总金额 = 明细 596 + 差补 200 + 超标 150 = 946。
    expect(claim.recordsTotal, 596);
    expect(claim.total, 946);
    // 退补金额 = 553 + 35 + 8 + 200 - 150 = 646。
    expect(claim.balanceAmount, 646);
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
    // 未填写超标金额时，超标金额行不显示。
    expect(labels, isNot(contains('超标金额')));
    // 有内容与派生行仍展示。
    expect(labels, contains('高速费'));
    expect(labels, contains('地铁费'));
    expect(labels, contains('退补金额'));
    // 高速费 35 + 地铁费 8，退补金额 = 43。
    final balanceRow = rows.firstWhere((r) => r.label == '退补金额');
    expect(balanceRow.amount, 43);
  });

  test('超标金额行仅在填写后显示', () {
    final claim = Claim(
      id: 'c1',
      name: '测试',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 3),
      allowance: 200,
      excessAmount: 120,
      records: [
        _record('r1', RecordCategory.train, 100),
        _record('r2', RecordCategory.highway, 20),
      ],
      savedAt: DateTime(2026, 7, 3),
    );
    final rows = claim.summaryRows;
    final labels = rows.map((r) => r.label).toList();
    expect(labels, contains('超标金额'));
    final excessRow = rows.firstWhere((r) => r.label == '超标金额');
    expect(excessRow.amount, 120);
    // 退补金额 = 100 + 20 + 200 - 120 = 200。
    final balanceRow = rows.firstWhere((r) => r.label == '退补金额');
    expect(balanceRow.amount, 200);
  });
}
