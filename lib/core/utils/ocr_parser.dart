/// OCR 文本的结构化解析，不依赖平台或原生库。
class OcrParseResult {
  final bool ok;
  final String? category;
  final String? title;
  final String? subtitle;
  final double? amount;

  const OcrParseResult({
    required this.ok,
    this.category,
    this.title,
    this.subtitle,
    this.amount,
  });
}

class ImageHint {
  final String orderType;
  final String orderId;
  final double? amount;

  const ImageHint({
    required this.orderType,
    required this.orderId,
    this.amount,
  });
}

const _categories = <String, List<String>>{
  'train': ['火车', '高铁', '动车', '铁路', '12306', '车次'],
  'flight': ['机票', '航空', '客票', '航班', '登机', '航段'],
  'hotel': ['酒店', '住宿', '房费', '入住', '旅馆'],
  'car': ['出租车', '网约车', '滴滴', '打车', '起步价', '用车'],
  'highway': ['高速', '通行费', '过路费', '收费站'],
  'subway': ['地铁', '轨道交通'],
};

const _labels = <String, String>{
  'train': '火车票',
  'flight': '机票',
  'hotel': '酒店住宿',
  'car': '出租车',
  'highway': '高速通行费',
  'subway': '地铁票',
};

OcrParseResult parseOcrText(String text) {
  if (text.trim().isEmpty) return const OcrParseResult(ok: false);
  String? category;
  for (final entry in _categories.entries) {
    if (entry.value.any(text.contains)) {
      category = entry.key;
      break;
    }
  }
  final amount = _lastAmount(text);
  final ok = amount != null || category != null;
  if (!ok) return const OcrParseResult(ok: false);

  final label = _labels[category] ?? '票据';
  final date = _extractDate(text);
  final subtitle = [
    if (category != null) label,
    ?date,
  ].join(' ');
  return OcrParseResult(
    ok: true,
    category: category,
    title: _extractRoute(text) ?? _extractStationRoute(text) ?? label,
    subtitle: subtitle,
    amount: amount,
  );
}

/// 订单号与金额各按出现顺序配对，兼容 OCR 把金额集中输出在文末的截图。
List<ImageHint> extractAllOrderHints(String text) {
  final orders = RegExp(r'[A-Z]{2}[0-9]{14,22}').allMatches(text).where((
    match,
  ) {
    return (match.start == 0 ||
            !_isAsciiWord(text.codeUnitAt(match.start - 1))) &&
        (match.end == text.length || !_isAsciiWord(text.codeUnitAt(match.end)));
  }).toList();
  if (orders.isEmpty) return const [];
  final amounts = _amountCandidates(text);
  final hints = <ImageHint>[];
  for (var i = 0; i < orders.length; i++) {
    final id = orders[i].group(0)!;
    final type = switch (id.substring(0, 2)) {
      'DC' => 'car',
      'DF' => 'flight',
      'HO' => 'hotel',
      _ => null,
    };
    if (type != null) {
      hints.add(
        ImageHint(
          orderType: type,
          orderId: id,
          amount: i < amounts.length ? amounts[i].value : null,
        ),
      );
    }
  }
  return hints;
}

typedef _Amount = ({double value, bool prefixed});

List<_Amount> _amountCandidates(String text) {
  final results = <_Amount>[];
  var i = 0;
  while (i < text.length) {
    final prefix = text[i];
    final prefixed =
        prefix == '¥' || prefix == '￥' || prefix == 'x' || prefix == 'X';
    if (!prefixed && !_isDigit(text.codeUnitAt(i))) {
      i++;
      continue;
    }
    var end = prefixed ? i + 1 : i;
    while (prefixed && end < text.length && text[end].trim().isEmpty) {
      end++;
    }
    final start = end;
    while (end < text.length &&
        (_isDigit(text.codeUnitAt(end)) ||
            text[end] == ',' ||
            text[end] == '.')) {
      end++;
    }
    if (end > start &&
        (end == text.length || (text[end] != '-' && text[end] != '/'))) {
      final number = text.substring(start, end).replaceAll(',', '');
      final value = double.tryParse(number);
      if (value != null &&
          value >= 0.01 &&
          value <= 100000 &&
          (prefixed ||
              number.contains('.') ||
              (value >= 100 && (value < 1900 || value > 2099)))) {
        results.add((value: value, prefixed: prefixed));
      }
    }
    i = end > i ? end : i + 1;
  }
  return results;
}

double? _lastAmount(String text) {
  final candidates = _amountCandidates(text);
  for (final item in candidates.reversed) {
    if (item.prefixed) return item.value;
  }
  return candidates.isEmpty ? null : candidates.last.value;
}

String? _extractDate(String text) {
  for (final match in RegExp(
    r'([0-9]{4})[-/年]([0-9]{1,2})[-/月日]([0-9]{1,2})',
  ).allMatches(text)) {
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (year >= 1900 &&
        year <= 2100 &&
        month >= 1 &&
        month <= 12 &&
        day >= 1 &&
        day <= 31) {
      return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    }
  }
  return null;
}

String? _extractRoute(String text) {
  for (final match in RegExp(
    r'([\u4e00-\u9fff]+)(?:→|->|至)([\u4e00-\u9fff]+)',
  ).allMatches(text)) {
    final from = match.group(1)!;
    final to = match.group(2)!;
    if (from.length >= 2 && to.length >= 2) return '$from→$to';
  }
  return null;
}

String? _extractStationRoute(String text) {
  final stations = RegExp(r'[\u4e00-\u9fff]+')
      .allMatches(text)
      .map((match) => match.group(0)!)
      .where((word) => word.length >= 3 && word.endsWith('站'))
      .take(2)
      .toList();
  return stations.length == 2 ? '${stations[0]}→${stations[1]}' : null;
}

bool _isDigit(int value) => value >= 48 && value <= 57;
bool _isAsciiWord(int value) =>
    _isDigit(value) ||
    (value >= 65 && value <= 90) ||
    (value >= 97 && value <= 122) ||
    value == 95;
