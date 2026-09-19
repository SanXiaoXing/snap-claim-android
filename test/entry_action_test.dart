// 桌面入口 action 分发单测。
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/core/utils/entry_action.dart';
import 'package:snap_claim_android/core/utils/owed_widget.dart';

void main() {
  group('parseEntryAction', () {
    test('open_mine / new_claim', () {
      expect(parseEntryAction('open_mine')?.kind, EntryActionKind.openMine);
      expect(parseEntryAction('new_claim')?.kind, EntryActionKind.newClaim);
    });

    test('edit_claim_<id>（推荐，无冒号）', () {
      final action = parseEntryAction('edit_claim_abc-123');
      expect(action?.kind, EntryActionKind.editClaim);
      expect(action?.claimId, 'abc-123');
    });

    test('edit_claim:<id>（旧协议兼容）', () {
      final action = parseEntryAction('edit_claim:abc-123');
      expect(action?.kind, EntryActionKind.editClaim);
      expect(action?.claimId, 'abc-123');
    });

    test('非法 / 空白 / 缺 id → null', () {
      expect(parseEntryAction('edit_claim_'), isNull);
      expect(parseEntryAction('edit_claim:'), isNull);
      expect(parseEntryAction(''), isNull);
      expect(parseEntryAction('   '), isNull);
      expect(parseEntryAction('open_home'), isNull);
    });

    test('允许前后空白', () {
      expect(parseEntryAction('  open_mine  ')?.kind, EntryActionKind.openMine);
    });
  });

  group('parseHomeWidgetEntryUri', () {
    test('slash 路径 → edit_claim_<id>', () {
      expect(
        parseHomeWidgetEntryUri(Uri.parse('snapclaim://entry/edit_claim/abc-123')),
        'edit_claim_abc-123',
      );
    });

    test('整段 path 已是 action', () {
      expect(
        parseHomeWidgetEntryUri(Uri.parse('snapclaim://entry/edit_claim_abc-123')),
        'edit_claim_abc-123',
      );
      expect(
        parseHomeWidgetEntryUri(Uri.parse('snapclaim://entry/new_claim')),
        'new_claim',
      );
    });
  });

  group('entryActionDedupeKey', () {
    test('与协议字符串一致，便于短窗去重', () {
      expect(
        entryActionDedupeKey(const EntryAction(EntryActionKind.openMine)),
        kOpenMineAction,
      );
      expect(
        entryActionDedupeKey(const EntryAction(EntryActionKind.newClaim)),
        kNewClaimAction,
      );
      expect(
        entryActionDedupeKey(
          const EntryAction(EntryActionKind.editClaim, claimId: 'abc-123'),
        ),
        'edit_claim_abc-123',
      );
      expect(kEntryActionDedupeWindow, const Duration(milliseconds: 800));
    });
  });

  group('EntryActionReceiver', () {
    setUp(EntryActionReceiver.takePending);

    test('无监听时 emit 进入 pending，takePending 取走并清空', () {
      EntryActionReceiver.emit('open_mine');
      EntryActionReceiver.emit('new_claim');
      final pending = EntryActionReceiver.takePending();
      expect(pending, hasLength(2));
      expect(pending[0].kind, EntryActionKind.openMine);
      expect(pending[1].kind, EntryActionKind.newClaim);
      expect(EntryActionReceiver.takePending(), isEmpty);
    });

    test('非法 action 不进入 pending', () {
      EntryActionReceiver.emit('edit_claim_');
      EntryActionReceiver.emit('edit_claim:');
      EntryActionReceiver.emit('nope');
      expect(EntryActionReceiver.takePending(), isEmpty);
    });
  });
}
