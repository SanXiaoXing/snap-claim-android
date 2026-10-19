// 二维码内容解析：携程行程单 URI 转报销明细，其他内容保留原文。
import '../../features/invoice/models/record.dart';

/// 解析结果。
class QrParseResult {
  /// 成功解析出的明细；解析失败时为 null。
  final Record? record;

  /// 原始扫描内容（无论是否解析成功都会保留）。
  final String raw;

  const QrParseResult({this.record, required this.raw});
}

final _categoryMap = RecordCategory.values.asNameMap();

/// 将扫码内容解析为 [QrParseResult]。
Future<QrParseResult> parseQrContent(String content) async {
  final separator = content.indexOf('://');
  if (separator < 0) return QrParseResult(raw: content);
  final type = content.substring(0, separator).trim().toLowerCase();
  final category = switch (type) {
    'etriphotel' => 'hotel',
    'etripcar' => 'car',
    'etrip' => 'flight',
    _ => null,
  };
  final cat = _categoryMap[category];
  if (cat == null) return QrParseResult(raw: content);
  final fields = content.substring(separator + 3).split(',');
  if (fields.length < 4) return QrParseResult(raw: content);
  final title = fields[1].trim();
  final amount = double.tryParse(fields[category == 'flight' ? 2 : 3].trim());
  if (title.isEmpty || amount == null) return QrParseResult(raw: content);
  final orderNo = fields[category == 'flight' ? 0 : 2].trim();
  return QrParseResult(
    record: Record(
      id: nextRecordId(),
      category: cat,
      title: title,
      subtitle: orderNo.isEmpty ? '' : '订单号 $orderNo',
      amount: amount,
    ),
    raw: content.trim(),
  );
}
