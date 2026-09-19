// 桌面入口 action 分发单测。
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/core/utils/entry_action.dart';

void main() {
  group('parseEntryAction', () {
    test('open_mine / new_claim', () {
      expect(parseEntryAction('open_mine')?.kind, EntryActionKind.openMine);
      expect(parseEntryAction('new_claim')?.kind, EntryActionKind.newClaim);
    });

    test('edit_claim:<id>', () {
      final action = parseEntryAction('edit_claim:abc-123');
      expect(action?.kind, EntryActionKind.editClaim);
      expect(action?.claimId, 'abc-123');
    });

    test('非法 / 空白 / 缺 id → null', () {
      expect(parseEntryAction('edit_claim:'), isNull);
      expect(parseEntryAction(''), isNull);
      expect(parseEntryAction('   '), isNull);
      expect(parseEntryAction('open_home'), isNull);
    });

    test('允许前后空白', () {
      expect(parseEntryAction('  open_mine  ')?.kind, EntryActionKind.openMine);
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
      EntryActionReceiver.emit('edit_claim:');
      EntryActionReceiver.emit('nope');
      expect(EntryActionReceiver.takePending(), isEmpty);
    });
  });
}
