import 'package:flutter/material.dart';

import 'app/app.dart';
import 'src/rust/frb_generated.dart';

Future<void> main() async {
  // 初始化 Flutter-Rust 桥，加载 Rust 核心库（snap_claim_core）。
  await RustLib.init();
  runApp(const SnapClaimApp());
}
