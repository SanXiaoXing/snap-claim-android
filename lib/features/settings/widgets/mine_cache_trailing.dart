// 清除缓存行尾的缓存大小标签：异步加载一次并记忆，避免每次重建
// （删除/归档/保存后「我的」页会随 MainShell 整体重建）都重新触发
// 全量目录扫描导致主线程卡顿。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/cache.dart';

class CacheTrailing extends StatefulWidget {
  const CacheTrailing({super.key});

  @override
  State<CacheTrailing> createState() => _CacheTrailingState();
}

class _CacheTrailingState extends State<CacheTrailing> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = cacheSizeFormatted();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FutureBuilder<String>(
      future: _future,
      builder: (_, snap) => Text(
        snap.data ?? '计算中…',
        style: TextStyle(fontSize: 12, color: c.fgMuted),
      ),
    );
  }
}
