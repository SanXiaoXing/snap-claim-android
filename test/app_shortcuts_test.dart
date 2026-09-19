// 桌面入口项组装规则单测。
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/core/utils/app_shortcuts.dart';
import 'package:snap_claim_android/core/utils/entry_action.dart';
import 'package:snap_claim_android/features/invoice/models/claim.dart';
import 'package:snap_claim_android/features/invoice/models/record.dart';

Claim _claim({
  required String id,
  String name = '',
  bool archived = false,
  DateTime? savedAt,
  DateTime? start,
  DateTime? end,
  double train = 0,
  double allowance = 0,
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
  ];
  return Claim(
    id: id,
    name: name,
    startDate: start ?? DateTime(2026, 7, 1),
    endDate: end ?? DateTime(2026, 7, 3),
    records: records,
    allowance: allowance,
    savedAt: savedAt ?? DateTime(2026, 7, 1),
    archived: archived,
  );
}

void main() {
  group('claimShortcutTitle', () {
    test('有名用名，空名用日期区间', () {
      expect(
        claimShortcutTitle(_claim(id: 'a', name: '  上海出差  ')),
        '上海出差',
      );
      expect(
        claimShortcutTitle(_claim(id: 'a', name: '')),
        '20260701-20260703',
      );
    });
  });

  group('buildEntryItems（默认含新建，小组件等）', () {
    test('0 张未归档单 → 仅新建 + 加号图标', () {
      final items = buildEntryItems(const [], withIcons: true);
      expect(items, hasLength(1));
      expect(items.single.action, kNewClaimAction);
      expect(items.single.icon, kShortcutIconNew);
    });

    test('归档不出现；2+ 按 savedAt 降序取前 2，末尾追加新建', () {
      final items = buildEntryItems([
        _claim(id: 'old', name: '最旧', savedAt: DateTime(2026, 7, 1)),
        _claim(id: 'archived', name: '归档', archived: true, savedAt: DateTime(2026, 7, 20)),
        _claim(id: 'newest', name: '最新', savedAt: DateTime(2026, 7, 30)),
        _claim(
          id: 'noname',
          name: '',
          savedAt: DateTime(2026, 7, 15),
          start: DateTime(2026, 3, 2),
          end: DateTime(2026, 3, 5),
        ),
      ], withIcons: true);
      expect(items, hasLength(3));
      expect(items[0].title, '最新');
      expect(items[0].icon, kShortcutIconClaim);
      expect(items[1].title, '20260302-20260305');
      expect(items[1].icon, kShortcutIconClaim);
      expect(items[2].action, kNewClaimAction);
      expect(items[2].icon, kShortcutIconNew);
      for (final item in items) {
        expect(parseEntryAction(item.action), isNotNull);
      }
    });
  });

  group('buildEntryItems（长按菜单顺序）', () {
    test('「新建报销单」恒为最后一条，前面才是报销单', () {
      final items = buildEntryItems([
        _claim(id: 'old', name: '较旧', savedAt: DateTime(2026, 7, 1)),
        _claim(id: 'newest', name: '最新', savedAt: DateTime(2026, 7, 30)),
      ], withIcons: true);
      expect(items, hasLength(kMaxClaimShortcuts + 1));
      expect(items.last.action, kNewClaimAction);
      expect(items.last.title, '新建报销单');
      expect(items.last.icon, kShortcutIconNew);
      // 最后一条之前全是报销单，且各自指向编辑 action。
      for (final item in items.take(items.length - 1)) {
        expect(item.action.startsWith(kEditClaimPrefix), isTrue);
        expect(item.icon, kShortcutIconClaim);
      }
    });

    test('没有未归档单 → 菜单只剩「新建」一条（不留空菜单）', () {
      final items = buildEntryItems(
        [_claim(id: 'x', archived: true)],
        withIcons: true,
      );
      expect(items, hasLength(1));
      expect(items.single.action, kNewClaimAction);
    });
  });

  group('buildEntryItems（小组件）', () {
    test('withAmounts + maxClaims:1 → 最新 1 单 + 新建', () {
      final items = buildEntryItems(
        [
          _claim(id: 'a', name: '甲', savedAt: DateTime(2026, 7, 20), train: 100),
          _claim(id: 'c', name: '丙', savedAt: DateTime(2026, 7, 25), train: 300, allowance: 66),
        ],
        maxClaims: kQuickWidgetMaxClaims,
        withAmounts: true,
      );
      expect(items, hasLength(2));
      expect(items[0].title, '丙');
      expect(items[0].amountText, '¥366');
      expect(items[1].action, kNewClaimAction);
      expect(items[1].amountText, isNull);
    });
  });
}
