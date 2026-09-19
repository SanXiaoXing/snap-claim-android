// AI 设置页：API Key + 模型（预设底部选择 / 自定义）。本机 SharedPreferences。
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/ai/ai_settings.dart';
import '../../invoice/widgets/app_top_bar.dart';

/// 开放平台 API Key 申请页。
const String kApiKeyPortalUrl = 'https://bigmodel.cn/apikey/platform';

/// 模型选择里的「自定义」占位 id。
const String kAiModelCustomId = '__custom__';

/// (模型 id, 说明)。
const List<(String, String)> _kModelPresets = [
  ('glm-4.7-flash', '默认 · 推荐'),
  ('glm-4-flash-250414', '更快 · 更省额度'),
];

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final _apiKeyCtrl = TextEditingController();
  final _customModelCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _obscureKey = true;

  String _baseUrl = kAiDefaultBaseUrl;

  /// 预设模型 id，或 [kAiModelCustomId]。
  String _modelSelection = kAiDefaultModel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _customModelCtrl.dispose();
    super.dispose();
  }

  bool get _isCustomModel => _modelSelection == kAiModelCustomId;

  bool _isPreset(String id) => _kModelPresets.any((p) => p.$1 == id);

  /// (主标题, 副标题)。
  (String, String) _selectionMeta(String current) {
    if (current == kAiModelCustomId) {
      final custom = _customModelCtrl.text.trim();
      return ('自定义模型', custom.isEmpty ? '填写智谱其他模型 id' : custom);
    }
    for (final p in _kModelPresets) {
      if (p.$1 == current) return p;
    }
    return (current, '智谱模型');
  }

  void _applySavedModel(String model) {
    final id = model.trim().isEmpty ? kAiDefaultModel : model.trim();
    if (_isPreset(id)) {
      _modelSelection = id;
      _customModelCtrl.text = '';
    } else {
      _modelSelection = kAiModelCustomId;
      _customModelCtrl.text = id;
    }
  }

  void _onModelSelected(String value) {
    setState(() {
      _modelSelection = value;
      if (value != kAiModelCustomId) {
        _customModelCtrl.text = '';
      } else if (_customModelCtrl.text.trim().isEmpty) {
        _customModelCtrl.text = kAiDefaultModel;
      }
    });
  }

  Future<void> _load() async {
    final s = await loadAiSettings();
    if (!mounted) return;
    setState(() {
      _apiKeyCtrl.text = s.apiKey;
      _baseUrl = s.baseUrl;
      _applySavedModel(s.model);
      _loading = false;
    });
  }

  Future<void> _save() async {
    final custom = _customModelCtrl.text.trim();
    if (_isCustomModel && custom.isEmpty) {
      showAppSnack(context, '请填写自定义模型名称', background: context.colors.danger);
      return;
    }
    setState(() => _saving = true);
    await saveAiSettings(AiSettings(
      baseUrl: _baseUrl,
      model: _isCustomModel ? (custom.isEmpty ? kAiDefaultModel : custom) : _modelSelection,
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
      if (!ok && mounted) showAppSnack(context, '无法打开：$kApiKeyPortalUrl');
    } catch (_) {
      if (mounted) showAppSnack(context, '无法打开：$kApiKeyPortalUrl');
    }
  }

  InputDecoration _inputDeco(String hint, {Widget? suffix}) {
    final c = context.colors;
    final base = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c.border),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14, color: c.fgSoft),
      filled: true,
      fillColor: c.bgSecondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: base,
      enabledBorder: base,
      focusedBorder: base.copyWith(
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
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.fg),
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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.fg),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Future<void> _openModelSheet() async {
    final current = _isPreset(_modelSelection) || _modelSelection == kAiModelCustomId
        ? _modelSelection
        : kAiModelCustomId;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final sc = sheetContext.colors;
        Widget tile(String value, String title, String subtitle) {
          final on = current == value;
          return ListTile(
            title: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: sc.fg,
              ),
            ),
            subtitle: subtitle.isEmpty
                ? null
                : Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: on ? sc.accent : sc.fgMuted,
                    ),
                  ),
            selected: on,
            selectedTileColor: sc.accentBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            trailing: on ? Icon(Icons.check_circle, size: 20, color: sc.accent) : null,
            onTap: () => Navigator.of(sheetContext).pop(value),
          );
        }

        return Material(
          color: sc.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16, top: 4),
                      decoration: BoxDecoration(
                        color: sc.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text(
                      '选择模型',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: sc.fg),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      '可选预设，或填写智谱其他模型 id',
                      style: TextStyle(fontSize: 12, color: sc.fgMuted),
                    ),
                  ),
                  for (final p in _kModelPresets) tile(p.$1, p.$1, p.$2),
                  Divider(height: 1, color: sc.border),
                  tile(kAiModelCustomId, '自定义（智谱其他模型）', '手动填写模型 id'),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) _onModelSelected(selected);
  }

  Widget _modelPicker() {
    final c = context.colors;
    final current = _isPreset(_modelSelection) || _modelSelection == kAiModelCustomId
        ? _modelSelection
        : kAiModelCustomId;
    final meta = _selectionMeta(current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: '选择模型，当前 ${meta.$1}',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _openModelSheet,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.bgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta.$1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.fg,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meta.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.fgMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.expand_more, size: 22, color: c.fgMuted),
                ],
              ),
            ),
          ),
        ),
        if (_isCustomModel) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customModelCtrl,
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() {}),
            style: TextStyle(fontSize: 14, color: c.fg),
            decoration: _inputDeco('例如 glm-4-air'),
          ),
          const SizedBox(height: 6),
          Text(
            '填写智谱开放平台里的完整模型 id，需与接口一致。',
            style: TextStyle(fontSize: 11, color: c.fgSoft, height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _portalButton() {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openApiKeyPortal,
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('去申请 API Key'),
        style: OutlinedButton.styleFrom(
          foregroundColor: c.accent,
          side: BorderSide(color: c.accent.withValues(alpha: 0.45)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
                              style: TextStyle(fontSize: 12, color: c.fgMuted, height: 1.5),
                            ),
                            const SizedBox(height: 12),
                            _portalButton(),
                            const SizedBox(height: 8),
                            Text(
                              kApiKeyPortalUrl,
                              style: TextStyle(fontSize: 11, color: c.fgSoft),
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
                                    onPressed: () =>
                                        setState(() => _obscureKey = !_obscureKey),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _label('模型'),
                              _modelPicker(),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _saving ? null : _save,
                                  child: Text(_saving ? '保存中…' : '保存'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: _saving ? null : _clearKey,
                                  child: Text(
                                    '清除 API Key',
                                    style: TextStyle(fontSize: 13, color: c.danger),
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
