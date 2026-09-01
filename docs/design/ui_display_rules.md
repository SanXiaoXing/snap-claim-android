> 本文定义 SnapClaim 界面"如何显示"的统一约定。
> 新增任何页面、组件、动效前，先读这一份。

---

## 核心结论（一句话）

SnapClaim 是**无第三方状态库**的 Flutter 应用：

```
根 StatefulWidget（唯一可信数据源）
  │  setState 改内存
  │  → 回调冒泡（onSaveClaim 等）
  ▼
MaterialApp（theme / darkTheme / themeMode）
  ▼
MainShell（Stack 三页 + Liquid Glass 底栏）
  ▼
复用 widgets（context.colors 取色板）
  + 少量 StatefulWidget 动效件
```

Rust 后端通过 `flutter_rust_bridge` 异步返回数据，界面用 `await + mounted 守卫 + setState` 刷新。

---

# 1. 状态管理规则（最重要）

> 不引入 Provider / Riverpod / Bloc / GetX / ValueNotifier / StreamBuilder。

## 1.1 单一可信数据源

- 根组件 `SnapClaimApp`（`lib/app/app.dart`）持有全局状态：
  - `List<Claim> _claims` —— 所有报销单
  - `ThemeMode _themeMode` —— 主题模式
- 任何其他地方**不得**私自保存一份 `_claims` 的副本作为真相来源。

## 1.2 数据向下传递：构造参数 + 回调

- 子页通过**构造参数**接收数据（如 `MainShell(claims: _claims, onSaveClaim: _saveClaim)`）。
- 子页通过**回调**把变更冒泡回根组件（如 `ValueChanged<Claim>`）。
- 子页操作 → 根组件 `setState` 改 `_claims` → 整棵 `MaterialApp` 重建 → 所有页面拿到新数据。

```dart
// 正确：子页只管回调，不碰全局数据
void _saveClaim(Claim claim) {
  setState(() {
    final idx = _claims.indexWhere((e) => e.id == claim.id);
    if (idx >= 0) { final next = [..._claims]; next[idx] = claim; _claims = next; }
    else { _claims = [claim, ..._claims]; }
  });
  _persist(() => AppDatabase.instance.upsertClaim(claim), '保存报销单');
}
```

## 1.3 持久化与刷新分离

- 内存变更立即 `setState`，持久化（`sqflite`）异步进行，二者不互相阻塞。
- 备份导入替换数据库后，调用 `_reloadClaims()` 重新 `getAllClaims()` 并 `setState`，而不是就地拼凑。

---

# 2. 主题与取色规则（样式中枢）

> 全项目颜色**只允许**通过 `context.colors` 取，禁止硬编码 `Colors.xxx`。

## 2.1 色板定义在 theme.dart

- 色板 `AppColorScheme` 是 `ThemeExtension`，挂在 `ThemeData` 上（`lib/app/theme.dart`）。
- 包含令牌：`bg / card / border / fg / fgMuted / accent / accentBg / danger` 等 13 个。
- 浅色 `AppColorScheme.light` 与深色 `AppColorScheme.dark` 各一套常量。

## 2.2 取色扩展（强制约定）

每个组件 `build` 开头第一句：

```dart
final c = context.colors;
```

之后所有颜色用 `c.bg` / `c.card` / `c.fg` / `c.accent` …，这是 UI 一致性的根基。

## 2.3 Material3 与细节

- `useMaterial3: true`，色板映射到 `ColorScheme` / `appBarTheme` / `inputDecorationTheme`。
- 点击涟漪：`splashFactory: InkSparkle`。
- 通用卡片圆角装饰：`cardDecoration(c)`（圆角 16 + 细边框）—— 全项目复用，不要各自写 `BoxDecoration`。
- 全局提示：`showAppSnack(...)` —— 不要用裸 `ScaffoldMessenger` 自己拼。

---

# 3. 组件编写规则

## 3.1 StatelessWidget 优先

> 纯展示组件一律 `StatelessWidget`。

- 卡片、标签、表单字段、空状态、列表项 → `StatelessWidget`，只通过 `widget.xxx` 取 props。
- 仅以下情况才用 `StatefulWidget`：
  1. 持有全局 / 页面状态（`SnapClaimApp` / `MainShell` / `EditorPage` / `DetailPage` / `MinePage`）
  2. 自带动画（`CreateCta` / `FabMenu` / `_SelectedPill` 带 `AnimationController`）
  3. 内部瞬时态（如 `PressScale` 的 `_pressed`、弹窗里的临时选中）

## 3.2 build 方法组织惯例

```dart
Widget build(BuildContext context) {
  final c = context.colors;            // 1. 取色板
  return Column(                       // 2. 页面骨架：Column + Expanded(SingleChildScrollView)
    children: [
      ...
      if (cond) ...[                    // 3. 条件渲染用 if (...) ...[...]
        ...
      ],
      for (final x in list) ...[        // 4. 列表渲染用 for (...) ...[...]
        ...
      ],
    ],
  );
}
```

- 局部弹窗 / 私有子组件放在同文件（如 `editor_page.dart` 内的 `_ExitConfirmDialog`），避免跨文件碎片。

## 3.3 复用件清单（不要重复造）

| 组件 | 位置 | 用途 |
|------|------|------|
| `AppTopBar` / `AppIconButton` | `widgets/app_top_bar.dart` | 居中标题栏 / 36×36 圆角图标按钮 |
| `PressScale` | `widgets/press_scale.dart` | 按下缩小 0.94 的点击反馈（必包可点元素） |
| `FieldLabel` / `DatePill` | `widgets/field_widgets.dart` | 表单字段 / 日期胶囊 |
| `CategoryBadge` 等 | `widgets/chips.dart` | 分类标签体系 |
| `EmptyHint` | `widgets/empty_hint.dart` | 空状态占位 |
| `ClaimCard` | `widgets/claim_card.dart` | 报销单卡片（首页/历史/归档复用） |
| `CreateCta` | `widgets/create_cta.dart` | 圆形创建按钮 + 呼吸光环 |
| `_GlassTabBar` | `main_shell.dart` | 底部 Liquid Glass 导航栏 |

---

# 4. Rust 数据刷新规则

## 4.1 封装位置

Rust 调用统一收口在 `lib/core/utils/`：

- `allowance.dart` → `rust.perDiemAllowance(...)`
- `ocr.dart` → OCR 识别
- `qr_parser.dart` → 二维码解析

不要在其他页面直接 `import '../../src/rust/api/...'`。

## 4.2 异步刷新三段式（强制）

```dart
Future<void> _refresh() async {
  final result = await perDiemAllowance(_start, _end); // 1. await Rust
  if (!mounted) return;                                 // 2. mounted 守卫（防异步后崩溃）
  setState(() => _allowance = result);                  // 3. 写入局部状态 → 局部 rebuild
}
```

> `await` 之后**必须**有 `if (!mounted) return;`，这是铁律。

---

# 5. 导航规则

> 不用任何路由框架（无 go_router / auto_route）。

- 全部使用 `MaterialPageRoute` 命令式 `Navigator.push`。
- 根组件持有 `GlobalKey<NavigatorState>`，支持"系统分享直达"从后台 push 页面。
- 页面栈：`MainShell` → push `EditorPage` / `DetailPage` / `QrScannerPage` 等。

---

# 6. 暗色模式规则

- 三态：`ThemeMode.system / light / dark`，用 `shared_preferences` 持久化（键 `themeMode`）。
- 切换时带 300ms `easeOutCubic` 过渡。
- 明暗分支用 `Theme.of(context).brightness` 或 `c == AppColorScheme.dark` 判断（如 `chips.dart`、`claim_card.dart`）。

---

# 7. 动效与"减少动态"规则

> 任何动画都必须尊重系统"减少动态"偏好。

- 多处读取 `MediaQuery.maybeOf(context)?.disableAnimations`（`main_shell.dart`、`create_cta.dart`、`fab_menu.dart`）。
- 关闭动画时直接跳变（弹簧跳过、呼吸光环停转），不得强制播放。
- 点击反馈用 `PressScale`（按下缩小 0.94），保持一致手感。

---

# 8. 安全区域与键盘适配规则

- 顶部栏用 `SafeArea(bottom: false)`，底部栏用 `SafeArea(top: false)`，避免被刘海 / 手势条遮挡。
- `MainShell` 设 `extendBody: true`，让内容延伸到底部栏之下供玻璃模糊。
- 编辑 / 详情页正文用 `SingleChildScrollView`，底部 `padding` 留 120 容纳 FAB。
- 键盘弹起时依赖 Scaffold 默认 `resizeToAvoidBottomInset`，内容自然上推；不要覆盖成 `false`。

---

# 9. 不可变数据模型规则

> 所有业务模型是 `@immutable` 类 + `copyWith`。

- 刷新时一律生成**新对象**（配合 `setState` 触发 diff）。
- 列表更新用 `[...list]` 展开产生新引用，禁止就地 `list[i] = x` 修改。

```dart
@immutable
class Claim {
  final String id;
  final double amount;
  const Claim({required this.id, required this.amount});
  Claim copyWith({double? amount}) => Claim(id: id, amount: amount ?? this.amount);
}
```

---

# 10. 生命周期与异步安全规则

- `initState` 取初始值，`dispose` 释放 `TextEditingController` / `AnimationController`。
- `MediaQuery` 必须在 `didChangeDependencies` 中读取，不要在 `initState` 里读。
- 首帧后弹引导用 `WidgetsBinding.instance.addPostFrameCallback`，配合 `GlobalKey` 定位目标控件。
- 所有 `await` 后都加 `if (!mounted) return;`（见第 4.2 节）。

---

# 11. 多语言（当前状态，需改进）

> 当前是"名义支持，实际只中文"，不要误以为已做 i18n。

- `app.dart` 声明了 `supportedLocales: [zh_CN, en_US]`，但 `locale` 硬编码 `const Locale('zh','CN')`。
- 无 `intl` 包、无 `.arb`、无 `lib/l10n`，所有文案硬编码中文。
- **新增文案直接写中文即可**，但要意识到未来需要抽资源文件。

---

# 速查清单（新增页面时核对）

- [ ] 颜色只用 `context.colors`，无硬编码 `Colors.xxx`
- [ ] `build` 开头 `final c = context.colors;`
- [ ] 纯展示组件用 `StatelessWidget`
- [ ] 数据变更走回调冒泡到根 `setState`，不私存副本
- [ ] Rust 异步调用三段式：`await` → `if (!mounted) return` → `setState`
- [ ] 动画读 `disableAnimations`，关动态时跳变
- [ ] 卡片用 `cardDecoration(c)`，提示用 `showAppSnack`
- [ ] 模型 `@immutable` + `copyWith`，列表用 `[...list]` 展开
- [ ] 顶部 / 底部 `SafeArea` 正确，键盘适配交给 Scaffold 默认行为
