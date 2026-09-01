// OCR 结果的可编辑预览对话框：展示识别出的全部明细
// （每行金额可编辑、可删行），确认后一次性追加。
// 供编辑页「上传图片」与系统分享面板直达（分享图片 → OCR）共用。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../models/record.dart';
import 'chips.dart';
import 'press_scale.dart';

/// OCR 识别结果预览对话框；确认后返回用户保留的明细列表
/// （金额可编辑、可删行），返回 null 表示用户取消。
class OcrPreviewDialog extends StatefulWidget {
  final List<Record> initial;

  const OcrPreviewDialog({super.key, required this.initial});

  @override
  State<OcrPreviewDialog> createState() => _OcrPreviewDialogState();
}

/// 待确认明细草稿（订单号只读，金额可编辑；用车可切换市内/往返）。
class _OcrDraft {
  final RecordCategory category;
  final String title;
  final TextEditingController amountCtrl;

  /// 用车行程类型（仅用车有意义），预览中可切换。
  CarTripType? carTripType;

  _OcrDraft({
    required this.category,
    required this.title,
    required String amount,
    this.carTripType,
  }) : amountCtrl = TextEditingController(text: amount);
}

class _OcrPreviewDialogState extends State<OcrPreviewDialog> {
  late final List<_OcrDraft> _drafts;

  @override
  void initState() {
    super.initState();
    _drafts = [
      for (final r in widget.initial)
        _OcrDraft(
          category: r.category,
          title: r.title,
          amount: r.amount > 0 ? _fmtAmount(r.amount) : '',
          // 用车默认市内交通，可在预览中切换为往返。
          carTripType: r.carTripType ??
              (r.category == RecordCategory.car ? CarTripType.city : null),
        ),
    ];
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.amountCtrl.dispose();
    }
    super.dispose();
  }

  static String _fmtAmount(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void _confirm() {
    final records = [
      for (final d in _drafts)
        Record(
          id: nextRecordId(),
          category: d.category,
          title: d.title,
          subtitle: '',
          amount: (double.tryParse(d.amountCtrl.text.trim()) ?? 0.0)
              .clamp(0.0, double.infinity)
              .toDouble(),
          carTripType:
              d.category == RecordCategory.car ? d.carTripType : null,
        ),
    ];
    Navigator.of(context).pop(records);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '识别结果（${_drafts.length} 条）',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _drafts.length; i++) ...[
              _OcrDraftRow(
                draft: _drafts[i],
                onRemove: _drafts.length > 1
                    ? () => setState(() => _drafts.removeAt(i))
                    : null,
                onTripTypeChanged: (t) =>
                    setState(() => _drafts[i].carTripType = t),
              ),
              if (i < _drafts.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
      actions: [
        appDialogButton(context),
        FilledButton(
          onPressed: _confirm,
          child: Text('添加 ${_drafts.length} 条'),
        ),
      ],
    );
  }
}

/// 单条明细行：类型徽章 + 订单号 + 金额输入 +（用车时）市内/往返切换 + 删除按钮。
class _OcrDraftRow extends StatelessWidget {
  final _OcrDraft draft;
  final VoidCallback? onRemove;
  final ValueChanged<CarTripType>? onTripTypeChanged;

  const _OcrDraftRow({
    required this.draft,
    this.onRemove,
    this.onTripTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      decoration: BoxDecoration(
        color: c.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          CategoryBadge(category: draft.category),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.fg,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: draft.amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 13, color: c.fg),
                  decoration: ocrInputDecoration(c, hint: '金额'),
                ),
                // 用车记录可选择市内交通 / 往返交通。
                if (draft.category == RecordCategory.car) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final t in CarTripType.values) ...[
                        CarTripChip(
                          label: t.label,
                          selected: draft.carTripType == t,
                          onTap: () => onTripTypeChanged?.call(t),
                        ),
                        if (t != CarTripType.values.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: c.fgSoft),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// 用车行程类型选择胶囊（市内交通 / 往返交通），选中态使用用车品牌色。
class CarTripChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CarTripChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = RecordCategory.car.base;
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? base : c.bgSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? base : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : c.fgMuted,
          ),
        ),
      ),
    );
  }
}

/// OCR 金额输入框样式（预览行 / 手动添加共用）。
InputDecoration ocrInputDecoration(AppColorScheme c, {required String hint}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.fgSoft),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
    );
