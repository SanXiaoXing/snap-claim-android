// AiSettings 读写：未写过 prefs 键时必须回落默认，不得抛错（首装会卡 loading）。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:snap_claim_android/core/ai/ai_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('首次安装：prefs 无 AI 键时 loadAiSettings 返回默认且不抛错', () async {
    final s = await loadAiSettings();
    expect(s.baseUrl, kAiDefaultBaseUrl);
    expect(s.model, kAiDefaultModel);
    expect(s.apiKey, '');
    expect(s.isConfigured, isFalse);
  });

  test('空白字符串也回落默认', () async {
    SharedPreferences.setMockInitialValues({
      'ai_base_url': '   ',
      'ai_model': '',
      'ai_api_key': '  sk-x  ',
    });
    final s = await loadAiSettings();
    expect(s.baseUrl, kAiDefaultBaseUrl);
    expect(s.model, kAiDefaultModel);
    expect(s.apiKey, 'sk-x');
    expect(s.isConfigured, isTrue);
  });

  test('保存后再读回', () async {
    await saveAiSettings(const AiSettings(
      baseUrl: 'https://example.com/v4',
      model: 'glm-4-air',
      apiKey: 'sk-test',
    ));
    final s = await loadAiSettings();
    expect(s.baseUrl, 'https://example.com/v4');
    expect(s.model, 'glm-4-air');
    expect(s.apiKey, 'sk-test');
  });
}
