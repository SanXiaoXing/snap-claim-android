// 报销统计「类别占比」口径测试：
// 必须与 Claim.summaryRows / Claim.balanceAmount 完全一致，
// 既不把预借金额（飞机/酒店/用车）算进报销，也不能漏掉差补与超标金额。
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/features/invoice/models/claim.dart';
import 'package:snap_claim_android/features/invoice/models/record.dart';
import 'package:snap_claim_android/features/settings/models/stats_breakdown.dart';

/// 明细含预借（飞机 800 / 酒店 300 / 用车 50）+ 超标 100 + 差补 200 的报销单。
/// 退补毛额 = 火车 553 + 高速 35 + 地铁 10 + 差补 200 = 798
/// 退补金额 = 798 − 超标 100 = 698
/// 预借金额 = 800 + 300 + 50 = 1150
Claim _mixedClaim() => Claim(
  id: 'c1',
  name: '混合报销单',
  startDate: DateTime(2026, 7, 5),
  endDate: DateTime(2026, 7, 7),
  savedAt: DateTime(2026, 7, 7),
  allowance: 200,
  excessAmount: 100,
  records: [
    const Record(
      id: 'r1',
      category: RecordCategory.train,
      title: '火车票',
      subtitle: '',
      amount: 553,
    ),
    const Record(
      id: 'r2',
      category: RecordCategory.highway,
      title: '高速费',
      subtitle: '',
      amount: 35,
    ),
    const Record(
      id: 'r3',
      category: RecordCategory.subway,
      title: '地铁费',
      subtitle: '',
      amount: 10,
    ),
    const Record(
      id: 'r4',
      category: RecordCategory.flight,
      title: '机票',
      subtitle: '',
      amount: 800,
    ),
    const Record(
      id: 'r5',
      category: RecordCategory.hotel,
      title: '酒店',
      subtitle: '',
      amount: 300,
    ),
    const Record(
      id: 'r6',
      category: RecordCategory.car,
      title: '打车',
      subtitle: '',
      amount: 50,
    ),
  ],
);

void main() {
  group('退补构成', () {
    test('只包含火车/高速费/地铁费/差补，不含预借金额', () {
      final b = StatsBreakdown.compute([_mixedClaim()]);
      final labels = b.balance.slices.map((s) => s.label).toList();

      expect(labels, ['火车', '差补', '高速费', '地铁费']);
      // 飞机 / 酒店 / 用车属于预借金额，不得混入报销构成。
      expect(labels, isNot(contains('飞机')));
      expect(labels, isNot(contains('酒店')));
      expect(labels, isNot(contains('市内交通')));
      expect(labels, isNot(contains('往返交通')));
    });

    test('毛额 - 超标 = 累计退补金额（与 Claim.balanceAmount 同口径）', () {
      final claim = _mixedClaim();
      final b = StatsBreakdown.compute([claim]);

      expect(b.balance.gross, 798.0);
      expect(b.balance.deduction, 100.0);
      expect(b.balance.hasDeduction, isTrue);
      expect(b.balance.net, claim.balanceAmount);
    });

    test('各项占比相加为 100%', () {
      final b = StatsBreakdown.compute([_mixedClaim()]);
      final sum = b.balance.slices.fold(0.0, (s, e) => s + e.ratio);
      expect(sum, closeTo(1.0, 1e-9));

      // 火车 553 / 798 ≈ 69.3%。
      expect(b.balance.slices.first.percentText, '69.3%');
    });

    test('超标金额为 0 时不展示扣减项', () {
      final claim = _mixedClaim().copyWith(excessAmount: 0);
      final b = StatsBreakdown.compute([claim]);

      expect(b.balance.hasDeduction, isFalse);
      expect(b.balance.net, b.balance.gross);
    });
  });

  group('预借构成', () {
    test('包含飞机/酒店/用车，合计等于预借金额', () {
      final b = StatsBreakdown.compute([_mixedClaim()]);
      final labels = b.advance.slices.map((s) => s.label).toList();

      expect(labels, ['飞机', '酒店', '市内交通']);
      expect(b.advance.net, 1150.0);
      expect(b.advance.hasDeduction, isFalse);
    });

    test('用车按市内交通 / 往返交通拆分，与报销汇总一致', () {
      final claim = Claim(
        id: 'c2',
        name: '用车报销单',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 2),
        savedAt: DateTime(2026, 8, 2),
        records: [
          const Record(
            id: 'r1',
            category: RecordCategory.car,
            title: '市内打车',
            subtitle: '',
            amount: 30,
          ),
          const Record(
            id: 'r2',
            category: RecordCategory.car,
            title: '机场往返',
            subtitle: '',
            amount: 20,
            carTripType: CarTripType.roundTrip,
          ),
          const Record(
            id: 'r3',
            category: RecordCategory.train,
            title: '火车票',
            subtitle: '',
            amount: 100,
          ),
        ],
      );
      final b = StatsBreakdown.compute([claim]);

      final advance = <String, StatsSlice>{
        for (final s in b.advance.slices) s.label: s,
      };
      // 市内交通 = 用车总额 50 − 往返 20 = 30；火车不属于预借。
      expect(advance['市内交通']!.amount, 30.0);
      expect(advance['市内交通']!.count, 1);
      expect(advance['往返交通']!.amount, 20.0);
      expect(advance['往返交通']!.count, 1);
      expect(advance.containsKey('火车'), isFalse);
      expect(b.advance.net, 50.0);
    });
  });

  group('边界情况', () {
    test('金额为 0 的项不展示（与报销汇总一致）', () {
      final claim = Claim(
        id: 'c3',
        name: '只有火车',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 2),
        savedAt: DateTime(2026, 8, 2),
        records: [
          const Record(
            id: 'r1',
            category: RecordCategory.train,
            title: '火车票',
            subtitle: '',
            amount: 100,
          ),
        ],
      );
      final b = StatsBreakdown.compute([claim]);

      // 无差补、无超标、无预借：只保留火车一项，占比 100%。
      expect(b.balance.slices.map((s) => s.label).toList(), ['火车']);
      expect(b.balance.slices.single.ratio, 1.0);
      expect(b.advance.isEmpty, isTrue);
    });

    test('无数据：两组均为空', () {
      final b = StatsBreakdown.compute([]);

      expect(b.isEmpty, isTrue);
      expect(b.balance.isEmpty, isTrue);
      expect(b.advance.isEmpty, isTrue);
      expect(b.balance.net, 0.0);
    });
  });
}
