//! 二维码内容解析：将扫到的文本解析为报销明细字段。
//! 支持两种编码：
//!  1. JSON：{"category":"train","title":"...","subtitle":"...","amount":553}
//!  2. 竖线分隔：train|G123 北京南→上海虹桥|二等座|553
//! 无法识别时回退为纯文本，ok=false，调用方据 raw 展示。

/// 二维码解析结果。
#[derive(Clone, Debug)]
pub struct QrParseResult {
    /// 是否成功解析为明细。
    pub ok: bool,
    /// 原始扫描内容（无论是否解析成功都会保留）。
    pub raw: String,
    /// 票据分类名（train/flight/hotel/car），解析失败为 None。
    pub category: Option<String>,
    /// 名称，解析失败为 None。
    pub title: Option<String>,
    /// 备注副标题，解析失败为 None。
    pub subtitle: Option<String>,
    /// 金额，解析失败为 None。
    pub amount: Option<f64>,
}

/// 将扫码内容解析为 [QrParseResult]。
pub fn parse_qr_content(content: String) -> QrParseResult {
    let text = content.trim();
    if text.is_empty() {
        return failed_result(content);
    }

    // 1. 尝试 JSON。
    if text.starts_with('{') {
        if let Some(r) = try_parse_json(text) {
            return r;
        }
    }

    // 2. 尝试竖线分隔：category|title|subtitle|amount。
    if text.contains('|') {
        if let Some(r) = try_parse_pipe(text) {
            return r;
        }
    }

    // 3. 尝试携程行程单格式：etripHotel://id,name,orderNo,amount。
    if text.contains("://") {
        if let Some(r) = try_parse_etrip(text) {
            return r;
        }
    }

    failed_result(content)
}

fn ok_result(raw: String, category: String, title: String, subtitle: String, amount: f64) -> QrParseResult {
    QrParseResult {
        ok: true,
        raw,
        category: Some(category),
        title: Some(title),
        subtitle: Some(subtitle),
        amount: Some(amount),
    }
}

/// 解析失败的结果（调用方据 raw 展示原文）。
fn failed_result(raw: String) -> QrParseResult {
    QrParseResult {
        ok: false,
        raw,
        category: None,
        title: None,
        subtitle: None,
        amount: None,
    }
}

fn try_parse_json(text: &str) -> Option<QrParseResult> {
    // 极简手写 JSON 解析：仅识别本应用生成的扁平对象，
    // 避免引入 serde 依赖增加编译体积。
    let map = parse_flat_json(text)?;
    let category = map.get("category")?.trim().to_string();
    if !is_valid_category(&category) {
        return None;
    }
    let title = map.get("title")?.trim().to_string();
    if title.is_empty() {
        return None;
    }
    let subtitle = map.get("subtitle").map(|s| s.trim().to_string()).unwrap_or_default();
    let amount = parse_amount(map.get("amount").map(|s| s.as_str()).unwrap_or("0"));
    Some(ok_result(text.to_string(), category, title, subtitle, amount))
}

fn try_parse_pipe(text: &str) -> Option<QrParseResult> {
    let parts: Vec<&str> = text.split('|').collect();
    if parts.len() < 2 {
        return None;
    }
    let category = parts[0].trim().to_lowercase();
    if !is_valid_category(&category) {
        return None;
    }
    let title = parts[1].trim().to_string();
    if title.is_empty() {
        return None;
    }
    let subtitle = if parts.len() > 2 { parts[2].trim().to_string() } else { String::new() };
    let amount = if parts.len() > 3 {
        parts[3].trim().parse::<f64>().unwrap_or(0.0)
    } else {
        0.0
    };
    Some(ok_result(text.to_string(), category, title, subtitle, amount))
}

/// 解析携程行程单格式，前缀映射：etripHotel→hotel、etripCar→car、etrip→flight。
/// 两种字段布局，均需至少 4 段，否则返回 None（交由上层回退）：
///   - 飞机：`etrip://订单号,姓名,金额,原价`，金额在第 3 位
///   - 酒店/用车：`etripHotel://订单号,姓名,订单号,金额`，金额在末位
fn try_parse_etrip(text: &str) -> Option<QrParseResult> {
    let (prefix, data) = text.split_once("://")?;
    let category = match prefix.trim().to_lowercase().as_str() {
        "etriphotel" => "hotel",
        "etripcar" => "car",
        "etrip" => "flight",
        _ => return None,
    };
    let fields: Vec<&str> = data.split(',').collect();
    if fields.len() < 4 {
        return None;
    }
    let title = fields[1].trim().to_string();
    if title.is_empty() {
        return None;
    }
    let (amount_str, order_no) = if category == "flight" {
        (fields[2], fields[0])
    } else {
        (fields[3], fields[2])
    };
    let amount = amount_str.trim().parse::<f64>().ok()?;
    let order_no = order_no.trim();
    let subtitle = if order_no.is_empty() {
        String::new()
    } else {
        format!("订单号 {order_no}")
    };
    Some(ok_result(text.to_string(), category.to_string(), title, subtitle, amount))
}

fn is_valid_category(s: &str) -> bool {
    matches!(s, "train" | "flight" | "hotel" | "car" | "highway" | "subway")
}

fn parse_amount(s: &str) -> f64 {
    s.trim().parse::<f64>().unwrap_or(0.0)
}

/// 解析扁平 JSON 对象 `{"k":"v","n":123}`，仅支持字符串与数字值。
/// 转义符仅处理 \" 与 \\，足够覆盖本应用生成的内容。
fn parse_flat_json(text: &str) -> Option<std::collections::HashMap<String, String>> {
    let bytes = text.as_bytes();
    let mut i = 0;
    let n = bytes.len();
    // 跳过空白。
    skip_ws(bytes, &mut i);
    if i >= n || bytes[i] != b'{' {
        return None;
    }
    i += 1;
    let mut map = std::collections::HashMap::new();
    loop {
        skip_ws(bytes, &mut i);
        if i >= n {
            return None;
        }
        if bytes[i] == b'}' {
            break;
        }
        // 解析 key（字符串）。
        let key = parse_string(bytes, &mut i)?;
        skip_ws(bytes, &mut i);
        if i >= n || bytes[i] != b':' {
            return None;
        }
        i += 1;
        skip_ws(bytes, &mut i);
        if i >= n {
            return None;
        }
        // 解析 value（字符串或数字/字面量）。
        let value = if bytes[i] == b'"' {
            parse_string(bytes, &mut i)?
        } else {
            parse_literal(bytes, &mut i)
        };
        map.insert(key, value);
        skip_ws(bytes, &mut i);
        if i < n && bytes[i] == b',' {
            i += 1;
            continue;
        }
        if i < n && bytes[i] == b'}' {
            break;
        }
        return None;
    }
    Some(map)
}

fn skip_ws(bytes: &[u8], i: &mut usize) {
    while *i < bytes.len() && bytes[*i].is_ascii_whitespace() {
        *i += 1;
    }
}

fn parse_string(bytes: &[u8], i: &mut usize) -> Option<String> {
    if *i >= bytes.len() || bytes[*i] != b'"' {
        return None;
    }
    *i += 1;
    let mut out = String::new();
    while *i < bytes.len() {
        let c = bytes[*i];
        match c {
            b'"' => {
                *i += 1;
                return Some(out);
            }
            b'\\' => {
                *i += 1;
                if *i >= bytes.len() {
                    return None;
                }
                match bytes[*i] {
                    b'"' => out.push('"'),
                    b'\\' => out.push('\\'),
                    b'/' => out.push('/'),
                    b'n' => out.push('\n'),
                    b't' => out.push('\t'),
                    b'r' => out.push('\r'),
                    _ => out.push(bytes[*i] as char),
                }
                *i += 1;
            }
            _ => {
                // 按字节推进；UTF-8 多字节字符会以完整序列推入。
                let start = *i;
                *i += 1;
                while *i < bytes.len() && (bytes[*i] & 0xC0) == 0x80 {
                    *i += 1;
                }
                out.push_str(std::str::from_utf8(&bytes[start..*i]).ok()?);
            }
        }
    }
    None
}

fn parse_literal(bytes: &[u8], i: &mut usize) -> String {
    let start = *i;
    while *i < bytes.len() && !bytes[*i].is_ascii_whitespace() && bytes[*i] != b',' && bytes[*i] != b'}' {
        *i += 1;
    }
    String::from_utf8_lossy(&bytes[start..*i]).into_owned()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn etrip_flight_amount_is_third_field() {
        // 飞机：订单号,姓名,金额,原价 —— 金额在第 3 位。
        let r = parse_qr_content("etrip://2811544509,赵文俊,577.0,2317.0".to_string());
        assert!(r.ok);
        assert_eq!(r.category.as_deref(), Some("flight"));
        assert_eq!(r.title.as_deref(), Some("赵文俊"));
        assert_eq!(r.subtitle.as_deref(), Some("订单号 2811544509"));
        assert_eq!(r.amount, Some(577.0));
    }

    #[test]
    fn etrip_hotel_amount_is_last_field() {
        let r = parse_qr_content("etripHotel://870667,闫兴,2485235576652567552,3261.0".to_string());
        assert!(r.ok);
        assert_eq!(r.category.as_deref(), Some("hotel"));
        assert_eq!(r.title.as_deref(), Some("闫兴"));
        assert_eq!(r.amount, Some(3261.0));
    }

    #[test]
    fn etrip_car_amount_is_last_field() {
        let r = parse_qr_content("etripCar://870667,闫兴,2485235576652567552,86.0".to_string());
        assert!(r.ok);
        assert_eq!(r.category.as_deref(), Some("car"));
        assert_eq!(r.amount, Some(86.0));
    }

    #[test]
    fn unknown_prefix_falls_back() {
        let r = parse_qr_content("foo://870667,闫兴,2485235576652567552,86.0".to_string());
        assert!(!r.ok);
    }
}