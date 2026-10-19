// 二维码解析器单元测试：覆盖携程 etrip 格式与失败回退。
// 解析逻辑在 Dart 侧完成。
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/core/utils/qr_parser.dart';
import 'package:snap_claim_android/features/invoice/models/record.dart';

void main() {
  group('etrip 规则', () {
    test('etripHotel 解析为酒店，末尾为金额', () async {
      final r = await parseQrContent(
        'etripHotel://870667,闫兴,2485235576652567552,3261.0',
      );
      expect(r.record, isNotNull);
      expect(r.record!.category, RecordCategory.hotel);
      expect(r.record!.title, '闫兴');
      expect(r.record!.subtitle, '订单号 2485235576652567552');
      expect(r.record!.amount, 3261.0);
    });

    test('etrip 解析为飞机，金额在第三位', () async {
      final r = await parseQrContent('etrip://2811544509,赵文俊,577.0,2317.0');
      expect(r.record, isNotNull);
      expect(r.record!.category, RecordCategory.flight);
      expect(r.record!.title, '赵文俊');
      expect(r.record!.subtitle, '订单号 2811544509');
      expect(r.record!.amount, 577.0);
    });

    test('etripCar 解析为用车', () async {
      final r = await parseQrContent(
        'etripCar://870667,闫兴,2485235576652567552,86.0',
      );
      expect(r.record, isNotNull);
      expect(r.record!.category, RecordCategory.car);
      expect(r.record!.amount, 86.0);
    });

    test('未知前缀回退为原始内容', () async {
      final raw = 'foo://870667,闫兴,2485235576652567552,86.0';
      final r = await parseQrContent(raw);
      expect(r.record, isNull);
      expect(r.raw, raw);
    });

    test('缺少金额字段时不解析', () async {
      final r = await parseQrContent('etripHotel://870667,闫兴');
      expect(r.record, isNull);
    });
  });

  test('无法识别时回退为纯文本', () async {
    final r = await parseQrContent('hello world');
    expect(r.record, isNull);
    expect(r.raw, 'hello world');
  });
}
