// AI 情况说明：本机配置（智谱 OpenAI 兼容口）。
// 存 SharedPreferences；可写入 .snapbackup manifest（见 core/backup）。
import 'package:shared_preferences/shared_preferences.dart';

/// 智谱官方完整对话补全接口（OpenAI 兼容）。
const String kAiDefaultBaseUrl =
    'https://open.bigmodel.cn/api/paas/v4/chat/completions';

/// 默认 / 示例模型（智谱 GLM-4 Flash 官方快照 id）。
const String kAiDefaultModel = 'glm-4-flash-250414';

const String _kBaseUrl = 'ai_base_url';
const String _kModel = 'ai_model';
const String _kApiKey = 'ai_api_key';

String _pick(String? value, String fallback) {
  final t = (value ?? '').trim();
  return t.isEmpty ? fallback : t;
}

/// 一组 AI 服务配置。
class AiSettings {
  final String baseUrl;
  final String model;
  final String apiKey;

  const AiSettings({
    required this.baseUrl,
    required this.model,
    required this.apiKey,
  });

  bool get isConfigured => apiKey.trim().isNotEmpty;

  /// 从备份 manifest 的 `ai` 对象还原；缺字段用默认值。
  factory AiSettings.fromBackupJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AiSettings(
        baseUrl: kAiDefaultBaseUrl,
        model: kAiDefaultModel,
        apiKey: '',
      );
    }
    return AiSettings(
      baseUrl: _pick(json['base_url'] as String?, kAiDefaultBaseUrl),
      model: _pick(json['model'] as String?, kAiDefaultModel),
      apiKey: (json['api_key'] as String?) ?? '',
    );
  }

  /// 写入备份 manifest 的结构。
  Map<String, dynamic> toBackupJson() => {
        'base_url': baseUrl,
        'model': model,
        'api_key': apiKey,
      };
}

/// 读本机 AI 配置；未写过 / 空白字段回落默认。
Future<AiSettings> loadAiSettings() async {
  final prefs = await SharedPreferences.getInstance();
  return AiSettings(
    baseUrl: _pick(prefs.getString(_kBaseUrl), kAiDefaultBaseUrl),
    model: _pick(prefs.getString(_kModel), kAiDefaultModel),
    apiKey: (prefs.getString(_kApiKey) ?? '').trim(),
  );
}

/// 持久化 AI 配置。
Future<void> saveAiSettings(AiSettings settings) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kBaseUrl, _pick(settings.baseUrl, kAiDefaultBaseUrl));
  await prefs.setString(_kModel, _pick(settings.model, kAiDefaultModel));
  await prefs.setString(_kApiKey, settings.apiKey.trim());
}

/// 清除 API Key（保留 baseUrl / model）。
Future<void> clearAiApiKey() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kApiKey, '');
}

/// 备份导入后，若 manifest 带了 ai 字段则写回本机；无则不动。
Future<void> applyAiSettingsFromBackup(Map<String, dynamic>? aiJson) async {
  if (aiJson == null) return;
  await saveAiSettings(AiSettings.fromBackupJson(aiJson));
}
