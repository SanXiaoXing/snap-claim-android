// 应用根组件：持有主题模式与报销单数据，装配 MaterialApp。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/database.dart';
import '../core/utils/ocr.dart';
import '../core/utils/shared_image.dart';
import '../features/invoice/models/claim.dart';
import '../features/invoice/models/record.dart';
import '../features/invoice/pages/editor_page.dart';
import '../features/invoice/pages/main_shell.dart';
import '../features/invoice/widgets/ocr_preview_dialog.dart';
import 'theme.dart';

class SnapClaimApp extends StatefulWidget {
  const SnapClaimApp({super.key});

  @override
  State<SnapClaimApp> createState() => _SnapClaimAppState();
}

class _SnapClaimAppState extends State<SnapClaimApp> {
  // 全局导航 Key：系统分享直达需在首帧后 push 编辑页 / 弹 OCR 进度窗。
  final _navKey = GlobalKey<NavigatorState>();
  // 热启动（应用已在后台运行）时的分享图片事件订阅。
  StreamSubscription<List<String>>? _sharedSub;

  // 主题偏好存储键：保存 ThemeMode 的名称（system / light / dark）。
  static const _themePrefsKey = 'themeMode';

  ThemeMode _themeMode = ThemeMode.system;
  List<Claim> _claims = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SharedImageReceiver.init();
    _init();
    // 冷启动：应用从分享面板被拉起，取走待处理图片并走 OCR 解析。
    _consumePendingSharedImages();
    // 热启动：应用已在运行，监听新分享的图片路径。
    _sharedSub =
        SharedImageReceiver.onSharedImages.listen(_handleSharedImages);
  }

  /// 首帧前的初始化：并行读取报销单与持久化的主题设置，
  /// 两者都就绪后才渲染主界面，避免主题先以默认值闪一下再切换。
  Future<void> _init() async {
    List<Claim> claims;
    try {
      claims = await AppDatabase.instance.getAllClaims();
    } catch (e) {
      debugPrint('加载报销单失败（列表将为空）: $e');
      claims = [];
    }
    var themeMode = ThemeMode.system;
    try {
      final prefs = await SharedPreferences.getInstance();
      themeMode = _themeModeFromName(prefs.getString(_themePrefsKey));
    } catch (e) {
      debugPrint('读取主题设置失败（使用跟随系统）: $e');
    }
    if (!mounted) return;
    setState(() {
      _claims = claims;
      _themeMode = themeMode;
      _loading = false;
    });
  }

  /// 外观模式三态切换：更新内存并持久化，重启应用后保持。
  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _persist(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefsKey, mode.name);
    }, '保存主题设置');
  }

  static ThemeMode _themeModeFromName(String? name) {
    for (final m in ThemeMode.values) {
      if (m.name == name) return m;
    }
    return ThemeMode.system;
  }

  @override
  void dispose() {
    _sharedSub?.cancel();
    super.dispose();
  }

  void _saveClaim(Claim claim) {
    setState(() {
      final idx = _claims.indexWhere((e) => e.id == claim.id);
      if (idx >= 0) {
        final next = [..._claims];
        next[idx] = claim;
        _claims = next;
      } else {
        _claims = [claim, ..._claims];
      }
    });
    _persist(() => AppDatabase.instance.upsertClaim(claim), '保存报销单');
  }

  /// 归档报销单（归档 = 已报销）：更新内存状态并持久化。
  void _archiveClaim(Claim claim) {
    final archived = claim.copyWith(archived: true);
    setState(() {
      final idx = _claims.indexWhere((e) => e.id == claim.id);
      if (idx >= 0) {
        final next = [..._claims];
        next[idx] = archived;
        _claims = next;
      }
    });
    _persist(() => AppDatabase.instance.upsertClaim(archived), '归档报销单');
  }

  /// 撤销归档（已报销 → 未归档）：更新内存状态并持久化。
  void _restoreClaim(Claim claim) {
    final restored = claim.copyWith(archived: false);
    setState(() {
      final idx = _claims.indexWhere((e) => e.id == claim.id);
      if (idx >= 0) {
        final next = [..._claims];
        next[idx] = restored;
        _claims = next;
      }
    });
    _persist(() => AppDatabase.instance.upsertClaim(restored), '撤销归档');
  }

  /// 删除报销单：从内存移除并从数据库删除（含明细）。
  void _deleteClaim(Claim claim) {
    setState(() {
      _claims = _claims.where((e) => e.id != claim.id).toList();
    });
    _persist(() => AppDatabase.instance.deleteClaim(claim.id), '删除报销单');
  }

  /// 从数据库重新加载报销单（备份导入替换数据库文件后调用）。
  Future<void> _reloadClaims() async {
    List<Claim> claims;
    try {
      claims = await AppDatabase.instance.getAllClaims();
    } catch (e) {
      debugPrint('加载报销单失败（列表将为空）: $e');
      claims = [];
    }
    if (!mounted) return;
    setState(() => _claims = claims);
  }

  /// 持久化到数据库：内存已先行更新，写入失败不打断 UI，
  /// 但必须打印错误——否则数据看似已保存、重启后却丢失且无从排查。
  void _persist(Future<void> Function() op, String what) {
    op().catchError((Object e) {
      debugPrint('$what失败（数据未写入磁盘，重启应用后可能丢失）: $e');
    });
  }

  /// 冷启动：取走分享面板直达的待处理图片路径。
  Future<void> _consumePendingSharedImages() async {
    final paths = await SharedImageReceiver.takePending();
    if (paths.isEmpty) return;
    // 首帧后 Navigator 才可用（OCR 进度窗 / 预览对话框 / push 编辑页都需要）。
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _handleSharedImages(paths);
  }

  /// 分享图片直达：逐张 OCR → 弹可编辑预览 → 确认后新建报销单并进入编辑页。
  Future<void> _handleSharedImages(List<String> paths) async {
    final context = _navKey.currentContext;
    if (context == null) return;
    for (final path in paths) {
      // context 来自全局 Navigator，须用 context.mounted 而非 State.mounted
      // 守卫（循环跨 await 后再次使用，lint 要求同 context 的检查）。
      if (!context.mounted) return;
      final result = await recognizeImageFile(context, path);
      if (!context.mounted) return;
      if (result == null || result.error != null) {
        showAppSnack(context, result?.error ?? '识别失败，请重试', ms: 1600);
        continue;
      }
      if (result.records.isEmpty) {
        showAppSnack(context, '未识别到票据信息，请换一张清晰的截图', ms: 1600);
        continue;
      }
      final added = await showDialog<List<Record>>(
        context: context,
        builder: (_) => OcrPreviewDialog(initial: result.records),
      );
      if (!context.mounted || added == null || added.isEmpty) continue;
      // 以识别明细新建一张报销单并进入编辑页，用户可继续完善后保存。
      final now = DateTime.now();
      final claim = Claim(
        id: '${now.microsecondsSinceEpoch}',
        name: '',
        startDate: now,
        endDate: now,
        records: added,
        savedAt: now,
      );
      _navKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => EditorPage(
            claim: claim,
            onSave: _saveClaim,
            // 明细尚未持久化：返回时必须弹保存确认，防止静默丢弃。
            promptSaveOnExit: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapClaim',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: _themeMode,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : MainShell(
              claims: _claims,
              onSaveClaim: _saveClaim,
              onArchiveClaim: _archiveClaim,
              onRestoreClaim: _restoreClaim,
              onDeleteClaim: _deleteClaim,
              onDataRestored: _reloadClaims,
              themeMode: _themeMode,
              onChangeThemeMode: _setThemeMode,
            ),
    );
  }
}
