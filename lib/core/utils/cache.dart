// 缓存管理：计算和清除临时缓存（不触碰报销单数据库）。
// Android 上应用缓存目录与临时目录同一物理路径，只扫 getApplicationCacheDirectory。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

Future<Directory?> _cacheDir() async {
  try {
    return await getApplicationCacheDirectory();
  } catch (_) {
    return null;
  }
}

/// 递归计算目录大小（字节）—— 顶层函数，供 compute 在后台 isolate 中执行。
int _dirSizeSync(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return 0;
  var total = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) {
      total += entity.lengthSync();
    }
  }
  return total;
}

Future<int> _dirSizeAsync(Directory dir) async {
  try {
    return await compute(_dirSizeSync, dir.path);
  } catch (_) {
    return 0;
  }
}

/// 格式化字节数为人类可读字符串。
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// 计算可清除缓存的总大小并格式化为可读字符串。
Future<String> cacheSizeFormatted() async {
  final dir = await _cacheDir();
  if (dir == null) return formatBytes(0);
  return formatBytes(await _dirSizeAsync(dir));
}

/// 清除应用缓存目录中的所有文件；返回实际释放的字节数。
/// 报销单数据（sqflite）存储在独立数据库路径，不受影响。
Future<int> clearCache() async {
  final dir = await _cacheDir();
  if (dir == null || !dir.existsSync()) return 0;
  final freed = await _dirSizeAsync(dir);
  // 删除目录内容但保留目录本身（部分插件期望目录存在）。
  for (final entity in dir.listSync()) {
    try {
      if (entity is File) {
        await entity.delete();
      } else if (entity is Directory) {
        await entity.delete(recursive: true);
      }
    } catch (_) {}
  }
  return freed;
}
