// 报销单编辑页：表单 + 汇总 + 明细（左滑删除）+ 追加记录 FAB。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/allowance.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ocr.dart';
import '../../../core/utils/qr_parser.dart';
import '../models/claim.dart';
import '../models/record.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/chips.dart';
import '../widgets/empty_hint.dart';
import '../widgets/fab_menu.dart';
import '../widgets/field_widgets.dart';
import '../widgets/ocr_preview_dialog.dart';
import '../widgets/record_row.dart';
import '../widgets/summary_card.dart';
import 'qr_scanner_page.dart';

class EditorPage extends StatefulWidget {
  final Claim claim;
  final ValueChanged<Claim> onSave;

  /// 退出时是否强制弹「保存 / 不保存 / 取消」确认。
  /// 系统分享直达创建的新报销单已预填 OCR 明细，但尚未持久化：
  /// _isDirty 与初始值一致会被误判为"无修改"而直接放行返回，
  /// 故开启本开关，让干净状态下的返回也走保存确认，避免数据静默丢失。
  final bool promptSaveOnExit;

  const EditorPage({
    super.key,
    required this.claim,
    required this.onSave,
    this.promptSaveOnExit = false,
  });

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final TextEditingController _nameCtrl;
  late DateTime _start;
  late DateTime _end;
  late List<Record> _records;
  // 差补金额由 Rust 核心库异步计算，算好后缓存到此供 _buildCurrent 同步取用。
  late double _allowance;
  // 名称是否自动跟随日期（新建时默认为日期范围，未被手动修改）。
  bool _nameAuto = false;
  // 初始名称（用于脏值判断：与 _nameCtrl 文本比对）。
  late final String _initialName;
  // 显式跳过后续 Pop 拦截（保存 / 丢弃路径），避免保存后又被回弹拦下。
  bool _skipPopGuard = false;

  @override
  void initState() {
    super.initState();
    _start = widget.claim.startDate;
    _end = widget.claim.endDate;
    _records = [...widget.claim.records];
    // 新建报销单：名称默认为「起始日期-结束日期」（如 20260701-20260723）。
    // 注意：_fmtDateRange 依赖 _start/_end，须在日期初始化之后调用。
    if (widget.claim.name.isEmpty) {
      _nameAuto = true;
      _initialName = _fmtDateRange();
    } else {
      _initialName = widget.claim.name;
    }
    _nameCtrl = TextEditingController(text: _initialName);
    // 先用既有报销单存的差补作为初值，避免首帧闪烁；再异步重算。
    _allowance = widget.claim.allowance;
    _refreshAllowance();
  }

  /// 名称的日期范围格式：起始日期-结束日期。
  String _fmtDateRange() => '${fmtDateCompact(_start)}-${fmtDateCompact(_end)}';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Claim _buildCurrent() => widget.claim.copyWith(
        name: _nameCtrl.text.trim().isEmpty
            ? _fmtDateRange()
            : _nameCtrl.text.trim(),
        startDate: _start,
        endDate: _end,
        records: _records,
        allowance: _allowance,
        savedAt: DateTime.now(),
      );

  /// 调用 Rust 核心库重算差补并刷新界面。
  Future<void> _refreshAllowance() async {
    final a = await perDiemAllowance(_start, _end);
    if (!mounted) return;
    setState(() => _allowance = a);
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
        if (_start.isAfter(picked)) _start = picked;
      }
      // 名称未被手动修改时，跟随新的日期范围。
      if (_nameAuto) {
        _nameCtrl.text = _fmtDateRange();
      }
    });
    _refreshAllowance();
  }

  void _save() {
    widget.onSave(_buildCurrent());
    // 跳过后续 Pop 拦截，避免 _save 已经 pop 时再次被回弹拦下。
    _skipPopGuard = true;
    // 返回 true 告知调用方：本次编辑确实保存了修改。
    Navigator.of(context).pop(true);
  }

  /// 当前表单相对原始报销单是否被修改：
  /// 比较名称、起止日期、明细数量与每条明细的关键字段。
  bool get _isDirty {
    if (_nameCtrl.text != _initialName) return true;
    if (_start != widget.claim.startDate) return true;
    if (_end != widget.claim.endDate) return true;
    final orig = widget.claim.records;
    if (_records.length != orig.length) return true;
    for (var i = 0; i < _records.length; i++) {
      final c = _records[i];
      final o = orig[i];
      if (c.id != o.id ||
          c.amount != o.amount ||
          c.category != o.category ||
          c.carTripType != o.carTripType) {
        return true;
      }
    }
    return false;
  }

  /// 处理退出请求：脏状态（或 [promptSaveOnExit] 强制）下弹
  /// 「保存 / 不保存 / 取消」对话框，由用户决定保存、丢弃修改或留在页面。
  Future<void> _handleBack() async {
    if (!widget.promptSaveOnExit && !_isDirty) {
      // 未做修改直接退出：返回 false，调用方（详情页）应留在原地。
      Navigator.of(context).pop(false);
      return;
    }
    final action = await showDialog<_ExitAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ExitConfirmDialog(),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _ExitAction.save:
        // 走 _save，逻辑同顶部「保存」按钮：保存数据并 pop。
        _save();
      case _ExitAction.discard:
        // 丢弃修改直接退出，跳过 Pop 拦截。
        _skipPopGuard = true;
        Navigator.of(context).pop(false);
      case _ExitAction.cancel:
        // 留在当前页，什么也不做。
        break;
    }
  }

  void _fabAction(String label) {
    switch (label) {
      case '扫码添加':
        _scanToAdd();
      case '上传图片':
        _ocrToAdd();
      case '手动添加':
        _manualAdd();
      default:
        _notReady(label);
    }
  }

  /// 手动添加明细：选择类型 → 输入金额 → 追加到当前报销单。
  Future<void> _manualAdd() async {
    final record = await showDialog<Record>(
      context: context,
      builder: (_) => const _ManualAddDialog(),
    );
    if (!mounted || record == null) return;
    setState(() => _records = [..._records, record]);
    _toast('已添加：${record.category.label} ${fmtMoney(record.amount)}');
  }

  /// 打开扫码页，扫到可识别的票据明细则追加到当前报销单。
  Future<void> _scanToAdd() async {
    final result = await Navigator.of(context).push<QrParseResult>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (!mounted || result == null) return;
    if (result.record != null) {
      setState(() => _records = [..._records, result.record!]);
      _toast('已添加：${result.record!.title}');
    } else {
      _showRawContent(result.raw);
    }
  }

  /// 拍照 / 选图走 OCR 识别，弹可编辑预览，确认后追加到当前报销单。
  Future<void> _ocrToAdd() async {
    final result = await pickImageAndOcr(context);
    if (!mounted || result == null) return;
    if (result.error != null) {
      _toast(result.error!);
      return;
    }
    if (result.records.isEmpty) {
      _toast('未识别到票据信息，请换一张清晰的截图');
      return;
    }
    final added = await showDialog<List<Record>>(
      context: context,
      builder: (_) => OcrPreviewDialog(initial: result.records),
    );
    if (!mounted || added == null || added.isEmpty) return;
    setState(() => _records = [..._records, ...added]);
    _toast('已添加 ${added.length} 条明细');
  }

  void _showRawContent(String raw) {
    final c = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '扫码结果',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.fg,
          ),
        ),
        content: Text(
          raw,
          style: TextStyle(fontSize: 14, color: c.fgMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('关闭', style: TextStyle(fontSize: 14, color: c.fgMuted)),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    showAppSnack(context, msg, ms: 1200);
  }

  void _notReady(String label) {
    _toast('$label功能开发中');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = _buildCurrent();
    final counts = current.tagCounts;
    // 拦截系统返回 / 手势返回：未改动且未强制确认时直接放行，
    // 否则走 _handleBack 弹确认框（脏状态或分享直达的新单）。
    return PopScope(
      canPop: _skipPopGuard || (!widget.promptSaveOnExit && !_isDirty),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: [
            Column(
              children: [
                AppTopBar(
                  leading: AppIconButton(
                    icon: Icons.chevron_left,
                    onTap: _handleBack,
                  ),
                  title: '报销单',
                  trailing: AppTextButton(label: '保存', onTap: _save),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 表单卡片。
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: cardDecoration(c),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FieldLabel('报销单名称'),
                            TextField(
                              controller: _nameCtrl,
                              onChanged: (v) {
                                // 用户手动编辑名称后，不再自动跟随日期。
                                if (v.trim() != _fmtDateRange()) {
                                  _nameAuto = false;
                                }
                              },
                              style: TextStyle(
                                fontSize: 15,
                                color: c.fg,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: '请输入报销单名称',
                                hintStyle: TextStyle(color: c.fgSoft),
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: c.border),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: c.accent, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FieldLabel('出差日期'),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                DatePill(
                                  date: _start,
                                  label: '开始',
                                  onTap: () => _pickDate(true),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Icon(Icons.arrow_forward,
                                      size: 14, color: c.fgSoft),
                                ),
                                DatePill(
                                  date: _end,
                                  label: '结束',
                                  onTap: () => _pickDate(false),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SummaryCard(claim: current),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            '明细记录（${_records.length}）',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.fg,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '左滑删除',
                            style: TextStyle(fontSize: 10, color: c.fgSoft),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TagSummary(counts: counts),
                      if (_records.isEmpty)
                        EmptyHint(
                          icon: Icons.receipt_long_outlined,
                          text: '暂无明细，点击右下角按钮添加',
                          card: true,
                        )
                      else
                        Column(
                          children: [
                            for (var i = 0; i < _records.length; i++) ...[
                              DismissibleRecordRow(
                                record: _records[i],
                                dismissKey: ValueKey(_records[i].id),
                                onDismissed: () => setState(() => _records
                                    .removeWhere((e) => e.id == _records[i].id)),
                                // 仅用车记录支持右滑切换市内/往返交通。
                                onTripTypeChanged:
                                    _records[i].category == RecordCategory.car
                                        ? (t) => setState(() {
                                              final r = _records[i];
                                              _records[i] = Record(
                                                id: r.id,
                                                category: r.category,
                                                title: r.title,
                                                subtitle: r.subtitle,
                                                amount: r.amount,
                                                carTripType: t,
                                              );
                                            })
                                        : null,
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          FabMenu(
            items: const [
              FabMenuItem(icon: Icons.qr_code_scanner, label: '扫码添加'),
              FabMenuItem(icon: Icons.image_outlined, label: '上传图片'),
              FabMenuItem(icon: Icons.edit_outlined, label: '手动添加'),
            ],
            onAction: _fabAction,
          ),
        ],
      ),
      ),
    );
  }
}

/// 手动添加明细对话框：选择类型 + 输入金额（用车可选市内/往返）。
class _ManualAddDialog extends StatefulWidget {
  const _ManualAddDialog();

  @override
  State<_ManualAddDialog> createState() => _ManualAddDialogState();
}

class _ManualAddDialogState extends State<_ManualAddDialog> {
  RecordCategory _category = RecordCategory.train;
  CarTripType _carTripType = CarTripType.city;
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;
    Navigator.of(context).pop(Record(
      id: nextRecordId(),
      category: _category,
      title: _category.label,
      subtitle: '',
      amount: amount,
      carTripType: _category == RecordCategory.car ? _carTripType : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        '手动添加',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: c.fg,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择类型',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.fgMuted),
          ),
          const SizedBox(height: 10),
          // 类型选择网格。
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in RecordCategory.values)
                GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _category == cat ? cat.base : c.bgSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _category == cat ? cat.base : c.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon, size: 16,
                            color: _category == cat ? Colors.white : c.fgMuted),
                        const SizedBox(width: 4),
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _category == cat ? Colors.white : c.fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          // 用车可选市内/往返。
          if (_category == RecordCategory.car) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (final t in CarTripType.values) ...[
                  CarTripChip(
                    label: t.label,
                    selected: _carTripType == t,
                    onTap: () => setState(() => _carTripType = t),
                  ),
                  if (t != CarTripType.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '金额',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.fgMuted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: TextStyle(fontSize: 15, color: c.fg),
            decoration: ocrInputDecoration(c, hint: '请输入金额'),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消', style: TextStyle(fontSize: 14, color: c.fgMuted)),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('添加'),
        ),
      ],
    );
  }
}

/// 退出编辑时的用户选择：保存修改 / 丢弃修改 / 留在页面。
enum _ExitAction { save, discard, cancel }

/// 脏状态下退出编辑的确认对话框：
/// - 不保存：直接退出，修改丢弃。
/// - 取消：留在当前页继续编辑。
/// - 保存：保存修改后退出。
class _ExitConfirmDialog extends StatelessWidget {
  const _ExitConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        '保存修改？',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: c.fg,
        ),
      ),
      content: Text(
        '当前报销单有未保存的修改，是否保存？',
        style: TextStyle(fontSize: 14, color: c.fgMuted, height: 1.5),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ExitAction.discard),
          child: Text('不保存', style: TextStyle(fontSize: 14, color: c.fgMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ExitAction.cancel),
          child: Text('取消', style: TextStyle(fontSize: 14, color: c.fgMuted)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ExitAction.save),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

