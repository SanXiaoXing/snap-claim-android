// 二维码内容解析 —— 通过 flutter_rust_bridge 调用 Rust 核心库 (snap_claim_core)。
// 真正的解析逻辑在 rust/src/api/qr.rs，
// Dart 侧仅做分类字符串 → RecordCategory 映射并组装 Record。
import '../../src/rust/api/qr.dart' as rust;
import '../../features/invoice/models/record.dart';

/// 解析结果。
class QrParseResult {
  /// 成功解析出的明细；解析失败时为 null。
  final Record? record;

  /// 原始扫描内容（无论是否解析成功都会保留）。
  final String raw;

  /// 是否成功解析为明细。
  bool get ok => record != null;

  const QrParseResult({this.record, required this.raw});
}

final _categoryMap = {
  for (final c in RecordCategory.values) c.name: c,
};

/// 将扫码内容解析为 [QrParseResult]。
Future<QrParseResult> parseQrContent(String content) async {
  final r = await rust.parseQrContent(content: content);
  if (!r.ok || r.category == null || r.title == null) {
    return QrParseResult(raw: r.raw);
  }
  final cat = _categoryMap[r.category!];
  if (cat == null) return QrParseResult(raw: r.raw);
  return QrParseResult(
    record: Record(
      id: nextRecordId(),
      category: cat,
      title: r.title!,
      subtitle: r.subtitle ?? '',
      amount: r.amount ?? 0,
    ),
    raw: r.raw,
  );
}
