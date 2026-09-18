// AI 提示词 / URL / SSE / 错误映射单元测试（纯逻辑，不依赖网络）。
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/core/ai/ai_client.dart';
import 'package:snap_claim_android/core/ai/ai_prompt.dart';
import 'package:snap_claim_android/core/ai/ai_settings.dart';

void main() {
  test('系统提示词包含情况说明核心约束', () {
    expect(kAiSituationSystemPrompt, contains('情况说明'));
    expect(kAiSituationSystemPrompt, contains('本人'));
    expect(kAiSituationSystemPrompt, contains('特此说明'));
    expect(kAiSituationSystemPrompt, contains('说明人'));
  });

  test('用户消息包装自由文本原因', () {
    final msg = buildAiSituationUserMessage('  火车票买错日期  ');
    expect(msg, contains('火车票买错日期'));
  });

  test('messages = system + user', () {
    final messages = buildAiSituationMessages('原因');
    expect(messages.length, 2);
    expect(messages.first['role'], 'system');
    expect(messages.last['content'], contains('原因'));
  });

  test('chat/completions URL：完整接口、短 base 补全、防重复', () {
    expect(
      buildAiChatCompletionsUri(kAiDefaultBaseUrl).toString(),
      kAiDefaultBaseUrl,
    );
    expect(
      buildAiChatCompletionsUri('https://open.bigmodel.cn/api/paas/v4')
          .toString(),
      kAiDefaultBaseUrl,
    );
    expect(
      buildAiChatCompletionsUri('https://open.bigmodel.cn/api/paas/v4/')
          .toString(),
      kAiDefaultBaseUrl,
    );
    expect(
      buildAiChatCompletionsUri('   ').toString(),
      kAiDefaultBaseUrl,
    );
  });

  test('请求 body：默认模型 + stream + 关闭 thinking + 固定采样参数', () {
    final body = buildAiChatBody(
      model: 'glm-4.7-flash',
      reason: '高铁晚点改签',
    );
    expect(body['model'], 'glm-4.7-flash');
    expect(body['stream'], true);
    expect(body['thinking'], {'type': 'disabled'});
    expect(body['max_tokens'], kAiMaxTokens);
    expect(body['temperature'], kAiTemperature);
  });

  test('HTTP/业务错误映射带服务端原文', () {
    String bodyOf(String code, String msg) =>
        '{"error":{"code":"$code","message":"$msg"}}';

    expect(
      mapAiHttpError(401, bodyOf('1001', '未收到 Authentication')),
      contains('API Key'),
    );
    expect(
      mapAiHttpError(429, bodyOf('1302', '账户已达到速率限制')),
      contains('限流'),
    );
    expect(
      mapAiHttpError(429, bodyOf('1113', '账户已欠费')),
      contains('欠费'),
    );
    expect(mapAiHttpError(400, bodyOf('1211', '模型不存在')), contains('模型'));
    expect(mapAiHttpError(500, ''), contains('不可用'));
  });

  test('SSE 解析 content 与 reasoning_content', () {
    const chunk = '''
data: {"choices":[{"delta":{"reasoning_content":"思考"}}]}

data: {"choices":[{"delta":{"content":"关于"}}]}

data: {"choices":[{"delta":{"content":"行程"}}]}

data: [DONE]
''';
    final deltas = parseSseDeltas(chunk).toList();
    expect(deltas.map((e) => e.reasoning).join(), '思考');
    expect(deltas.map((e) => e.content).join(), '关于行程');
  });

  test('AiSettings 备份 JSON 往返与缺省', () {
    const s = AiSettings(
      baseUrl: kAiDefaultBaseUrl,
      model: 'glm-4-air',
      apiKey: 'sk-test',
    );
    final restored = AiSettings.fromBackupJson(s.toBackupJson());
    expect(restored.baseUrl, kAiDefaultBaseUrl);
    expect(restored.model, 'glm-4-air');
    expect(restored.isConfigured, isTrue);

    final empty = AiSettings.fromBackupJson(null);
    expect(empty.baseUrl, kAiDefaultBaseUrl);
    expect(empty.isConfigured, isFalse);
  });
}
