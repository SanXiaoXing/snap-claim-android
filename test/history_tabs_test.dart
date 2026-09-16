// 历史页「滑动分段 tab」与滑动操作回归测试。
//
// 覆盖：默认 tab / 点按切换 / 拖拽 tab 切换 / 未报销左滑归档 /
// 已报销右滑撤销归档 / 已报销左滑删除（二次确认）/ 两个 tab 的空态文案。
//
// 说明：
// - HistoryPage 自身不带 Scaffold（由 MainShell 提供），测试里用 Scaffold(body:) 包裹。
// - 归档 / 撤销 / 删除都通过回调冒泡给上层，这里用一个有状态外壳持有 claims，
//   在回调里 setState 刷新，模拟根组件的单一可信数据源（这样被操作项会真正从
//   列表移除，与真实运行时一致，也避免 Dismissible 残留在树上）。
// - 用 pumpAndSettle 检测卡死（无限动画 / 每帧重建会超时抛出）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/app/theme.dart';
import 'package:snap_claim_android/features/invoice/models/claim.dart';
import 'package:snap_claim_android/features/invoice/models/record.dart';
import 'package:snap_claim_android/features/invoice/pages/history_page.dart';
import 'package:snap_claim_android/features/invoice/widgets/sliding_pill.dart';
import 'package:snap_claim_android/features/invoice/widgets/sliding_segmented_tabs.dart';

Record _record(String id) => Record(
      id: id,
      category: RecordCategory.train,
      title: '明细$id',
      subtitle: '',
      amount: 100,
    );

Claim _claim(String id, {bool archived = false}) => Claim(
      id: id,
      name: '报销单$id',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 3),
      records: [_record('r$id')],
      savedAt: DateTime(2026, 7, 3),
      archived: archived,
    );

/// 模拟根组件的状态外壳：持有 claims，回调里 setState 刷新。
class _Harness extends StatefulWidget {
  final List<Claim> initial;
  final List<String> archivedLog;
  final List<String> restoredLog;
  final List<String> deletedLog;

  const _Harness({
    required this.initial,
    required this.archivedLog,
    required this.restoredLog,
    required this.deletedLog,
  });

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late List<Claim> _claims;

  @override
  void initState() {
    super.initState();
    _claims = [...widget.initial];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HistoryPage(
        claims: _claims,
        onSaveClaim: (_) {},
        onArchiveClaim: (c) {
          widget.archivedLog.add(c.id);
          setState(() => _claims = [
                for (final x in _claims)
                  x.id == c.id ? x.copyWith(archived: true) : x,
              ]);
        },
        onRestoreClaim: (c) {
          widget.restoredLog.add(c.id);
          setState(() => _claims = [
                for (final x in _claims)
                  x.id == c.id ? x.copyWith(archived: false) : x,
              ]);
        },
        onDeleteClaim: (c) {
          widget.deletedLog.add(c.id);
          setState(
              () => _claims = _claims.where((x) => x.id != c.id).toList());
        },
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  List<Claim> claims, {
  List<String>? archivedLog,
  List<String>? restoredLog,
  List<String>? deletedLog,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: _Harness(
        initial: claims,
        archivedLog: archivedLog ?? [],
        restoredLog: restoredLog ?? [],
        deletedLog: deletedLog ?? [],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// QA 对抗性用例专用：可控选中下标的 [SlidingSegmentedTabs] 宿主。
/// 记录每次 onChanged 收到的下标（用于断言「是否发生了切换」）。
class _TabHost extends StatefulWidget {
  final int initialIndex;
  final List<int>? changes;
  final bool reduceMotion;

  const _TabHost({
    super.key,
    this.initialIndex = 0,
    this.changes,
    this.reduceMotion = false,
  });

  @override
  State<_TabHost> createState() => _TabHostState();
}

class _TabHostState extends State<_TabHost> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    Widget body = Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SlidingSegmentedTabs(
          index: _index,
          labels: const ['未报销', '已报销'],
          counts: const [2, 3],
          onChanged: (i) {
            widget.changes?.add(i);
            setState(() => _index = i);
          },
        ),
      ),
    );
    if (widget.reduceMotion) {
      body = MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: body,
      );
    }
    return MaterialApp(theme: buildLightTheme(), home: body);
  }
}

void main() {
  testWidgets('默认停在「未报销」：只显示未归档项', (tester) async {
    await _pump(tester, [_claim('u1'), _claim('a1', archived: true)]);

    expect(find.text('未报销'), findsOneWidget);
    expect(find.text('已报销'), findsOneWidget);
    expect(find.text('报销单u1'), findsOneWidget);
    expect(find.text('报销单a1'), findsNothing);
  });

  testWidgets('点按「已报销」切到已归档列表且不卡死', (tester) async {
    await _pump(tester, [_claim('u1'), _claim('a1', archived: true)]);

    await tester.tap(find.text('已报销'));
    await tester.pumpAndSettle();

    expect(find.text('报销单a1'), findsOneWidget);
    expect(find.text('报销单u1'), findsNothing);
  });

  testWidgets('在 tab 标签上横向拖拽可切换 tab', (tester) async {
    await _pump(tester, [_claim('u1'), _claim('a1', archived: true)]);

    // 从「未报销」标签向右拖拽超过半格 → 切到「已报销」。
    await tester.drag(find.text('未报销'), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.text('报销单a1'), findsOneWidget);
    expect(find.text('报销单u1'), findsNothing);
  });

  testWidgets('未报销 tab 左滑归档：卡片消失且回调收到 id', (tester) async {
    final archived = <String>[];
    await _pump(
      tester,
      [_claim('u1'), _claim('u2')],
      archivedLog: archived,
    );

    expect(find.text('报销单u1'), findsOneWidget);
    expect(find.text('报销单u2'), findsOneWidget);

    await tester.drag(find.text('报销单u1'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('报销单u1'), findsNothing);
    expect(find.text('报销单u2'), findsOneWidget);
    expect(archived, ['u1']);
  });

  testWidgets('已报销 tab 右滑撤销归档：卡片消失且回调收到 id', (tester) async {
    final restored = <String>[];
    await _pump(
      tester,
      [_claim('a1', archived: true), _claim('a2', archived: true)],
      restoredLog: restored,
    );

    await tester.tap(find.text('已报销'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('报销单a1'), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(find.text('报销单a1'), findsNothing);
    expect(find.text('报销单a2'), findsOneWidget);
    expect(restored, ['a1']);
  });

  testWidgets('已报销 tab 左滑删除（二次确认）：卡片消失且回调收到 id', (tester) async {
    final deleted = <String>[];
    await _pump(
      tester,
      [_claim('a1', archived: true), _claim('a2', archived: true)],
      deletedLog: deleted,
    );

    await tester.tap(find.text('已报销'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('报销单a1'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    // 弹出二次确认框 → 点「删除」。
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(find.text('报销单a1'), findsNothing);
    expect(find.text('报销单a2'), findsOneWidget);
    expect(deleted, ['a1']);
  });

  testWidgets('两个 tab 的空态文案', (tester) async {
    await _pump(tester, []);

    expect(find.text('暂无未报销记录'), findsOneWidget);

    await tester.tap(find.text('已报销'));
    await tester.pumpAndSettle();

    expect(find.text('暂无已报销记录'), findsOneWidget);
  });

  // ==================== 以下为 QA 增补的对抗性 / 边界用例 ====================

  testWidgets('对抗1：tab 栏小幅拖动未过阈值 → 回弹且不触发 onChanged',
      (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(_TabHost(changes: changes));
    await tester.pumpAndSettle();

    final rest = tester.getRect(find.byType(SlidingPill));

    // 轨道宽 ≈ 760，半格 ≈ 190；拖 60px 且慢速（100px/s < 300px/s）→ 不切换。
    await tester.timedDrag(
      find.byType(SlidingSegmentedTabs),
      const Offset(60, 0),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();

    expect(changes, isEmpty, reason: '未过阈值不应触发 onChanged');
    final after = tester.getRect(find.byType(SlidingPill));
    expect(after.left, closeTo(rest.left, 0.5), reason: '胶囊应回弹到原位');
  });

  testWidgets('对抗2：tab 栏按住跟手拖动 → 胶囊实时跟随，松手落到目标段',
      (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(_TabHost(initialIndex: 1, changes: changes));
    await tester.pumpAndSettle();

    final track = tester.getRect(find.byType(SlidingSegmentedTabs));
    final rest1 = tester.getRect(find.byType(SlidingPill)).left;

    final g = await tester.startGesture(
      tester.getCenter(find.byType(SlidingSegmentedTabs)),
    );
    // 第一段位移被 drag-start 的 touch slop 吃掉（Flutter 既定行为），
    // 从第二段开始才计入跟手位移，故这里从第二段起采样。
    await g.moveBy(const Offset(-50, 0));
    await tester.pump();
    await g.moveBy(const Offset(-60, 0));
    await tester.pump();
    final mid1 = tester.getRect(find.byType(SlidingPill)).left;
    await g.moveBy(const Offset(-80, 0));
    await tester.pump();
    final mid2 = tester.getRect(find.byType(SlidingPill)).left;

    expect(mid1, lessThan(rest1 - 20), reason: '按住左移后胶囊应跟随左移');
    expect(mid2, lessThan(mid1 - 40), reason: '继续左移胶囊应继续跟随');
    expect(changes, isEmpty, reason: '未松手前不应触发切换');

    // 继续左移使累计位移过半格 → 松手切到 index 0。
    await g.moveBy(const Offset(-160, 0));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();

    expect(changes, [0], reason: '松手后应切到左段 index 0');
    final landed = tester.getRect(find.byType(SlidingPill)).left;
    expect(landed, lessThan(track.left + track.width / 2),
        reason: '胶囊应落到左段');
    expect(landed, lessThan(rest1 - 100), reason: '胶囊应从右段明显左移');
  });

  testWidgets('对抗3a：边界不越界（index 0 左拖 / index 1 右拖 均不回绕）',
      (tester) async {
    // index 0 朝左边界拖 → 不得回绕到最后一页。
    final c0 = <int>[];
    await tester.pumpWidget(_TabHost(key: const ValueKey('b0'), changes: c0));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byType(SlidingSegmentedTabs), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(c0, isEmpty, reason: 'index 0 左拖不得回绕到 index 1');

    // index 1 朝右边界拖 → 不得回绕到第一页。
    // 换 key 触发全新 State，避免复用上一段的 index=0。
    final c1 = <int>[];
    await tester.pumpWidget(
        _TabHost(key: const ValueKey('b1'), initialIndex: 1, changes: c1));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byType(SlidingSegmentedTabs), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(c1, isEmpty, reason: 'index 1 右拖不得回绕到 index 0');
  });

  testWidgets('对抗3b：方向语义 = 拖向右前进一格 / 拖向左后退一格',
      (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(_TabHost(changes: changes));
    await tester.pumpAndSettle();

    await tester.drag(
        find.byType(SlidingSegmentedTabs), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(changes, [1], reason: 'index 0 向右拖 → 前进到 index 1');

    await tester.drag(
        find.byType(SlidingSegmentedTabs), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(changes, [1, 0], reason: 'index 1 向左拖 → 后退到 index 0');
  });

  testWidgets('对抗4a：减少动态下 tab 点按/拖拽仍可切换且不卡死',
      (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(_TabHost(changes: changes, reduceMotion: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('已报销'));
    await tester.pumpAndSettle();
    expect(changes, [1], reason: '减少动态下点按仍应切换');

    await tester.tap(find.text('未报销'));
    await tester.pumpAndSettle();
    expect(changes, [1, 0]);

    await tester.drag(
        find.byType(SlidingSegmentedTabs), const Offset(320, 0));
    await tester.pumpAndSettle();
    expect(changes, [1, 0, 1], reason: '减少动态下拖拽仍应切换');
  });

  testWidgets('对抗4b：减少动态下整页 HistoryPage 切换正常（jumpToPage）',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: _Harness(
            initial: [_claim('u1'), _claim('a1', archived: true)],
            archivedLog: [],
            restoredLog: [],
            deletedLog: [],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('已报销'));
    await tester.pumpAndSettle();
    expect(find.text('报销单a1'), findsOneWidget);
    expect(find.text('报销单u1'), findsNothing);

    await tester.drag(find.text('未报销'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('报销单u1'), findsOneWidget,
        reason: '减少动态下拖 tab 仍应切回未报销');
  });

  testWidgets('对抗5：非卡片区域横滑 → PageView 翻页并反向同步 tab',
      (tester) async {
    await _pump(tester, [_claim('u1'), _claim('a1', archived: true)]);

    final pillBefore = tester.getRect(find.byType(SlidingPill)).left;

    // 在 PageView 中部（单张卡片下方的空白区，非卡片处）向左快滑翻页。
    await tester.timedDrag(
      find.byType(PageView),
      const Offset(-320, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();

    final pillAfter = tester.getRect(find.byType(SlidingPill)).left;
    expect(pillAfter, greaterThan(pillBefore + 100),
        reason: 'PageView 翻页后应反向同步 tab（胶囊移到右段）');
    expect(find.text('报销单a1'), findsOneWidget, reason: '应显示已报销列表');
    expect(find.text('报销单u1'), findsNothing);
  });

  testWidgets('对抗6：卡片上左滑触发归档但 tab 不应切换', (tester) async {
    final archived = <String>[];
    await _pump(tester, [_claim('u1'), _claim('u2')], archivedLog: archived);

    final pillBefore = tester.getRect(find.byType(SlidingPill)).left;

    await tester.drag(find.text('报销单u1'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(archived, ['u1'], reason: '卡片左滑应触发归档回调');
    expect(find.text('报销单u2'), findsOneWidget, reason: '仍停留在未报销 tab');
    expect(find.text('报销单u1'), findsNothing);
    final pillAfter = tester.getRect(find.byType(SlidingPill)).left;
    expect(pillAfter, closeTo(pillBefore, 0.5), reason: 'tab 不应因卡片横滑而切换');
  });

  testWidgets('对抗7：上层 setState 迁移 archived → 卡片在两 tab 间迁移',
      (tester) async {
    late StateSetter setState;
    var archived = false;
    final claim = _claim('u1');

    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, ss) {
            setState = ss;
            return HistoryPage(
              claims: [claim.copyWith(archived: archived)],
              onSaveClaim: (_) {},
              onArchiveClaim: (_) {},
              onRestoreClaim: (_) {},
              onDeleteClaim: (_) {},
            );
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('报销单u1'), findsOneWidget);

    setState(() => archived = true);
    await tester.pumpAndSettle();
    expect(find.text('报销单u1'), findsNothing, reason: '应从未报销 tab 消失');

    await tester.tap(find.text('已报销'));
    await tester.pumpAndSettle();
    expect(find.text('报销单u1'), findsOneWidget, reason: '应出现在已报销 tab');

    setState(() => archived = false);
    await tester.pumpAndSettle();
    expect(find.text('报销单u1'), findsNothing, reason: '应从已报销 tab 消失');

    await tester.tap(find.text('未报销'));
    await tester.pumpAndSettle();
    expect(find.text('报销单u1'), findsOneWidget, reason: '应回到未报销 tab');
  });

  testWidgets('对抗8：已报销左滑删除弹窗点「取消」→ 卡片仍在、onDelete 未调用',
      (tester) async {
    final deleted = <String>[];
    await _pump(tester, [_claim('a1', archived: true)], deletedLog: deleted);

    await tester.tap(find.text('已报销'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('报销单a1'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('删除报销单'), findsOneWidget, reason: '应弹出二次确认');

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('报销单a1'), findsOneWidget, reason: '取消后卡片仍在');
    expect(deleted, isEmpty, reason: '取消不应调用 onDelete');
  });

  testWidgets('对抗9：浅色 / 深色主题下渲染同一页面均无异常', (tester) async {
    for (final theme in [buildLightTheme(), buildDarkTheme()]) {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: _Harness(
            initial: [_claim('u1'), _claim('a1', archived: true)],
            archivedLog: [],
            restoredLog: [],
            deletedLog: [],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('报销单u1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('对抗10：卸载页面不抛异常（PageController/Ticker 已释放）',
      (tester) async {
    await _pump(tester, [_claim('u1'), _claim('a1', archived: true)]);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('对抗11：counts 等于两 tab 实际条目数', (tester) async {
    await _pump(tester, [
      _claim('u1'),
      _claim('u2'),
      _claim('a1', archived: true),
      _claim('a2', archived: true),
      _claim('a3', archived: true),
    ]);

    final tabs = find.byType(SlidingSegmentedTabs);
    expect(
      find.descendant(of: tabs, matching: find.text('2')),
      findsOneWidget,
      reason: '未报销应显示 2',
    );
    expect(
      find.descendant(of: tabs, matching: find.text('3')),
      findsOneWidget,
      reason: '已报销应显示 3',
    );
  });
}
