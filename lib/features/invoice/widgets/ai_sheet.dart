// AI 情况说明底部弹层：状态机 + 流式生成 + 复制。
// 关闭即清空，不留本地历史。生成中可「停止」（关闭 http client）。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../app/theme.dart';
import '../../../core/ai/ai_client.dart';
import '../../../core/ai/ai_settings.dart';
import '../../settings/pages/ai_settings_page.dart';
import 'ai_mascot.dart';
import 'press_scale.dart';

enum _AiSheetStatus { loading, unconfigured, idle, generating, success, error }

/// 打开 AI 情况说明弹层。
void showAiSituationSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _AiSituationSheet(),
  );
}

class _AiSituationSheet extends StatefulWidget {
  const _AiSituationSheet();

  @override
  State<_AiSituationSheet> createState() => _AiSituationSheetState();
}

class _AiSituationSheetState extends State<_AiSituationSheet> {
  final _reasonCtrl = TextEditingController();
  final _focus = FocusNode();
  final _resultScrollCtrl = ScrollController();

  _AiSheetStatus _status = _AiSheetStatus.loading;
  AiSettings? _settings;
  String _output = '';
  String? _error;
  http.Client? _client;
  bool _stopping = false;
  bool _inFlight = false;
  DateTime? _rateLimitedUntil;
  bool _copied = false;
  Timer? _copiedResetTimer;

  @override
  void initState() {
    super.initState();
    _reloadSettings();
  }

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    _client?.close();
    _reasonCtrl.dispose();
    _focus.dispose();
    _resultScrollCtrl.dispose();
    super.dispose();
  }

  void _resetAfterStop() {
    _status = _AiSheetStatus.idle;
    _output = '';
    _error = null;
    _stopping = false;
  }

  Future<void> _reloadSettings() async {
    AiSettings s;
    try {
      s = await loadAiSettings();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _settings = null;
        _status = _AiSheetStatus.unconfigured;
        _error = null;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _settings = s;
      _status =
          s.isConfigured ? _AiSheetStatus.idle : _AiSheetStatus.unconfigured;
      _error = null;
    });
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiSettingsPage()),
    );
    if (!mounted) return;
    await _reloadSettings();
  }

  void _stop() {
    final client = _client;
    if (client == null) return;
    setState(() => _stopping = true);
    client.close();
  }

  Future<void> _generate() async {
    if (_inFlight) return;
    final until = _rateLimitedUntil;
    if (until != null) {
      final left = until.difference(DateTime.now()).inSeconds;
      if (left > 0) {
        setState(() {
          _status = _AiSheetStatus.error;
          _error = '刚才触发了并发限流，请约 $left 秒后再试。\n'
              '限流按账户并发计算，同一 Key 在其它设备/工具里也会占并发。';
        });
        return;
      }
      _rateLimitedUntil = null;
    }

    final settings = _settings;
    if (settings == null || !settings.isConfigured) {
      setState(() => _status = _AiSheetStatus.unconfigured);
      return;
    }
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) return;

    _client?.close();
    final client = http.Client();
    _client = client;
    _inFlight = true;

    setState(() {
      _status = _AiSheetStatus.generating;
      _output = '';
      _error = null;
      _stopping = false;
    });

    try {
      final text = await streamAiSituationExplanation(
        settings: settings,
        reason: reason,
        client: client,
        onContent: (delta) {
          if (!mounted) return;
          setState(() => _output += delta);
        },
      );
      if (!mounted) return;
      if (_stopping) {
        setState(_resetAfterStop);
        return;
      }
      setState(() {
        _output = text.trim();
        _status = _AiSheetStatus.success;
        _copied = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_stopping) {
        setState(_resetAfterStop);
        return;
      }
      final msg = e is AiGenerateException ? e.message : '生成失败：$e';
      if (msg.contains('429') || msg.contains('限流') || msg.contains('1302')) {
        _rateLimitedUntil = DateTime.now().add(const Duration(seconds: 45));
      }
      setState(() {
        _status = _AiSheetStatus.error;
        _error = msg;
      });
    } finally {
      _inFlight = false;
      if (identical(_client, client)) {
        _client = null;
      }
    }
  }

  Future<void> _copyOutput() async {
    final text = _output.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _copied = true);
    _copiedResetTimer?.cancel();
    _copiedResetTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }

  Widget _buildCopyButton({required bool reduceMotion}) {
    final c = context.colors;
    final done = _copied;
    final duration =
        Duration(milliseconds: reduceMotion ? 0 : 220);

    Widget stateRow({
      required IconData icon,
      required String label,
      bool scaleIcon = false,
    }) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: scaleIcon && !done ? 0.72 : 1.0,
            duration: duration,
            curve: Curves.easeOutBack,
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 15,
              height: 1.0,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: done ? '已复制成功' : '复制全文',
      child: PressScale(
        onTap: _copyOutput,
        pressedScale: 0.97,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: done
                ? Color.lerp(c.accent, Colors.white, 0.06)
                : c.accent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: done
                  ? c.accentLight
                  : c.accent.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: c.accent.withValues(alpha: done ? 0.28 : 0.2),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: duration,
                  opacity: done ? 0 : 1,
                  child:
                      stateRow(icon: Icons.copy_rounded, label: '复制全文'),
                ),
              ),
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: duration,
                  opacity: done ? 1 : 0,
                  child: stateRow(
                    icon: Icons.check_circle_rounded,
                    label: '复制成功',
                    scaleIcon: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDoc(String raw) => raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool danger = false,
  }) {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: danger
            ? FilledButton.styleFrom(backgroundColor: c.danger)
            : null,
        child: Text(label),
      ),
    );
  }

  /// 结果区：固定高度可滚动，带滚动条。
  Widget _resultBox({
    required String text,
    required double maxHeight,
    bool selectable = false,
  }) {
    final c = context.colors;
    final child = selectable
        ? SelectableText(
            text,
            style: TextStyle(fontSize: 13.5, height: 1.7, color: c.fg),
          )
        : Text(
            text,
            style: TextStyle(fontSize: 13, height: 1.65, color: c.fg),
          );

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 72, maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: c.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Scrollbar(
        controller: _resultScrollCtrl,
        thumbVisibility: true,
        radius: const Radius.circular(8),
        thickness: 3,
        child: SingleChildScrollView(
          controller: _resultScrollCtrl,
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBody() {
    final c = context.colors;

    switch (_status) {
      case _AiSheetStatus.loading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(color: c.accent)),
        );

      case _AiSheetStatus.unconfigured:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '尚未配置 API Key',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.fg,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '在「我的 → AI 设置」填入 API Key 后，即可在此生成正式情况说明。',
              style: TextStyle(fontSize: 13, color: c.fgMuted, height: 1.55),
            ),
            const SizedBox(height: 16),
            _primaryButton(label: '去设置', onPressed: _openSettings),
          ],
        );

      case _AiSheetStatus.idle:
      case _AiSheetStatus.generating:
      case _AiSheetStatus.success:
      case _AiSheetStatus.error:
        final generating = _status == _AiSheetStatus.generating;
        final canCopy =
            _status == _AiSheetStatus.success && _output.trim().isNotEmpty;
        final canGenerate =
            !generating && _reasonCtrl.text.trim().isNotEmpty;
        final isError = _status == _AiSheetStatus.error;
        final hasOutput = _output.isNotEmpty;
        final resultMax =
            (MediaQuery.of(context).size.height * 0.36).clamp(140.0, 280.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _reasonCtrl,
              focusNode: _focus,
              enabled: !generating,
              maxLines: 4,
              minLines: 3,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 14, color: c.fg, height: 1.5),
              decoration: InputDecoration(
                hintText: '写出差原因，以及这次行程费用出了什么问题',
                hintStyle: TextStyle(fontSize: 13, color: c.fgSoft),
                filled: true,
                fillColor: c.bgSecondary,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.accent, width: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (generating)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hasOutput ? '正在撰写情况说明…' : '正在连接模型，请稍候…',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (generating && hasOutput || (!generating && (hasOutput || isError))) ...[
              if (isError)
                _resultBox(
                  text: _error ?? '生成失败',
                  maxHeight: resultMax,
                )
              else
                _resultBox(
                  text: _formatDoc(_output),
                  maxHeight: resultMax,
                  selectable: !generating,
                ),
              if (!generating && !isError) ...[
                const SizedBox(height: 6),
                Text(
                  '可在结果框内上下滑动查看完整内容。',
                  style: TextStyle(fontSize: 11, color: c.fgSoft),
                ),
              ],
              const SizedBox(height: 10),
            ],
            if (canCopy)
              _buildCopyButton(
                reduceMotion: MediaQuery.maybeOf(context)?.disableAnimations ??
                    false,
              )
            else if (generating)
              _primaryButton(label: '停止', onPressed: _stop, danger: true)
            else if (isError)
              _primaryButton(label: '重试', onPressed: _generate)
            else
              _primaryButton(
                label: '生成情况说明',
                onPressed: canGenerate ? _generate : null,
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final media = MediaQuery.of(context);
    final bodyMaxHeight = (media.size.height * 0.72).clamp(360.0, 640.0);

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + media.viewInsets.bottom),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: bodyMaxHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AIMascot(awake: true, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI 情况说明',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.fg,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _settings?.isConfigured == true
                                ? '模型 ${_settings!.model}'
                                : '配置后可生成正式公文',
                            style:
                                TextStyle(fontSize: 12, color: c.fgMuted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _openSettings,
                      child: Text(
                        '设置',
                        style: TextStyle(fontSize: 13, color: c.accent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildBody(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
