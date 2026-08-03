// 缓存管理：计算和清除临时缓存（不触碰报销单数据库）。
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 可清除的缓存目录：临时目录 + 应用缓存目录。
/// 报销单数据库（sqflite）存储在独立的数据库路径下，不受影响。
Future<List<Directory>> _cacheDirs() async {
  final dirs = <Directory>[];
  try {
    dirs.add(await getTemporaryDirectory());
  } catch (_) {}
  try {
    dirs.add(await getApplicationCacheDirectory());
  } catch (_) {}
  return dirs;
}

/// 递归计算目录大小（字节）。
int _dirSize(Directory dir) {
  if (!dir.existsSync()) return 0;
  var total = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) {
      total += entity.lengthSync();
    }
  }
  return total;
}

/// 计算可清除缓存的总大小，返回字节。
Future<int> cacheSizeBytes() async {
  final dirs = await _cacheDirs();
  return dirs.fold<int>(0, (s, d) => s + _dirSize(d));
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
Future<String> cacheSizeFormatted() async => formatBytes(await cacheSizeBytes());

/// 清除缓存：删除临时目录和应用缓存目录中的所有文件。
/// 报销单数据（sqflite）不受影响。
/// 返回实际释放的字节数。
Future<int> clearCache() async {
  final dirs = await _cacheDirs();
  var freed = 0;
  for (final dir in dirs) {
    if (!dir.existsSync()) continue;
    freed += _dirSize(dir);
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
  }
  return freed;
}
