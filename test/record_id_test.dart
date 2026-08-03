// nextRecordId 单元测试：验证批量创建明细（如 OCR 多订单）时 id 唯一，
// 避免同一毫秒创建的多条记录 id 相同导致按 id 删除误删全部。
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/features/invoice/models/record.dart';

void main() {
  test('连续批量生成 100 个 id 全部唯一', () {
    final ids = {for (var i = 0; i < 100; i++) nextRecordId()};
    expect(ids.length, 100);
  });

  test('id 包含时间戳与递增序号，格式稳定', () {
    final id = nextRecordId();
    // 形如 <毫秒时间戳>-<序号>。
    expect(RegExp(r'^\d+-\d+$').hasMatch(id), isTrue);
  });
}
