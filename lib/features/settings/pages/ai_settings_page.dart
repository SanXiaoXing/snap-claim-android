// AI 设置页：API Key + 模型。本机 SharedPreferences。
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/ai/ai_settings.dart';
import '../../invoice/widgets/app_top_bar.dart';

/// 开放平台 API Key 申请页。
const String kApiKeyPortalUrl = 'https://bigmodel.cn/apikey/platform';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final _apiKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();

  bool _loading = true;
  bool _obscureKey = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await loadAiSettings();
    if (!mounted) return;
    setState(() {
      _apiKeyCtrl.text = s.apiKey;
      _modelCtrl.text = s.model;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final current = await loadAiSettings();
    await saveAiSettings(AiSettings(
      baseUrl: current.baseUrl,
      model: _modelCtrl.text.trim().isEmpty
          ? kAiDefaultModel
          : _modelCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    showAppSnack(context, 'AI 配置已保存', background: context.colors.accent);
  }

  Future<void> _clearKey() async {
    await clearAiApiKey();
    if (!mounted) return;
    setState(() => _apiKeyCtrl.text = '');
    showAppSnack(context, '已清除 API Key');
  }

  Future<void> _openApiKeyPortal() async {
    try {
      final ok = await launchUrl(
        Uri.parse(kApiKeyPortalUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        showAppSnack(context, '无法打开：$kApiKeyPortalUrl');
      }
    } catch (_) {
      if (mounted) showAppSnack(context, '无法打开：$kApiKeyPortalUrl');
    }
  }

  InputDecoration _inputDeco(String hint, {Widget? suffix}) {
    final c = context.colors;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14, color: c.fgSoft),
      filled: true,
      fillColor: c.bgSecondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      suffixIcon: suffix,
    );
  }

  Widget _label(String text) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: c.fg,
        ),
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.fg,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          AppTopBar(
            leading: AppIconButton(
              icon: Icons.chevron_left,
              onTap: () => Navigator.of(context).pop(),
            ),
            title: 'AI 设置',
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.accent))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _card(
                          title: '使用说明',
                          children: [
                            Text(
                              '配置 API Key 与模型后，即可在 AI 弹层中生成「情况说明」。'
                              '点「生成」时，输入内容会发送到你配置的模型接口；'
                              'App 不自建服务器、不代管 Key。Key 仅保存在本机，'
                              '并会随「导出数据」写入 .snapbackup。',
                              style: TextStyle(
                                fontSize: 12,
                                color: c.fgMuted,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _card(
                          title: '还没有 API Key？',
                          children: [
                            Text(
                              '可前往开放平台注册并创建 API Key，粘贴到下方即可。',
                              style: TextStyle(
                                fontSize: 12,
                                color: c.fgMuted,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _openApiKeyPortal,
                                icon:
                                    const Icon(Icons.open_in_new, size: 16),
                                label: const Text('去申请 API Key'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: c.accent,
                                  side: BorderSide(
                                    color: c.accent.withValues(alpha: 0.45),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              kApiKeyPortalUrl,
                              style:
                                  TextStyle(fontSize: 11, color: c.fgSoft),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: cardDecoration(c),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('API Key'),
                              TextField(
                                controller: _apiKeyCtrl,
                                obscureText: _obscureKey,
                                autocorrect: false,
                                enableSuggestions: false,
                                style: TextStyle(fontSize: 14, color: c.fg),
                                decoration: _inputDeco(
                                  '粘贴 API Key',
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscureKey
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: c.fgMuted,
                                    ),
                                    onPressed: () => setState(
                                        () => _obscureKey = !_obscureKey),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _label('模型'),
                              TextField(
                                controller: _modelCtrl,
                                style: TextStyle(fontSize: 14, color: c.fg),
                                decoration:
                                    _inputDeco('例如 $kAiDefaultModel'),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '默认 $kAiDefaultModel。',
                                style: TextStyle(
                                    fontSize: 11, color: c.fgSoft),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _saving ? null : _save,
                                  child:
                                      Text(_saving ? '保存中…' : '保存'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed:
                                      _saving ? null : _clearKey,
                                  child: Text(
                                    '清除 API Key',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: c.danger,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
