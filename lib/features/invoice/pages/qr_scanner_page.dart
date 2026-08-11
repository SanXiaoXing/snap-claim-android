// 二维码扫描页：相机实时扫描 + 相册图片识别。
// 扫到内容后解析为报销明细并返回给调用方（编辑页追加 / 我的页预览）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/qr_parser.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/press_scale.dart';
import '../widgets/scan_line.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  late final AnimationController _lineCtrl;
  bool _torchOn = false;
  bool _busy = false; // 防止重复处理。
  final List<QrParseResult> _results = []; // 本次扫码会话已识别的全部结果。
  QrParseResult? _pending; // 刚扫到、等待用户决定是否继续的结果。

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 减少动态：扫描线静置于中间，不做往复摆动。
    // 需在依赖就绪后读取 MediaQuery（initState 内不允许查询）。
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _lineCtrl.stop();
      _lineCtrl.value = 0.5;
    } else if (!_lineCtrl.isAnimating) {
      _lineCtrl.repeat(reverse: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用回到前台时恢复扫描，退到后台时暂停，释放相机资源。
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lineCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _finish(raw);
  }

  /// 解析内容并展示识别结果卡片；用户可继续扫描或完成后统一返回。
  Future<void> _finish(String raw) async {
    if (_busy) return;
    setState(() => _busy = true);
    _controller.stop();
    final parsed = await parseQrContent(raw);
    if (!mounted) return;
    // 视觉结果与触感同帧：确认感来自「识别成功」这个因果事件本身。
    HapticFeedback.lightImpact();
    setState(() {
      _results.add(parsed);
      _pending = parsed;
    });
  }

  /// 关闭结果卡片，恢复相机继续扫描下一张。
  void _resumeScan() {
    setState(() {
      _pending = null;
      _busy = false;
    });
    _controller.start();
  }

  /// 完成扫码，携带全部结果返回。
  void _done() => Navigator.of(context).pop(_results);

  /// 关闭页面：已有识别结果则带回，否则视为取消。
  void _close() => Navigator.of(context).pop(_results.isEmpty ? null : _results);

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.gallery);
      if (xfile == null) return;
      _toast('正在识别图片…');
      final capture = await _controller.analyzeImage(xfile.path);
      final barcodes = capture?.barcodes ?? const <Barcode>[];
      if (barcodes.isEmpty) {
        _toast('未在图片中识别到二维码');
        return;
      }
      final raw = barcodes.first.rawValue;
      if (raw == null || raw.isEmpty) {
        _toast('二维码内容为空');
        return;
      }
      _finish(raw);
    } on Exception catch (_) {
      _toast('图片识别失败，请重试');
    }
  }

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  void _toast(String msg) {
    showAppSnack(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 系统返回：有结果则带回，否则取消。
        _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 相机预览。
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
            // 扫描取景框 + 暗化遮罩 + 扫描线。
            _ScanOverlay(lineCtrl: _lineCtrl),
            // 顶部栏。
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppTopBar(
                title: '扫一扫',
                leading: AppIconButton(
                  icon: Icons.close,
                  onTap: _close,
                ),
              ),
            ),
            // 底部操作栏：相册 + 手电筒。
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionBtn(
                        icon: Icons.photo_outlined,
                        label: '相册',
                        onTap: _pickFromGallery,
                      ),
                      _ActionBtn(
                        icon: _torchOn
                            ? Icons.flash_on
                            : Icons.flash_off_outlined,
                        label: '手电筒',
                        active: _torchOn,
                        onTap: _toggleTorch,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 解析中的加载遮罩。
            if (_busy && _pending == null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    color: c.accent,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            // 识别结果卡片：可继续扫描下一张，或完成并统一返回。
            if (_pending != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 104,
                child: _ResultCard(
                  result: _pending!,
                  count: _results.length,
                  onContinue: _resumeScan,
                  onDone: _done,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 取景框遮罩：四周暗化、中间透明方框 + 上下扫动的扫描线。
class _ScanOverlay extends StatelessWidget {
  final AnimationController lineCtrl;
  const _ScanOverlay({required this.lineCtrl});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final windowSide = size.width * 0.70;
    final left = (size.width - windowSide) / 2;
    final top = (size.height - windowSide) / 2;
    final windowRect = Rect.fromLTWH(left, top, windowSide, windowSide);
    return IgnorePointer(
      child: Stack(
        children: [
          // 四周暗化遮罩，中间挖空。
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.55),
              BlendMode.srcOut,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          // 取景框描边。
          Positioned.fromRect(
            rect: windowRect,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // 四角装饰。
          Positioned.fromRect(
            rect: windowRect,
            child: const _Corners(),
          ),
          // 扫描线。
          Positioned.fromRect(
            rect: windowRect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  ScanLine(
                    progress: lineCtrl,
                    trackHeight: windowSide,
                    color: const Color(0xFF34D399),
                  ),
                ],
              ),
            ),
          ),
          // 提示文字。
          Positioned(
            top: top + windowSide + 28,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '将二维码放入框内即可自动扫描',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 取景框四角 L 形装饰。
class _Corners extends StatelessWidget {
  const _Corners();

  @override
  Widget build(BuildContext context) {
    const len = 22.0;
    const thick = 4.0;
    final color = const Color(0xFF34D399);
    return Stack(
      children: [
        for (final corner in const [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ]) ...[
          _bar(corner, len, thick, color, horizontal: true),
          _bar(corner, len, thick, color, horizontal: false),
        ],
      ],
    );
  }

  /// 单个角落的一条 L 边：横向 / 纵向各一条，贴住对应角落。
  Widget _bar(
    Alignment corner,
    double len,
    double thick,
    Color color, {
    required bool horizontal,
  }) {
    return Align(
      alignment: corner,
      child: Container(
        width: horizontal ? len : thick,
        height: horizontal ? thick : len,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: corner == Alignment.topLeft
                ? const Radius.circular(4)
                : Radius.zero,
            topRight: corner == Alignment.topRight
                ? const Radius.circular(4)
                : Radius.zero,
            bottomLeft: corner == Alignment.bottomLeft
                ? const Radius.circular(4)
                : Radius.zero,
            bottomRight: corner == Alignment.bottomRight
                ? const Radius.circular(4)
                : Radius.zero,
          ),
        ),
      ),
    );
  }
}

/// 识别结果卡片：展示刚扫到的明细/原文，可继续扫描或完成返回。
class _ResultCard extends StatelessWidget {
  final QrParseResult result;
  final int count;
  final VoidCallback onContinue;
  final VoidCallback onDone;

  const _ResultCard({
    required this.result,
    required this.count,
    required this.onContinue,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final rec = result.record;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF34D399), size: 18),
              const SizedBox(width: 6),
              const Text(
                '识别成功',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '已识别 $count 张',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rec != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: rec.category.badgeBg(Brightness.dark),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: rec.category.badgeBorder(Brightness.dark),
                    ),
                  ),
                  child: Text(
                    rec.category.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: rec.category.badgeFg(Brightness.dark),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rec.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (rec.subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                rec.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              fmtMoney(rec.amount),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF34D399),
              ),
            ),
          ] else ...[
            Text(
              '未识别到票据明细，将展示原始内容',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 110),
              child: SingleChildScrollView(
                child: Text(
                  result.raw,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PressScale(
                  onTap: onContinue,
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      '继续扫描',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PressScale(
                  onTap: onDone,
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34D399),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Text(
                      '完成并返回',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF06251C),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 底部圆形操作按钮。
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: active
                    ? const Color(0xFF34D399)
                    : Colors.white.withValues(alpha: 0.4),
                width: active ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: active
                  ? const Color(0xFF34D399)
                  : Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
