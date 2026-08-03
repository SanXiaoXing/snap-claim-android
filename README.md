# snap_claim_android

A new Flutter project.

## Getting Started

```markdown
your_project/

├── android/              # Android 原生壳
├── ios/                  # iOS 原生壳
├── linux/
├── windows/
│
├── lib/                  # Flutter 层
│   ├── main.dart
│   │
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart
│   │   └── theme.dart
│   │
│   ├── features/         # 功能模块
│   │   ├── invoice/
│   │   │   ├── pages/
│   │   │   ├── widgets/
│   │   │   ├── models/
│   │   │   └── providers/
│   │   │
│   │   └── settings/
│   │
│   ├── core/
│   │   ├── bridge/       # Rust接口
│   │   ├── database/
│   │   ├── utils/
│   │   └── constants.dart
│   │
│   └── services/
│
├── rust/                 # Rust核心
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs
│       │
│       ├── api/          # 暴露给Flutter
│       │   ├── invoice.rs
│       │   ├── ocr.rs
│       │   └── settings.rs
│       │
│       ├── core/
│       │   ├── parser.rs
│       │   └── engine.rs
│       │
│       ├── database/
│       │
│       └── utils/
│
└── pubspec.yaml
```

## 作者与版权

作者：SanXiaoXing

版权所有 © 2026 SanXiaoXing，保留所有权利。