import 'package:flutter_test/flutter_test.dart';
import 'package:snap_claim_android/core/utils/ocr_parser.dart';

void main() {
  test('火车票保留类别、金额、日期和行程', () {
    final parsed = parseOcrText(
      '铁路电子客票\nG123 北京南→上海虹桥\n2026年8月3日\n二等座\n合计 ¥553.00',
    );
    expect(parsed.ok, isTrue);
    expect(parsed.category, 'train');
    expect(parsed.title, '北京南→上海虹桥');
    expect(parsed.subtitle, '火车票 2026-08-03');
    expect(parsed.amount, 553);
  });

  test('金额优先采用最后一个带货币符号的候选', () {
    final parsed = parseOcrText('北京西站\n西安北站\n票价:¥547.50\n发货请到95306');
    expect(parsed.title, '北京西站→西安北站');
    expect(parsed.amount, 547.5);
  });

  test('订单号与集中在文末的金额按出现顺序配对', () {
    final hints = extractAllOrderHints(
      'DC260712188429557710\nDC260712188390654303\n'
      'HO20260712171800782163\nx89.19 90.56 3339',
    );
    expect(hints.map((h) => h.orderType), ['car', 'car', 'hotel']);
    expect(hints.map((h) => h.amount), [89.19, 90.56, 3339]);
  });

  test('日期、时间和型号不误认成金额', () {
    final parsed = parseOcrText('2026-07-12 23:29:23 253-日常用车 1间12晚');
    expect(parsed.amount, isNull);
  });
}
