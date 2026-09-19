// 桌面「公司欠我」金额与 URI 解析单测。
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/core/utils/owed_widget.dart';
import 'package:snap_claim_android/features/invoice/models/claim.dart';
import 'package:snap_claim_android/features/invoice/models/record.dart';

Claim _claim({
  required String id,
  double train = 0,
  double highway = 0,
  double subway = 0,
  double allowance = 0,
  double excess = 0,
  bool archived = false,
}) {
  final records = <Record>[
    if (train != 0)
      Record(
        id: '$id-train',
        category: RecordCategory.train,
        title: '火车',
        subtitle: '',
        amount: train,
      ),
    if (highway != 0)
      Record(
        id: '$id-hw',
        category: RecordCategory.highway,
        title: '高速',
        subtitle: '',
        amount: highway,
      ),
    if (subway != 0)
      Record(
        id: '$id-sub',
        category: RecordCategory.subway,
        title: '地铁',
        subtitle: '',
        amount: subway,
      ),
  ];
  return Claim(
    id: id,
    name: '单$id',
    startDate: DateTime(2026, 7, 1),
    endDate: DateTime(2026, 7, 3),
    records: records,
    allowance: allowance,
    excessAmount: excess,
    archived: archived,
    savedAt: DateTime(2026, 7, 3),
  );
}

void main() {
  group('owedTotal', () {
    test('空列表 → 0', () {
      expect(owedTotal(const []), 0);
    });

    test('仅计未归档单的 balanceAmount', () {
      expect(
        owedTotal([
          _claim(id: 'a', train: 100, allowance: 50),
          _claim(id: 'b', train: 200, archived: true),
          _claim(id: 'c', highway: 30, subway: 20),
        ]),
        200,
      );
    });

    test('全部已归档 → 0', () {
      expect(
        owedTotal([
          _claim(id: 'a', train: 100, archived: true),
          _claim(id: 'b', train: 999, archived: true),
        ]),
        0,
      );
    });

    test('超标从退补中扣除后再合计', () {
      expect(
        owedTotal([_claim(id: 'a', train: 500, allowance: 100, excess: 80)]),
        520,
      );
    });
  });

  group('parseHomeWidgetEntryUri', () {
    test('合法 action', () {
      expect(
        parseHomeWidgetEntryUri(Uri.parse('snapclaim://entry/open_mine')),
        'open_mine',
      );
      expect(
        parseHomeWidgetEntryUri(Uri.parse('snapclaim://entry/new_claim')),
        'new_claim',
      );
      expect(
        parseHomeWidgetEntryUri(
          Uri.parse('snapclaim://entry/edit_claim/abc-123'),
        ),
        'edit_claim:abc-123',
      );
    });

    test('非法协议 / 缺 id → null', () {
      expect(parseHomeWidgetEntryUri(null), isNull);
      expect(parseHomeWidgetEntryUri(Uri.parse('https://example.com')), isNull);
      expect(
        parseHomeWidgetEntryUri(Uri.parse('snapclaim://entry/edit_claim/')),
        isNull,
      );
      expect(parseHomeWidgetEntryUri(Uri.parse('snapclaim://entry/')), isNull);
    });
  });
}
