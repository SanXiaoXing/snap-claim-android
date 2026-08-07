// 缓存管理：计算和清除临时缓存（不触碰报销单数据库）。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 可清除的缓存目录：临时目录 + 应用缓存目录。
/// 报销单数据库（sqflite）存储在独立的数据库路径下，不受影响。
/// 注意：Android 上 [getTemporaryDirectory] 与 [getApplicationCacheDirectory]
/// 都返回同一物理目录（context.cacheDir），必须去重，否则大小会重复统计。
Future<List<Directory>> _cacheDirs() async {
  final dirs = <Directory>[];
  try {
    dirs.add(await getTemporaryDirectory());
  } catch (_) {}
  try {
    dirs.add(await getApplicationCacheDirectory());
  } catch (_) {}
  return dedupeCacheDirs(dirs);
}

/// 规范化目录路径用于去重比较：
/// 解析符号链接得到真实路径，并去掉末尾分隔符。
String normalizeDirPath(Directory d) {
  try {
    return d.resolveSymbolicLinksSync();
  } catch (_) {
    var p = d.absolute.path;
    while (p.length > 1 && (p.endsWith('/') || p.endsWith('\\'))) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }
}

/// 按物理路径去重：同一目录（含符号链接别名）只保留第一个。
/// Android 上临时目录与应用缓存目录是同一路径，重复会导致
List<Directory> dedupeCacheDirs(List<Directory> dirs) {
  final seen = <String>{};
  return [
    for (final d in dirs)
      if (seen.add(normalizeDirPath(d))) d,
  ];
}

/// 递归计算目录大小（字节）—— 顶层函数，供 compute 在后台 isolate 中执行，
/// 避免在主线程同步遍历目录导致 UI 卡顿（缓存文件多时尤为明显）。
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

/// 在后台 isolate 中计算目录大小，失败时按 0 处理。
Future<int> _dirSizeAsync(Directory dir) async {
  try {
    return await compute(_dirSizeSync, dir.path);
  } catch (_) {
    return 0;
  }
}

/// 计算可清除缓存的总大小，返回字节。
Future<int> cacheSizeBytes() async {
  final dirs = await _cacheDirs();
  var total = 0;
  for (final d in dirs) {
    total += await _dirSizeAsync(d);
  }
  return total;
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
    freed += await _dirSizeAsync(dir);
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
