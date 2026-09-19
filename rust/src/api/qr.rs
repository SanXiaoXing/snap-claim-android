//! 二维码内容解析：将扫到的文本解析为报销明细字段。
//! 支持携程行程单 URI：etripHotel / etripCar / etrip。
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

    // 携程行程单：etripHotel://id,name,orderNo,amount 等。
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
