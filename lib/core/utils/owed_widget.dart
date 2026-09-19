// 桌面「公司欠我」金额小组件数据层。
import '../../features/invoice/models/claim.dart';

/// 未归档报销单退补金额合计（公司欠我）。
double owedTotal(List<Claim> claims) {
  var sum = 0.0;
  for (final claim in claims) {
    if (claim.archived) continue;
    sum += claim.balanceAmount;
  }
  return sum;
}

/// 解析小组件启动 URI 为入口 action 字符串；非本协议返回 null。
/// 格式：`snapclaim://entry/open_mine` / `edit_claim/<id>` 等。
String? parseHomeWidgetEntryUri(Uri? uri) {
  if (uri == null) return null;
  if (uri.scheme != 'snapclaim' || uri.host != 'entry') return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  final head = segments.first;
  if (head == 'edit_claim') {
    if (segments.length < 2 || segments[1].isEmpty) return null;
    return 'edit_claim:${segments[1]}';
  }
  return head;
}
