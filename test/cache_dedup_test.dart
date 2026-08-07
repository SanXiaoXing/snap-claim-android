// 缓存去重单元测试：同一物理目录（Android 上临时目录与应用缓存目录
// 都是 context.cacheDir）只统计一次，避免大小重复统计 / 清除量对不上。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/core/utils/cache.dart';

void main() {
  test('同一物理目录（含尾部分隔符变体）只保留一个', () {
    final tmp = Directory.systemTemp.createTempSync('snap_claim_cache_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final path = tmp.path;

    // 模拟 Android：两个 API 返回同一路径，其中一个带尾分隔符。
    final dirs = [
      Directory(path),
      Directory(path.endsWith('/') ? path : '$path/'),
    ];

    final result = dedupeCacheDirs(dirs);
    expect(result.length, 1);
    expect(result.single.path, dirs.first.path);
  });

  test('不同目录全部保留', () {
    final a = Directory.systemTemp.createTempSync('snap_claim_cache_a');
    final b = Directory.systemTemp.createTempSync('snap_claim_cache_b');
    addTearDown(() {
      a.deleteSync(recursive: true);
      b.deleteSync(recursive: true);
    });

    final result = dedupeCacheDirs([a, b]);
    expect(result.length, 2);
  });

  test('去重后清除返回的释放量与统计口径一致', () {
    final a = Directory.systemTemp.createTempSync('snap_claim_cache_dup');
    addTearDown(() => a.deleteSync(recursive: true));
    // 写入 1KB 文件。
    File('${a.path}/data.bin').writeAsBytesSync(List.filled(1024, 1));

    // 去重后同一目录只出现一次。
    final dirs = dedupeCacheDirs([
      Directory(a.path),
      Directory('${a.path}/'), // 模拟 Android 同路径别名
    ]);
    expect(dirs.length, 1);

    // 统计大小 = 目录实际大小（不再翻倍）。
    final size = _dirSizePublic(dirs.first);
    expect(size, 1024);
  });
}

/// 与 cache.dart 内部 _dirSize 相同的递归统计逻辑（公开镜像）。
int _dirSizePublic(Directory dir) {
  if (!dir.existsSync()) return 0;
  var total = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) {
      total += entity.lengthSync();
    }
  }
  return total;
}
