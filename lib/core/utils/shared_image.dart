// 系统分享面板直达：其他 App（如小米相册）分享图片时，Android 侧把图片
// 复制到应用缓存目录并通过 MethodChannel 暴露路径，本接收器负责取走路径。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 分享图片接收器：封装 Android 侧 `snap_claim/shared_images` 通道。
///
/// 两种接入方式：
/// - 冷启动：应用从分享面板被拉起，启动后调用 [takePending] 取走待处理图片。
/// - 热启动：应用已在后台运行，通过 [onSharedImages] 事件流收到新分享。
class SharedImageReceiver {
  SharedImageReceiver._();

  static const _channel = MethodChannel('snap_claim/shared_images');

  static final _onSharedImages = StreamController<List<String>>.broadcast();

  /// 应用已在运行时收到的分享图片本地路径（缓存目录），逐个监听处理。
  static Stream<List<String>> get onSharedImages => _onSharedImages.stream;

  /// 注册原生 → Dart 事件（须在引擎就绪后、监听前调用一次）。
  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedImages') {
        final paths = (call.arguments as List?)?.cast<String>() ?? const [];
        if (paths.isNotEmpty) {
          _onSharedImages.add(paths);
        }
      }
    });
  }

  /// 冷启动：取走所有待处理的分享图片路径（取走即清空，避免重复处理）。
  static Future<List<String>> takePending() async {
    try {
      final list =
          await _channel.invokeMethod<List<dynamic>>('takePendingImages');
      return list?.cast<String>() ?? const [];
    } catch (e) {
      debugPrint('读取待处理分享图片失败: $e');
      return const [];
    }
  }
}
