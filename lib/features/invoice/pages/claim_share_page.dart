// 报销单分享页：渲染 [ShareCard] 并调起系统分享面板发送图片。
//
// 渲染策略：
// - [ShareCard] 用 [RepaintBoundary] 包裹，拿到 GlobalKey 后可在需要时
//   调 boundary.toImage() 将卡片光栅化为 PNG；
// - 屏幕上的预览是正常大小的卡片，分享时按 3x 像素密度（pixelRatio）
//   抓图，保证图片清晰。
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../models/claim.dart';
import '../widgets/share_card.dart';

class ClaimSharePage extends StatefulWidget {
  final Claim claim;

  const ClaimSharePage({super.key, required this.claim});

  @override
  State<ClaimSharePage> createState() => _ClaimSharePageState();
}

class _ClaimSharePageState extends State<ClaimSharePage> {
  /// 抓图用：RepaintBoundary 的全局 key，必须在 build 中挂在卡片外层。
  final GlobalKey _boundaryKey = GlobalKey();

  /// 分享进行中：禁用按钮 + 显示 loading，避免重复触发。
  bool _busy = false;

  /// 抓图分辨率倍数。3x 在手机分享场景下足够清晰，文件体积也合适。
  static const double _pixelRatio = 3.0;

  /// 将 [ShareCard] 光栅化为 PNG 字节数组。
  ///
  /// - `pixelRatio` 控制清晰度（高 = 文件大但锐利）；
  /// - 边界不可见时返回 null（用户尚未进入页面就分享等异常路径）。
  Future<Uint8List?> _capturePng() async {
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  /// 触发系统分享：抓图 → 写临时文件 → Share.shareXFiles。
  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) {
        _toast('分享失败：未找到预览卡片');
        return;
      }
      // 临时目录：`getTemporaryDirectory` 由 path_provider 提供。
      final dir = await getTemporaryDirectory();
      final file = await File(
        '${dir.path}/snapclaim_${widget.claim.id}.png',
      ).writeAsBytes(bytes, flush: true);
      // share_plus 10.x 使用静态 Share.shareXFiles。
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '${widget.claim.name} · ${_amountText()}',
        subject: 'SnapClaim 报销单',
      );
    } catch (e) {
      _toast('分享失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 纯文本分享：金额一行 + 名称一行，作为图片分享的兜底。
  Future<void> _shareAsText() async {
    if (_busy) return;
    final summary = StringBuffer()
      ..writeln('【${widget.claim.name}】')
      ..writeln('报销总额：${_amountText()}')
      ..writeln('明细数：${widget.claim.records.length}')
      ..writeln('—— 由 SnapClaim 生成');
    await Share.share(summary.toString(), subject: 'SnapClaim 报销单');
  }

  String _amountText() {
    final t = widget.claim.total;
    return '¥${t.toStringAsFixed(2)}';
  }

  void _toast(String msg) {
    showAppSnack(context, msg, ms: 1500);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bgSecondary,
      appBar: AppBar(
        backgroundColor: c.bgSecondary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: c.fg),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '分享报销单',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: c.fg,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Center(
                // 卡片宽度固定 360，但屏幕更宽时也保持自然大小不拉伸。
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: ShareCard(claim: widget.claim),
                ),
              ),
            ),
          ),
          _bottomBar(c),
        ],
      ),
    );
  }

  // 底部操作栏：纯文本分享 + 图片分享（主操作）。
  Widget _bottomBar(AppColorScheme c) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _shareAsText,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.fg,
                side: BorderSide(color: c.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                '文本分享',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.fgMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _busy ? null : _share,
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.ios_share, size: 18, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          '分享图片',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
