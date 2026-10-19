import 'dart:async';

import 'package:flutter/services.dart';

/// Android 原生通知与闹钟；桌面测试环境不提供该通道。
class ClaimReminders {
  static const _channel = MethodChannel('snap_claim/reminders');
  static final _changes = StreamController<void>.broadcast();
  static bool _bound = false;

  static Stream<void> get onChanged {
    if (!_bound) {
      _bound = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'changed') _changes.add(null);
      });
    }
    return _changes.stream;
  }

  static Future<void> sync() async {
    try {
      await _channel.invokeMethod<void>('sync');
    } on MissingPluginException {
      // Widget 测试 / 非 Android 平台。
    }
  }

  static Future<({int hour, int minute})> getTime() async {
    try {
      final value = await _channel.invokeMapMethod<String, int>('getTime');
      return (hour: value?['hour'] ?? 10, minute: value?['minute'] ?? 0);
    } on MissingPluginException {
      return (hour: 10, minute: 0);
    }
  }

  static Future<void> setTime(int hour, int minute) async {
    await _channel.invokeMethod<void>('setTime', {
      'hour': hour,
      'minute': minute,
    });
  }
}
