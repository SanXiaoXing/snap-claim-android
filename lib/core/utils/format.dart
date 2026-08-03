// 日期 / 金额 / 人民币大写格式化工具。
String _pad2(int n) => n.toString().padLeft(2, '0');

/// MM-DD，例如 07-15。
String fmtMd(DateTime d) => '${_pad2(d.month)}-${_pad2(d.day)}';

/// 紧凑日期（无分隔符），例如 20260701，用于报销单名称。
String fmtDateCompact(DateTime d) =>
    '${d.year}${_pad2(d.month)}${_pad2(d.day)}';

/// yyyy 年 M 月，例如 2026 年 7 月（月份不补零，与原型一致）。
String fmtYm(DateTime d) => '${d.year} 年 ${d.month} 月';

/// "MM-dd 保存"，例如 07-18 保存。
String fmtSaved(DateTime d) => '${_pad2(d.month)}-${_pad2(d.day)} 保存';

String _groupThousands(String intPart) =>
    intPart.replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',');

/// 带千分位与两位小数的金额，例如 ¥1,866.00。
String fmtMoney(num n) {
  final s = n.toStringAsFixed(2);
  final parts = s.split('.');
  return '¥${_groupThousands(parts[0])}.${parts[1]}';
}

/// 简写金额：保留最多两位小数、整数不带小数，例如 ¥1,866 / ¥3,261.50（用于卡片）。
String fmtMoneyShort(num n) {
  var s = n.toStringAsFixed(2);
  if (s.endsWith('.00')) {
    s = s.substring(0, s.length - 3);
  }
  final parts = s.split('.');
  return '¥${_groupThousands(parts[0])}${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// 将金额转为人民币大写，例如 壹仟捌佰陆拾陆元整。
String toChineseCurrency(num n) {
  const digits = '零壹贰叁肆伍陆柒捌玖';

  String intToChinese(int v) {
    if (v == 0) return '零';
    const u = ['', '拾', '佰', '仟'];
    const g = ['', '万', '亿'];
    String result = '';
    int groupIndex = 0;
    while (v > 0) {
      final group = v % 10000;
      v ~/= 10000;
      String groupStr = '';
      final digitsInGroup = [
        group ~/ 1000,
        (group ~/ 100) % 10,
        (group ~/ 10) % 10,
        group % 10,
      ];
      var started = false;
      for (var i = 0; i < 4; i++) {
        final d = digitsInGroup[i];
        if (d != 0) {
          groupStr += digits[d] + u[3 - i];
          started = true;
        } else if (started) {
          groupStr += '零';
          started = false;
        }
      }
      while (groupStr.endsWith('零')) {
        groupStr = groupStr.substring(0, groupStr.length - 1);
      }
      if (groupStr.isNotEmpty) {
        result = groupStr + g[groupIndex] + result;
      } else if (result.isNotEmpty && !result.startsWith('零')) {
        result = '零$result';
      }
      groupIndex++;
    }
    return result;
  }

  var integer = n.truncate();
  var dec = ((n - integer) * 100).round();
  if (dec >= 100) {
    integer += 1;
    dec -= 100;
  }

  final intPart = intToChinese(integer);
  String decPart;
  if (dec == 0) {
    decPart = '元整';
  } else {
    final jiao = dec ~/ 10;
    final fen = dec % 10;
    decPart = '元';
    if (jiao != 0) {
      decPart += '${digits[jiao]}角';
    } else if (fen != 0) {
      decPart += '零';
    }
    if (fen != 0) {
      decPart += '${digits[fen]}分';
    }
  }

  return '$intPart$decPart';
}
