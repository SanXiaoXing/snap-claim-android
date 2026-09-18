// 智谱 GLM / OpenAI 兼容 chat/completions 的 SSE 流式客户端。
// 对齐官方文档：https://docs.bigmodel.cn/cn/guide/models/free/glm-4.7-flash
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_prompt.dart';
import 'ai_settings.dart';

/// 公文场景默认采样参数（调用方不覆盖）。
const int kAiMaxTokens = 2048;
const double kAiTemperature = 0.3;

/// 生成过程失败（可直接展示给用户的人话）。
class AiGenerateException implements Exception {
  final String message;
  const AiGenerateException(this.message);
  @override
  String toString() => message;
}

/// 拼出 chat/completions 完整 URL。
Uri buildAiChatCompletionsUri(String baseUrl) {
  var raw = baseUrl.trim();
  while (raw.endsWith('/')) {
    raw = raw.substring(0, raw.length - 1);
  }
  if (raw.isEmpty) return Uri.parse(kAiDefaultBaseUrl);
  if (raw.endsWith('/chat/completions')) return Uri.parse(raw);
  return Uri.parse('$raw/chat/completions');
}

({String code, String message}) _extractError(String body) {
  final raw = body.trim();
  if (raw.isEmpty) return (code: '', message: '');
  try {
    final json = jsonDecode(raw);
    if (json is Map) {
      final err = json['error'];
      final src = err is Map ? err : json;
      return (
        code: '${src['code'] ?? ''}'.trim(),
        message: '${src['message'] ?? src['msg'] ?? ''}'.trim(),
      );
    }
  } catch (_) {}
  final brief =
      raw.length > 160 ? raw.substring(0, 160) : raw.replaceAll(RegExp(r'\s+'), ' ');
  return (code: '', message: brief);
}

/// HTTP + 智谱业务错误 → 人话（含服务端原文）。
String mapAiHttpError(int statusCode, String body) {
  final parsed = _extractError(body);
  final code = parsed.code;
  final apiMsg = parsed.message;
  String withMsg(String base) =>
      apiMsg.isEmpty ? base : '$base（服务端：$apiMsg）';

  // Key / 鉴权类业务码。
  if (code == '1000' ||
      code == '1001' ||
      code == '1003' ||
      code == '1005' ||
      statusCode == 401 ||
      statusCode == 403) {
    return withMsg('API Key 无效、缺失或已过期，请到「我的 → AI 设置」检查');
  }
  if (statusCode == 429 || code == '1113' || code == '1302' || code == '1305') {
    final why = code == '1113'
        ? '账户欠费'
        : code == '1302'
            ? '账户并发/频率已达上限（不一定是本 App 连点）'
            : code == '1305'
                ? '平台访问量过大'
                : '并发过高、额度用尽或欠费';
    return withMsg(
      '请求被限流或额度不足（${code.isEmpty ? 'HTTP 429' : '错误码 $code'}：$why）。'
      '请稍后再试，并到 open.bigmodel.cn 查看余额与速率限制',
    );
  }
  if (statusCode == 400 || statusCode == 404 || code == '1211') {
    return withMsg('接口地址或模型名不正确，请检查 Base URL 与模型');
  }
  if (statusCode >= 500) {
    return withMsg('模型服务暂时不可用（HTTP $statusCode），请稍后重试');
  }
  return withMsg('生成失败（HTTP $statusCode）');
}

/// SSE 增量：正文 content 与思考 reasoning（不进公文）。
class AiStreamDelta {
  final String content;
  final String reasoning;
  const AiStreamDelta({this.content = '', this.reasoning = ''});
}

Iterable<AiStreamDelta> parseSseDeltas(String chunk) sync* {
  for (final line in const LineSplitter().convert(chunk)) {
    if (!line.startsWith('data:')) continue;
    final data = line.substring(5).trim();
    if (data.isEmpty || data == '[DONE]') continue;
    try {
      final json = jsonDecode(data);
      if (json is! Map) continue;
      final choices = json['choices'];
      if (choices is! List || choices.isEmpty) continue;
      final choice = choices[0];
      if (choice is! Map) continue;
      final d = choice['delta'];
      if (d is! Map) continue;
      final c = d['content'];
      final r = d['reasoning_content'];
      final content = c is String ? c : '';
      final reasoning = r is String ? r : '';
      if (content.isEmpty && reasoning.isEmpty) continue;
      yield AiStreamDelta(content: content, reasoning: reasoning);
    } catch (_) {}
  }
}

/// 构造流式 chat/completions body。
Map<String, dynamic> buildAiChatBody({
  required String model,
  required String reason,
}) {
  return {
    'model': model.trim().isEmpty ? kAiDefaultModel : model.trim(),
    'messages': buildAiSituationMessages(reason),
    'stream': true,
    'thinking': {'type': 'disabled'},
    'temperature': kAiTemperature,
    'max_tokens': kAiMaxTokens,
  };
}

/// 流式生成情况说明。调用方可通过关闭 [client] 中止。
Future<String> streamAiSituationExplanation({
  required AiSettings settings,
  required String reason,
  required void Function(String delta) onContent,
  void Function(String delta)? onReasoning,
  http.Client? client,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final apiKey = settings.apiKey.trim();
  if (apiKey.isEmpty) {
    throw const AiGenerateException('尚未配置 API Key');
  }
  final userText = reason.trim();
  if (userText.isEmpty) {
    throw const AiGenerateException('请先填写原因');
  }

  final httpClient = client ?? http.Client();
  final owned = client == null;
  final uri = buildAiChatCompletionsUri(settings.baseUrl);

  try {
    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode(buildAiChatBody(
        model: settings.model,
        reason: userText,
      ));

    final response = await httpClient.send(request).timeout(
          timeout,
          onTimeout: () =>
              throw const AiGenerateException('请求超时，请检查网络后重试'),
        );

    if (response.statusCode != 200) {
      final errBody = await response.stream.bytesToString().timeout(
            const Duration(seconds: 10),
            onTimeout: () => '',
          );
      throw AiGenerateException(mapAiHttpError(response.statusCode, errBody));
    }

    final buffer = StringBuffer();
    await for (final bytes
        in response.stream.timeout(timeout).handleError((Object e) {
      throw e is TimeoutException
          ? const AiGenerateException('网络中断，请重试')
          : AiGenerateException('网络错误：$e');
    })) {
      final chunk = utf8.decode(bytes, allowMalformed: true);
      if (chunk.isEmpty) continue;
      for (final delta in parseSseDeltas(chunk)) {
        if (delta.reasoning.isNotEmpty) onReasoning?.call(delta.reasoning);
        if (delta.content.isNotEmpty) {
          buffer.write(delta.content);
          onContent(delta.content);
        }
      }
    }
    return buffer.toString();
  } on AiGenerateException {
    rethrow;
  } on TimeoutException {
    throw const AiGenerateException('请求超时，请检查网络后重试');
  } catch (e) {
    throw AiGenerateException('生成失败：$e');
  } finally {
    if (owned) httpClient.close();
  }
}
