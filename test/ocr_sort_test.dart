// reorderOcrText 单元测试：验证按 boundingBox 坐标重排 OCR 文本，
// 以及重排后订单号↔金额的 Rust 端配对结果（模拟 OCR 输出顺序乱序的真实截图）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:snap_claim_android/core/utils/ocr.dart';
import 'package:snap_claim_android/src/rust/api/ocr.dart' as rust;
import 'package:snap_claim_android/src/rust/frb_generated.dart';

TextElement _el(String text, double left, double top) => TextElement(
      text: text,
      symbols: const [],
      boundingBox: Rect.fromLTWH(left, top, text.length * 10.0, 20),
      recognizedLanguages: const [],
      cornerPoints: const [],
      confidence: null,
      angle: null,
    );

TextLine _line(String text, List<TextElement> elements, double top) => TextLine(
      text: text,
      elements: elements,
      boundingBox: Rect.fromLTWH(0, top, 300, 20),
      recognizedLanguages: const [],
      cornerPoints: const [],
      confidence: null,
      angle: null,
    );

TextBlock _block(List<TextLine> lines, double top) => TextBlock(
      text: lines.map((l) => l.text).join('\n'),
      lines: lines,
      boundingBox: Rect.fromLTWH(0, top, 300, 150),
      recognizedLanguages: const [],
      cornerPoints: const [],
    );

void main() {
  setUpAll(() async => await RustLib.init());

  /// 三张订单卡片（DC 用车 / DC 用车 / HO 宾馆），每卡底部有金额行。
  /// OCR 输出顺序故意打乱：blocks 逆序、卡 1 内行乱序。
  RecognizedText buildRecognizedText() {
    final card1 = _block(
      [
        // 乱序：金额行在前、订单号行在后。
        _line('x89.19', [_el('x89.19', 0, 150)], 150),
        _line('253-日常用车', [_el('253-日常用车', 0, 120)], 120),
        _line('订单编号 DC260712188429557710',
            [_el('订单编号', 0, 100), _el('DC260712188429557710', 60, 100)], 100),
      ],
      100,
    );
    final card2 = _block(
      [
        _line('订单编号 DC260712188390654303',
            [_el('订单编号', 0, 200), _el('DC260712188390654303', 60, 200)], 200),
        _line('253-日常用车 -经济型', [_el('253-日常用车 -经济型', 0, 220)], 220),
        _line('90.56', [_el('90.56', 0, 250)], 250),
      ],
      200,
    );
    final card3 = _block(
      [
        _line('订单编号 HO20260712171800782163',
            [_el('订单编号', 0, 300), _el('HO20260712171800782163', 60, 300)], 300),
        _line('星程酒店(西安高新区锦业路)', [_el('星程酒店(西安高新区锦业路)', 0, 320)], 320),
        _line('3339', [_el('3339', 0, 350)], 350),
      ],
      300,
    );
    return RecognizedText(
      text: 'x89.19\n253-日常用车\n订单编号 DC260712188429557710\n'
          '订单编号 HO20260712171800782163\n星程酒店(西安高新区锦业路)\n3339\n'
          '订单编号 DC260712188390654303\n253-日常用车 -经济型\n90.56',
      blocks: [card3, card1, card2],
    );
  }

  group('reorderOcrText 坐标排序', () {
    test('按视觉顺序重排：卡 1 订单号行在金额行之前', () {
      final out = reorderOcrText(buildRecognizedText());
      expect(
        out,
        startsWith(
          '订单编号 DC260712188429557710\n253-日常用车\nx89.19\n订单编号 DC260712188390654303',
        ),
      );
      // 三个金额行保持在各自卡片段内。
      expect(out, contains('\nx89.19\n订单编号 DC260712188390654303'));
      expect(out, contains('\n3339'));
    });

    test('空 blocks 返回空串', () {
      expect(
        reorderOcrText(RecognizedText(text: '', blocks: const [])),
        isEmpty,
      );
    });
  });

  group('重排后 Rust 端到端配对', () {
    test('订单号与金额按坐标顺序正确配对', () async {
      final text = reorderOcrText(buildRecognizedText());
      final hints = await rust.extractAllOrderHints(text: text);
      expect(hints.length, 3);
      expect(hints[0].orderType, 'car');
      expect(hints[0].orderId, 'DC260712188429557710');
      expect(hints[0].amount, 89.19);
      expect(hints[1].orderType, 'car');
      expect(hints[1].orderId, 'DC260712188390654303');
      expect(hints[1].amount, 90.56);
      expect(hints[2].orderType, 'hotel');
      expect(hints[2].orderId, 'HO20260712171800782163');
      expect(hints[2].amount, 3339.0);
    });
  });
}
