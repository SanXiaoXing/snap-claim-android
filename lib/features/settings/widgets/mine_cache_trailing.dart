// 清除缓存行尾的缓存大小标签：异步加载，构建时刷新。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/cache.dart';

class CacheTrailing extends StatelessWidget {
  const CacheTrailing({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FutureBuilder<String>(
      future: cacheSizeFormatted(),
      builder: (_, snap) => Text(
        snap.data ?? '计算中…',
        style: TextStyle(fontSize: 12, color: c.fgMuted),
      ),
    );
  }
}
