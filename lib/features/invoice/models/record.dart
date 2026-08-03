// 报销明细记录模型与票据分类。
import 'package:flutter/material.dart';

/// 票据分类，对应原型中的火车 / 飞机 / 酒店 / 用车四类标签。
enum RecordCategory {
  train(
    label: '火车',
    icon: Icons.train,
    base: Color(0xFF3B82F6),
    lightFg: Color(0xFF2563EB),
    darkFg: Color(0xFF60A5FA),
  ),
  flight(
    label: '飞机',
    icon: Icons.flight,
    base: Color(0xFF8B5CF6),
    lightFg: Color(0xFF7C3AED),
    darkFg: Color(0xFFA78BFA),
  ),
  hotel(
    label: '酒店',
    icon: Icons.hotel_outlined,
    base: Color(0xFFF59E0B),
    lightFg: Color(0xFFD97706),
    darkFg: Color(0xFFFBBF24),
  ),
  car(
    label: '用车',
    icon: Icons.directions_car,
    base: Color(0xFF10B981),
    lightFg: Color(0xFF059669),
    darkFg: Color(0xFF34D399),
  );

  final String label;
  final IconData icon;
  final Color base;
  final Color lightFg;
  final Color darkFg;

  const RecordCategory({
    required this.label,
    required this.icon,
    required this.base,
    required this.lightFg,
    required this.darkFg,
  });

  /// 图标底色（半透明品牌色）。
  Color iconBg(Brightness b) =>
      base.withValues(alpha: b == Brightness.dark ? 0.18 : 0.12);

  /// 图标前景色，原型中两类主题均使用品牌色。
  Color iconFg(Brightness b) => base;

  /// 徽章底色。
  Color badgeBg(Brightness b) =>
      base.withValues(alpha: b == Brightness.dark ? 0.22 : 0.12);

  /// 徽章文字色，深色主题下使用更亮的色调以保证对比度。
  Color badgeFg(Brightness b) =>
      b == Brightness.dark ? darkFg : lightFg;

  /// 徽章描边色。
  Color badgeBorder(Brightness b) =>
      base.withValues(alpha: b == Brightness.dark ? 0.35 : 0.22);
}

/// 用车行程类型：市内交通 / 往返交通（仅用车记录有意义）。
enum CarTripType {
  city(label: '市内交通'),
  roundTrip(label: '往返交通');

  final String label;

  const CarTripType({required this.label});
}

/// 一条报销明细。
@immutable
class Record {
  final String id;
  final RecordCategory category;
  final String title;
  final String subtitle;
  final double amount;

  /// 用车行程类型（市内/往返）；仅 [RecordCategory.car] 记录有意义，
  /// 为 null 或 city 时计入「市内交通」汇总，roundTrip 计入「往返交通」。
  final CarTripType? carTripType;

  const Record({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.carTripType,
  });

  /// 是否计入「往返交通」汇总。
  bool get isRoundTripCar =>
      category == RecordCategory.car && carTripType == CarTripType.roundTrip;
}

int _recordIdSeq = 0;

/// 生成唯一记录 id：毫秒时间戳 + 进程内递增序号。
/// 避免同一毫秒批量创建明细（如 OCR 多订单一次识别多条）时 id 重复，
/// 否则按 id 删除一条会误删全部同 id 记录。
String nextRecordId() =>
    '${DateTime.now().millisecondsSinceEpoch}-${_recordIdSeq++}';
