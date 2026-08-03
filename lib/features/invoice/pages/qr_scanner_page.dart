// 二维码扫描页：相机实时扫描 + 相册图片识别。
// 扫到内容后解析为报销明细并返回给调用方（编辑页追加 / 我的页预览）。
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/theme.dart';
import '../../../core/utils/qr_parser.dart';
import '../widgets/app_top_bar.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
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

  /// 解析内容并返回；同时给触感反馈。
  Future<void> _finish(String raw) async {
    if (_busy) return;
    setState(() => _busy = true);
    _controller.stop();
    final parsed = await parseQrContent(raw);
    if (!mounted) return;
    Navigator.of(context).pop(parsed);
  }

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
    return Scaffold(
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
                onTap: () => Navigator.of(context).pop(),
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
          if (_busy)
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
        ],
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
              child: AnimatedBuilder(
                animation: lineCtrl,
                builder: (context, _) {
                  final y = windowSide * lineCtrl.value;
                  return Stack(
                    children: [
                      Positioned(
                        top: y,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFF34D399),
                                const Color(0xFF34D399),
                                Colors.transparent,
                              ],
                              stops: [0, 0.2, 0.8, 1],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF34D399)
                                    .withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
        // 左上
        Positioned(
          left: 0,
          top: 0,
          child: Container(
            width: len,
            height: thick,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: Container(
            width: thick,
            height: len,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
              ),
            ),
          ),
        ),
        // 右上
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: len,
            height: thick,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: thick,
            height: len,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
              ),
            ),
          ),
        ),
        // 左下
        Positioned(
          left: 0,
          bottom: 0,
          child: Container(
            width: len,
            height: thick,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(4),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          bottom: 0,
          child: Container(
            width: thick,
            height: len,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(4),
              ),
            ),
          ),
        ),
        // 右下
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: len,
            height: thick,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(4),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: thick,
            height: len,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(4),
              ),
            ),
          ),
        ),
      ],
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
    return GestureDetector(
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
