// 我的：统计概览 + 偏好设置 + 关于，对应原型 05 屏。
// 页面业务逻辑集中于此；卡片/行/开关等展示组件见 settings/widgets/。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/cache.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ocr.dart';
import '../../../core/utils/qr_parser.dart';
import '../../invoice/models/claim.dart';
import '../../invoice/pages/qr_scanner_page.dart';
import '../../invoice/widgets/app_top_bar.dart';
import '../widgets/mine_cache_trailing.dart';
import '../widgets/mine_info_line.dart';
import '../widgets/mine_owed_card.dart';
import '../widgets/mine_result_line.dart';
import '../widgets/mine_row.dart';
import '../widgets/mine_stat_cell.dart';
import 'stats_page.dart';

class MinePage extends StatefulWidget {
  final List<Claim> claims;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChangeThemeMode;

  const MinePage({
    super.key,
    required this.claims,
    required this.themeMode,
    required this.onChangeThemeMode,
  });

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // 从真实数据计算统计。
    final now = DateTime.now();
    final monthClaims = widget.claims
        .where((cl) =>
            cl.startDate.year == now.year && cl.startDate.month == now.month)
        .toList();
    // 本月报销 = 本月报销单的退补金额之和（退补金额 = 火车 + 差补）。
    final monthBalance =
        monthClaims.fold(0.0, (s, cl) => s + cl.balanceAmount);
    final monthRecords =
        monthClaims.fold(0, (s, cl) => s + cl.records.length);
    // 累计报销 = 全部报销单的退补金额之和。
    final totalBalance =
        widget.claims.fold(0.0, (s, cl) => s + cl.balanceAmount);
    final allRecords =
        widget.claims.fold(0, (s, cl) => s + cl.records.length);

    // 公司欠款 = 未报销（未归档）报销单的退补金额之和（退补金额 = 火车 + 差补）。
    final owedTotal = widget.claims
        .where((cl) => !cl.archived)
        .fold(0.0, (s, cl) => s + cl.balanceAmount);

    return Column(
      children: [
        AppTopBar(title: '我的'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            child: Column(
              children: [
                // 公司还欠我。
                OwedCard(total: owedTotal),
                const SizedBox(height: 16),
                // 统计概览。
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(c),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '统计概览',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.fg,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${now.year} 年度',
                            style: TextStyle(fontSize: 12, color: c.fgMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          StatCell(
                            label: '本月报销',
                            value: fmtMoney(monthBalance),
                            foot: '共 ${monthClaims.length} 张',
                          ),
                          const SizedBox(width: 10),
                          StatCell(
                            label: '本月单据',
                            value: '${monthClaims.length} 张',
                            foot: '$monthRecords 条明细',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          StatCell(
                            label: '累计报销',
                            value: fmtMoney(totalBalance),
                            foot: '共 ${widget.claims.length} 张',
                          ),
                          const SizedBox(width: 10),
                          StatCell(
                            label: '累计明细',
                            value: '$allRecords 条',
                            foot: '${widget.claims.length} 张报销单',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 统计 / 深色模式。
                Container(
                  decoration: cardDecoration(c),
                  child: Column(
                    children: [
                      MineRow(
                        icon: Icons.pie_chart_outline,
                        title: '报销统计',
                        subtitle: '查看月度/年度汇总',
                        trailing: Icon(Icons.chevron_right, size: 18, color: c.fgSoft),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StatsPage(claims: widget.claims),
                          ),
                        ),
                      ),
                      MineDivider(),
                      MineRow(
                        icon: Icons.brightness_6_outlined,
                        title: '外观模式',
                        subtitle: _themeModeLabel(widget.themeMode),
                        trailing: Icon(Icons.chevron_right, size: 18, color: c.fgSoft),
                        onTap: _pickThemeMode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 偏好设置。
                Container(
                  decoration: cardDecoration(c),
                  child: Column(
                    children: [
                      MineHeader(icon: Icons.tune, title: '偏好设置'),
                      MineDivider(),
                      MineRow(
                        icon: Icons.image_outlined,
                        title: '发票识别',
                        subtitle: '拍照 / 相册识别票据',
                        trailing: Icon(Icons.chevron_right, size: 18, color: c.fgSoft),
                        onTap: _ocrRecognize,
                      ),
                      MineDivider(),
                      MineRow(
                        icon: Icons.qr_code_scanner,
                        title: '二维码扫描',
                        subtitle: '扫码快速录入票据',
                        trailing: Icon(Icons.chevron_right, size: 18, color: c.fgSoft),
                        onTap: _scanQr,
                      ),
                      MineDivider(),
                      MineRow(
                        icon: Icons.delete_outline,
                        title: '清除缓存',
                        subtitle: '释放本地存储空间',
                        trailing: CacheTrailing(),
                        onTap: () => _showClearCacheDialog(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 版本信息。
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(c),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '版本信息',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.fg,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'v1.0.0',
                            style: TextStyle(fontSize: 12, color: c.fgMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      MineInfoLine(label: '作者', value: 'SanXiaoXing'),
                      const SizedBox(height: 6),
                      MineInfoLine(label: '版权', value: '© 2026 SanXiaoXing 保留所有权利'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 打开扫码页；扫到可识别的票据明细则展示预览，否则展示原始内容。
  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<QrParseResult>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (!mounted || result == null) return;
    _showScanResult(result);
  }

  /// 拍照 / 相册识别票据；结构化解析成功则展示字段预览，否则展示原文。
  Future<void> _ocrRecognize() async {
    final result = await pickImageAndOcr(context);
    if (!mounted || result == null) return;
    if (result.error != null) {
      _snack(result.error!);
      return;
    }
    if (result.raw.isEmpty) {
      _snack('未识别到文字，请换一张清晰的票据照片');
      return;
    }
    _showOcrResult(result);
  }

  void _snack(String msg) {
    showAppSnack(context, msg);
  }

  /// 外观模式三态选择（跟随系统 / 浅色 / 深色），选中后立即生效并持久化。
  Future<void> _pickThemeMode() async {
    final c = context.colors;
    final current = widget.themeMode;
    final picked = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '外观模式',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.fg,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeMode.values) ...[
              _ThemeOptionRow(
                label: _themeModeLabel(mode),
                selected: mode == current,
                onTap: () => Navigator.of(ctx).pop(mode),
              ),
            ],
          ],
        ),
      ),
    );
    if (picked != null && picked != current) {
      widget.onChangeThemeMode(picked);
    }
  }

  static String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
  }

  /// 清除缓存：先查询大小 → 确认对话框 → 清除 → 反馈释放量。
  Future<void> _showClearCacheDialog(BuildContext context) async {
    final sizeStr = await cacheSizeFormatted();
    if (!context.mounted) return;
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '清除缓存',
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
              '当前缓存大小：$sizeStr',
              style: TextStyle(fontSize: 14, color: c.fg),
            ),
            const SizedBox(height: 8),
            Text(
              '清除图片识别、扫码等产生的临时文件，'
              '不会删除已保存的报销单数据。',
              style: TextStyle(fontSize: 12, color: c.fgMuted, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消', style: TextStyle(fontSize: 14, color: c.fgMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final freed = await clearCache();
    if (!context.mounted) return;
    showAppSnack(context, '已清除缓存，释放 ${formatBytes(freed)}',
        background: c.accent);
    setState(() {}); // 刷新 CacheTrailing 显示
  }

  /// 展示识别 / 扫码结果：有明细时按分组字段行展示，否则展示原始内容。
  void _showRecordResultDialog(
    String title,
    List<List<(String, String)>> groups, {
    String? raw,
  }) {
    final c = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.fg,
          ),
        ),
        content: groups.isEmpty
            ? Text(
                raw ?? '',
                style: TextStyle(fontSize: 14, color: c.fgMuted, height: 1.5),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var g = 0; g < groups.length; g++) ...[
                    for (final (label, value) in groups[g]) ...[
                      ResultLine(label: label, value: value),
                      const SizedBox(height: 8),
                    ],
                    if (g < groups.length - 1) ...[
                      Divider(height: 1, color: c.border),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
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

  void _showOcrResult(OcrResult result) {
    _showRecordResultDialog(
      '识别结果（${result.records.length} 条）',
      [
        for (final r in result.records)
          [
            ('类别', r.category.label),
            ('名称', r.title),
            ('金额', fmtMoney(r.amount)),
          ],
      ],
      raw: result.raw,
    );
  }

  void _showScanResult(QrParseResult result) {
    final rec = result.record;
    _showRecordResultDialog(
      '扫码结果',
      rec == null
          ? const <List<(String, String)>>[]
          : [
              [
                ('类别', rec.category.label),
                ('名称', rec.title),
                ('备注', rec.subtitle),
                ('金额', fmtMoney(rec.amount)),
              ],
            ],
      raw: result.raw,
    );
  }
}

/// 外观模式选择对话框里的单行选项：左侧名称，右侧选中态圆点。
class _ThemeOptionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: c.fg),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 20,
              color: selected ? c.accent : c.fgSoft,
            ),
          ],
        ),
      ),
    );
  }
}
