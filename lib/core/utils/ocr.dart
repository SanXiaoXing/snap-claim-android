// OCR 识别服务：拍照 / 相册选图 → ML Kit 文字识别 → Rust 结构化解析为明细候选。
// 仅 Android 目标；ML Kit 首次识别某语言脚本时会自动下载对应模型（需联网一次）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../features/invoice/models/record.dart';
import '../../features/invoice/widgets/scan_line.dart';
import '../../src/rust/api/ocr.dart' as rust;

/// OCR 识别结果。
class OcrResult {
  /// 结构化解析出的全部明细候选（订单列表截图可能含多张订单，每张一条；
  /// 单张票据解析最多一条）。供预览确认后追加。
  final List<Record> records;

  /// OCR 识别出的原始文本；为空串表示图中未识别到文字。
  final String raw;

  /// 识别失败原因；非 null 时表示识别引擎异常（此时 [raw] 为空串）。
  final String? error;

  const OcrResult({required this.records, required this.raw, this.error});
}

final _categoryMap = RecordCategory.values.asNameMap();

/// 弹底部选择（拍照 / 相册），取图后走 OCR 识别 + 结构化解析。
///
/// 返回 null 表示用户取消；非 null 时：
///   - [OcrResult.error] 非空 = 识别引擎异常（已给出可提示的原因）
///   - [OcrResult.raw] 为空串 = 图中未识别到文字
///   - 否则为识别文本与解析出的候选明细。
Future<OcrResult?> pickImageAndOcr(BuildContext context) async {
  final source = await _pickSource(context);
  if (source == null) return null;

  final picker = ImagePicker();
  final XFile? xfile;
  try {
    xfile = await picker.pickImage(source: source);
  } catch (_) {
    return null;
  }
  if (xfile == null) return null;
  if (!context.mounted) return null;

  return recognizeImageFile(context, xfile.path);
}

/// 对指定图片文件执行 OCR 识别 + 结构化解析。
///
/// 与 [pickImageAndOcr] 共享识别流程与进度弹窗，供系统分享面板
/// 直达（分享图片 → OCR）等已有本地文件路径的场景复用。
/// 返回语义同 [pickImageAndOcr]。
Future<OcrResult?> recognizeImageFile(BuildContext context, String path) async {
  // OCR 识别需数秒（首次使用还需联网下载识别模型），
  // 弹扫描动画提示用户正在识别，避免误以为卡死。
  if (!context.mounted) return null;
  _showOcrLoading(context, path);
  // 等待进度弹窗完成弹出后再开始识别，避免识别过快时弹窗刚弹出就被关闭。
  await Future<void>.delayed(const Duration(milliseconds: 120));
  try {
    return await _runRecognition(path);
  } finally {
    // 无论识别成败都关闭进度弹窗。
    if (context.mounted) {
      _hideOcrLoading(context);
    }
  }
}

/// 识别图片文字 + Rust 结构化解析，返回 [OcrResult]。
Future<OcrResult> _runRecognition(String path) async {
  final text = await _recognize(path);
  if (text == null) {
    return const OcrResult(
      records: [],
      error: '识别引擎初始化失败，请检查网络后重试（首次使用需联网下载识别模型）',
      raw: '',
    );
  }
  if (text.trim().isEmpty) return const OcrResult(records: [], raw: '');

  // 订单列表截图可能含多张订单：按订单号切分逐段抽取；
  // 未命中订单号再走单张票据的启发式解析。
  List<Record> records;
  try {
    final hints = await rust.extractAllOrderHints(text: text);
    records = hints.isNotEmpty
        ? [for (final h in hints) ?_recordFromHint(h)]
        : [?await _recordFromOcrText(text)];
  } catch (e) {
    debugPrint('OCR 文本解析失败: $e');
    records = const [];
  }
  // 调试：打印解析出的明细，便于核对识别与解析结果。
  if (records.isNotEmpty) {
    debugPrint('OCR 解析明细: ${records.map((r) => '${r.category.label} ${r.title} ¥${r.amount}').join(' | ')}');
  } else {
    debugPrint('OCR 未解析出明细（原文见上方识别文本）');
  }
  return OcrResult(records: records, raw: text);
}

/// 订单截图 → Record（title=订单号，subtitle=类型标签）。
Record? _recordFromHint(rust.ImageHint hint) {
  final cat = _categoryMap[hint.orderType];
  if (cat == null) return null;
  return Record(
    id: nextRecordId(),
    category: cat,
    title: hint.orderId,
    subtitle: cat.label,
    amount: hint.amount ?? 0,
  );
}

/// 单张票据文本 → Record（复用 Rust 启发式解析）。
Future<Record?> _recordFromOcrText(String text) async {
  final parsed = await rust.parseOcrText(text: text);
  final cat = parsed.category == null ? null : _categoryMap[parsed.category!];
  if (!parsed.ok || cat == null || parsed.title == null) return null;
  return Record(
    id: nextRecordId(),
    category: cat,
    title: parsed.title!,
    subtitle: parsed.subtitle ?? '',
    amount: parsed.amount ?? 0,
  );
}

/// 底部选择：拍照 / 从相册选择。
Future<ImageSource?> _pickSource(BuildContext context) async {
  final c = context.colors;
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.photo_camera_outlined, color: c.fg),
            title: Text('拍照识别',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fg)),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library_outlined, color: c.fg),
            title: Text('从相册选择',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fg)),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// 弹出 OCR 识别进度动画（图片扫描线 + 转圈），提示用户正在识别内容。
void _showOcrLoading(BuildContext context, String imagePath) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OcrLoadingDialog(imagePath: imagePath),
  );
}

/// 关闭进度弹窗；弹窗不可手动关闭，只会由识别流程结束时调用。
void _hideOcrLoading(BuildContext context) {
  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}

/// OCR 识别进度弹窗：展示待识别图片 + 自上而下扫描线动画，
/// 让用户直观看到正在识别内容（首次使用还需联网下载模型，等待更久）。
class _OcrLoadingDialog extends StatefulWidget {
  final String imagePath;

  const _OcrLoadingDialog({required this.imagePath});

  @override
  State<_OcrLoadingDialog> createState() => _OcrLoadingDialogState();
}

class _OcrLoadingDialogState extends State<_OcrLoadingDialog>
    with SingleTickerProviderStateMixin {
  /// 扫描线循环动画。
  late final AnimationController _scan =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
        ..repeat();

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopScope(
      // 识别期间禁止返回键关闭，否则进度弹窗与识别流程的状态会错乱。
      canPop: false,
      child: Dialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(widget.imagePath), fit: BoxFit.cover),
                      AnimatedBuilder(
                        animation: _scan,
                        builder: (context, _) {
                          final t = _scan.value; // 0→1 循环扫描
                          return Stack(
                            children: [
                              // 已扫描区域遮罩渐隐，强化“自上而下读取”的视觉反馈。
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 180 * t,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        c.accent.withValues(alpha: 0.28),
                                        c.accent.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // 扫描线：细高亮线 + 柔光，光扫过票据的感觉。
                              ScanLine(
                                progress: _scan,
                                trackHeight: 180,
                                color: c.accent,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '正在识别票据内容…',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.fg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '首次使用需联网下载识别模型，请稍候',
                style: TextStyle(fontSize: 11, color: c.fgSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 用 ML Kit 中文脚本识别图片中的文字。
/// 返回 null 表示识别引擎异常（如设备无 Google Play 服务、模型下载失败、
/// 图片路径无效等），由调用方给出可操作提示，不让应用退出。
Future<String?> _recognize(String path) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
  try {
    final input = InputImage.fromFilePath(path);
    final result = await recognizer.processImage(input);
    // 按视觉坐标重排，避免 OCR 输出顺序与截图顺序不一致导致订单/金额错配。
    final text = reorderOcrText(result);
    // 调试：将识别文本完整打印到终端，便于核对解析规则。
    debugPrint('══════ OCR 识别文本 ══════\n$text\n══════════════════════');
    return text;
  } catch (e) {
    debugPrint('ML Kit 识别失败: $e');
    return null;
  } finally {
    // close 失败不应掩盖识别结果或导致异常逃逸。
    try {
      await recognizer.close();
    } catch (_) {}
  }
}

/// 按视觉坐标（自上而下、自左而右）重排 OCR 文本：
/// TextBlock 按 top 排序 → 块内 TextLine 按 top 排序 →
/// 行内 TextElement 按 left 排序并以空格连接。
/// OCR 的输出顺序不一定等于截图顺序（金额常被排到文末），
/// 用 boundingBox 恢复真实阅读顺序后再交给 Rust 解析。
String reorderOcrText(RecognizedText result) {
  final blocks = [...result.blocks]
    ..sort((a, b) => _compareRect(a.boundingBox, b.boundingBox));
  final buffer = StringBuffer();
  for (var bi = 0; bi < blocks.length; bi++) {
    final lines = [...blocks[bi].lines]
      ..sort((a, b) => _compareRect(a.boundingBox, b.boundingBox));
    for (var li = 0; li < lines.length; li++) {
      final elements = [...lines[li].elements]
        ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      buffer.write(
        elements.isEmpty
            ? lines[li].text
            : elements
                .map((e) => e.text.trim())
                .where((s) => s.isNotEmpty)
                .join(' '),
      );
      if (li < lines.length - 1) buffer.write('\n');
    }
    if (bi < blocks.length - 1) buffer.write('\n');
  }
  return buffer.toString();
}

/// 先比 top（y 坐标）再比 left（x 坐标）。
int _compareRect(Rect a, Rect b) {
  final byTop = a.top.compareTo(b.top);
  return byTop != 0 ? byTop : a.left.compareTo(b.left);
}
