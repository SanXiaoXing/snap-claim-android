// 应用根组件：持有主题模式与报销单数据，装配 MaterialApp。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/database.dart';
import '../core/utils/app_shortcuts.dart';
import '../core/utils/entry_action.dart';
import '../core/utils/home_widgets.dart';
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
  final _navKey = GlobalKey<NavigatorState>();
  final _shellKey = GlobalKey<MainShellState>();
  StreamSubscription<List<String>>? _sharedSub;
  StreamSubscription<EntryAction>? _entrySub;
  Future<void>? _initFuture;
  int _initialTab = kTabIndexHome;

  static const _themePrefsKey = 'themeMode';

  ThemeMode _themeMode = ThemeMode.system;
  List<Claim> _claims = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SharedImageReceiver.init();
    // 先监听入口 action，再 bind 快捷方式 / 桌面小组件：冷启动点击回调不丢。
    _entrySub = EntryActionReceiver.onAction.listen(_dispatchEntryAction);
    AppShortcuts.bind();
    HomeWidgets.bindEntryActions();
    _initFuture = _init();
    _consumePendingSharedImages();
    _consumePendingEntryActions();
    _sharedSub =
        SharedImageReceiver.onSharedImages.listen(_handleSharedImages);
  }

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
    await AppShortcuts.refresh(claims);
    await HomeWidgets.refreshAll(claims);
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _persist(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefsKey, mode.name);
    }, '保存主题设置');
  }

  static ThemeMode _themeModeFromName(String? name) =>
      ThemeMode.values.asNameMap()[name] ?? ThemeMode.system;

  @override
  void dispose() {
    _entrySub?.cancel();
    _sharedSub?.cancel();
    super.dispose();
  }

  void _afterClaimsChanged() {
    AppShortcuts.refresh(_claims);
    HomeWidgets.refreshAll(_claims);
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
    _afterClaimsChanged();
    _persist(() => AppDatabase.instance.upsertClaim(claim), '保存报销单');
  }

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
    _afterClaimsChanged();
    _persist(() => AppDatabase.instance.upsertClaim(archived), '归档报销单');
  }

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
    _afterClaimsChanged();
    _persist(() => AppDatabase.instance.upsertClaim(restored), '撤销归档');
  }

  void _deleteClaim(Claim claim) {
    setState(() {
      _claims = _claims.where((e) => e.id != claim.id).toList();
    });
    _afterClaimsChanged();
    _persist(() => AppDatabase.instance.deleteClaim(claim.id), '删除报销单');
  }

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
    await AppShortcuts.refresh(claims);
    await HomeWidgets.refreshAll(claims);
  }

  void _persist(Future<void> Function() op, String what) {
    op().catchError((Object e) {
      debugPrint('$what失败（数据未写入磁盘，重启应用后可能丢失）: $e');
    });
  }

  Future<void> _consumePendingSharedImages() async {
    final paths = await SharedImageReceiver.takePending();
    if (paths.isEmpty) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _handleSharedImages(paths);
  }

  Future<void> _consumePendingEntryActions() async {
    await _initFuture;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    for (final action in EntryActionReceiver.takePending()) {
      if (!mounted) return;
      await _dispatchEntryAction(action);
    }
  }

  Future<void> _dispatchEntryAction(EntryAction action) async {
    switch (action.kind) {
      case EntryActionKind.openMine:
        final shell = _shellKey.currentState;
        if (shell != null) {
          shell.selectTab(kTabIndexMine);
        } else if (mounted && _initialTab != kTabIndexMine) {
          setState(() => _initialTab = kTabIndexMine);
        }
      case EntryActionKind.newClaim:
        final now = DateTime.now();
        await _pushEditor(
          Claim(
            id: '${now.microsecondsSinceEpoch}',
            name: '',
            startDate: now,
            endDate: now,
            records: const [],
            savedAt: now,
          ),
        );
      case EntryActionKind.editClaim:
        final claim = _claims.where((c) => c.id == action.claimId).firstOrNull;
        if (claim == null) {
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted || _navKey.currentContext == null) return;
          showAppSnack(_navKey.currentContext!, '报销单不存在');
          return;
        }
        await _pushEditor(claim);
    }
  }

  Future<void> _pushEditor(Claim claim) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _navKey.currentState == null) return;
    _navKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => EditorPage(claim: claim, onSave: _saveClaim),
      ),
    );
  }

  Future<void> _handleSharedImages(List<String> paths) async {
    final context = _navKey.currentContext;
    if (context == null) return;
    for (final path in paths) {
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
      themeAnimationDuration: const Duration(milliseconds: 300),
      themeAnimationCurve: Curves.easeOutCubic,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : MainShell(
              key: _shellKey,
              claims: _claims,
              onSaveClaim: _saveClaim,
              onArchiveClaim: _archiveClaim,
              onRestoreClaim: _restoreClaim,
              onDeleteClaim: _deleteClaim,
              onDataRestored: _reloadClaims,
              themeMode: _themeMode,
              onChangeThemeMode: _setThemeMode,
              initialTab: _initialTab,
            ),
    );
  }
}
