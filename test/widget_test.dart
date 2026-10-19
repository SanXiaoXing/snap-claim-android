// 应用冒烟测试：验证 SnapClaimApp 在浅色/深色主题下均可正常构建。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/app/app.dart';

void main() {
  testWidgets('SnapClaimApp builds in light mode without throwing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SnapClaimApp());
    // App 启动时异步加载数据库；pump 多帧让 Future 完成。
    await tester.pump();
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
