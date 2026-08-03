//! OCR 文本结构化解析：将 OCR 识别出的票据文字解析为报销明细字段。
//! 启发式规则，不引入外部依赖：
//!   - 类别：按关键词识别（火车/高铁、机票/航班、酒店/住宿、出租/网约车）
//!   - 金额：取最后一个合法金额（发票合计通常位于底部）
//!   - 日期：识别 YYYY-MM-DD / YYYY/MM/DD / YYYY年M月D日
//! 无法识别金额与类别时 ok=false，调用方据 raw 回退展示原文。

/// OCR 解析结果。
#[derive(Clone, Debug)]
pub struct OcrParseResult {
    /// 是否成功解析出可用字段（有金额或类别）。
    pub ok: bool,
    /// 票据分类名（train/flight/hotel/car），未识别为 None。
    pub category: Option<String>,
    /// 名称（行程或类别标签），未识别为 None。
    pub title: Option<String>,
    /// 备注副标题（类别标签 + 日期），未识别为 None。
    pub subtitle: Option<String>,
    /// 金额，未识别为 None。
    pub amount: Option<f64>,
}

/// 将 OCR 文本解析为 [OcrParseResult]。
pub fn parse_ocr_text(text: String) -> OcrParseResult {
    let raw = text;
    if raw.trim().is_empty() {
        return OcrParseResult {
            ok: false,
            category: None,
            title: None,
            subtitle: None,
            amount: None,
        };
    }
    let category = detect_category(&raw);
    let amount = extract_last_amount(&raw);
    let date = extract_date(&raw);
    let ok = amount.is_some() || category.is_some();
    let (title, subtitle) = build_title_subtitle(&raw, category.as_deref(), date.as_deref());
    OcrParseResult {
        ok,
        category,
        title: ok.then_some(title),
        subtitle: ok.then_some(subtitle),
        amount,
    }
}

/// 订单截图抽取结果：订单号前缀即发票类型，末行 ¥xxx 即金额。
#[derive(Clone, Debug)]
pub struct ImageHint {
    /// 订单类型（car/flight/hotel）。
    pub order_type: String,
    /// 订单号（2 位前缀 + 14~22 位数字，如 DF12345678901234567890）。
    pub order_id: String,
    /// 末行金额，未识别到为 None。
    pub amount: Option<f64>,
}

/// 从订单列表截图 OCR 文本中抽取全部订单（图片可能含多张订单卡片）。
///
/// 策略：第 N 个订单号 ↔ 第 N 个金额（按出现顺序 1:1 配对）。
/// 这样无论 OCR 输出的金额是：
///   1. 落在每张卡内（按卡阅读），自然与卡内订单号同序；
///   2. 全部统一输出在文末（OCR 未按卡分组），仍按出现顺序与订单号一一对应。
/// 数量不等时按较短者配对，缺失一侧补 None，多余一侧忽略。
/// 无订单号或前缀未知则忽略。
pub fn extract_all_order_hints(text: String) -> Vec<ImageHint> {
    let chars: Vec<char> = text.chars().collect();
    let order_positions = find_all_order_id_positions(&chars);
    if order_positions.is_empty() {
        return Vec::new();
    }
    let amount_positions = find_all_amount_positions(&chars);
    let mut hints = Vec::with_capacity(order_positions.len());
    for (idx, (order_id, _pos)) in order_positions.into_iter().enumerate() {
        let order_type = match order_id.get(..2) {
            Some("DC") => "car",
            Some("DF") => "flight",
            Some("HO") => "hotel",
            _ => continue,
        };
        // 第 N 个订单号 ↔ 第 N 个金额（按出现顺序）。
        let amount = amount_positions.get(idx).map(|(_, v, _)| *v);
        hints.push(ImageHint {
            order_type: order_type.to_string(),
            order_id,
            amount,
        });
    }
    hints
}

/// 在 chars 中查找所有订单号及其起始位置。
/// 订单号是 ASCII（2 字母 + 14~22 位数字），故 char 位置即可作为下标比较。
fn find_all_order_id_positions(chars: &[char]) -> Vec<(String, usize)> {
    let n = chars.len();
    let mut results = Vec::new();
    let mut i = 0;
    while i + 1 < n {
        if chars[i].is_ascii_uppercase()
            && chars[i + 1].is_ascii_uppercase()
            && (i == 0 || !is_word_char_c(chars[i - 1]))
        {
            let mut j = i + 2;
            while j < n && chars[j].is_ascii_digit() {
                j += 1;
            }
            let digits = j - (i + 2);
            if (14..=22).contains(&digits) && (j == n || !is_word_char_c(chars[j])) {
                let s: String = chars[i..j].iter().collect();
                results.push((s, i));
                i = j;
                continue;
            }
        }
        i += 1;
    }
    results
}

/// 在 chars 中查找所有金额候选及其位置，候选规则（按出现顺序返回）：
///   - 带货币符号 ¥/￥ 或其 OCR 变形前缀（x/X）：范围 0.01~100000
///   - 无符号小数（如 90.56，¥ 符号被 OCR 丢失）：范围 0.01~100000
///   - 无符号整数（如 3339）：范围 100~99999 且排除 1900~2099（年份）
///   - 数字后紧跟 '-' 或 '/' 视为日期/型号分隔符，跳过（如 2026-07-12、253-日常用车）
/// 返回 (起始位置, 金额, 是否带货币符号前缀)。
fn find_all_amount_positions(chars: &[char]) -> Vec<(usize, f64, bool)> {
    let n = chars.len();
    let mut results = Vec::new();
    let mut i = 0;
    while i < n {
        let has_prefix = is_currency_char(chars[i]);
        if !has_prefix && !chars[i].is_ascii_digit() {
            i += 1;
            continue;
        }
        let mut j = if has_prefix { i + 1 } else { i };
        // 跳过前缀后的空白（仅前缀场景）。
        while has_prefix && j < n && chars[j].is_whitespace() {
            j += 1;
        }
        // 收集数字、逗号、小数点。
        let start = j;
        while j < n && (chars[j].is_ascii_digit() || chars[j] == ',' || chars[j] == '.') {
            j += 1;
        }
        if j > start {
            // 数字后紧跟 - 或 / 多为日期/型号分隔，跳过该候选。
            if j < n && (chars[j] == '-' || chars[j] == '/') {
                i = j + 1;
                continue;
            }
            let num_str: String = chars[start..j].iter().filter(|&&c| c != ',').collect();
            if let Ok(v) = num_str.parse::<f64>() {
                if is_valid_amount(v, has_prefix, num_str.contains('.')) {
                    results.push((i, v, has_prefix));
                }
            }
        }
        i = if j > i { j } else { i + 1 };
    }
    results
}

/// 货币符号及其常见 OCR 变形前缀（¥ 常被识别成 x / X）。
fn is_currency_char(c: char) -> bool {
    matches!(c, '¥' | '￥' | 'x' | 'X')
}

/// 金额候选校验：范围 + 无符号时的额外约束（避免日期/时间碎片）。
/// [has_dot] 表示数字串是否带小数点（86.00 解析为 f64 后是 86.0，
/// 无法用数值判断，必须看原始字符串）。
fn is_valid_amount(v: f64, has_prefix: bool, has_dot: bool) -> bool {
    if !(0.01..=100_000.0).contains(&v) {
        return false;
    }
    if has_prefix {
        return true;
    }
    // 无符号：数字串带小数点（如 86.00）直接接受；
    // 整数需 >=100 且排除年份（1900~2099）。
    if has_dot {
        return true;
    }
    v >= 100.0 && !(1900.0..=2099.0).contains(&v)
}

/// 字符级词边界判定（对应原 [is_word_char] 的 byte 版本）。
fn is_word_char_c(c: char) -> bool {
    c.is_ascii_alphanumeric() || c == '_'
}

/// 提取金额（单票据场景）：优先取最后一个带货币符号的候选
/// （¥/￥/x/X 高置信，避免把无符号的客服热线/编码当金额）；
/// 仅当完全没有带符号金额时才退化为最后一个候选（¥ 被 OCR 丢失的场景）。
fn extract_last_amount(text: &str) -> Option<f64> {
    let chars: Vec<char> = text.chars().collect();
    let candidates = find_all_amount_positions(&chars);
    candidates
        .iter()
        .rev()
        .find(|(_, _, prefixed)| *prefixed)
        .or_else(|| candidates.last())
        .map(|(_, v, _)| *v)
}

/// 类别中文标签，用于标题/备注展示。
fn category_label(category: &str) -> &'static str {
    match category {
        "train" => "火车票",
        "flight" => "机票",
        "hotel" => "酒店住宿",
        "car" => "出租车",
        _ => "票据",
    }
}

/// 按关键词识别票据类别，返回分类名（train/flight/hotel/car）。
fn detect_category(text: &str) -> Option<String> {
    // 注意顺序：更具体的词优先，避免 "出租车" 中的 "车" 之类误命中。
    const KEYWORDS: &[(&str, &[&str])] = &[
        ("train", &["火车", "高铁", "动车", "铁路", "12306", "车次"]),
        ("flight", &["机票", "航空", "客票", "航班", "登机", "航段"]),
        ("hotel", &["酒店", "住宿", "房费", "入住", "旅馆"]),
        ("car", &["出租车", "网约车", "滴滴", "打车", "起步价", "用车"]),
    ];
    KEYWORDS
        .iter()
        .find(|(_, kws)| kws.iter().any(|kw| text.contains(kw)))
        .map(|(cat, _)| (*cat).to_string())
}

/// 提取日期，归一化为 YYYY-MM-DD。
/// 支持 `2026-08-03`、`2026/8/3`、`2026年8月3日` 等写法。
fn extract_date(text: &str) -> Option<String> {
    let chars: Vec<char> = text.chars().collect();
    let n = chars.len();
    let mut i = 0;
    while i < n {
        if !chars[i].is_ascii_digit() {
            i += 1;
            continue;
        }
        let mut end = i;
        while end < n && chars[end].is_ascii_digit() {
            end += 1;
        }
        if end - i == 4 {
            let year: u32 = chars[i..end].iter().collect::<String>().parse().ok()?;
            let sep1 = chars.get(end).copied();
            let ok1 = matches!(sep1, Some('-') | Some('/') | Some('年'));
            if ok1 && (1900..=2100).contains(&year) {
                let (month, rest) = parse_ymd_num(&chars, end + 1)?;
                if (1..=12).contains(&month) {
                    let (day, _) = parse_ymd_num(&chars, rest)?;
                    if (1..=31).contains(&day) {
                        return Some(format!("{year:04}-{month:02}-{day:02}"));
                    }
                }
            }
        }
        i = end;
    }
    None
}

/// 从指定位置解析 1~2 位数字（月或日），返回 (数字, 下一个待处理下标)。
fn parse_ymd_num(chars: &[char], mut i: usize) -> Option<(u32, usize)> {
    let n = chars.len();
    if i >= n || !chars[i].is_ascii_digit() {
        return None;
    }
    let start = i;
    while i < n && chars[i].is_ascii_digit() {
        i += 1;
    }
    let digits: String = chars[start..i].iter().collect();
    if digits.len() > 2 {
        return None;
    }
    let v: u32 = digits.parse().ok()?;
    // 跳过紧跟的分隔符（月/日/-//），以便继续解析下一个数字。
    if i < n && matches!(chars[i], '月' | '日' | '-' | '/') {
        i += 1;
    }
    Some((v, i))
}

/// 组装标题与备注：
///   - title：优先取行程（"北京南→上海虹桥"），否则类别标签
///   - subtitle：类别标签 + 日期，如 "火车票 2026-08-03"
fn build_title_subtitle(
    text: &str,
    category: Option<&str>,
    date: Option<&str>,
) -> (String, String) {
    let label = category.map(category_label).unwrap_or("票据");
    // 优先箭头行程，其次两行站名（火车票），否则类别标签。
    let title = extract_route(text)
        .or_else(|| extract_station_route(text))
        .unwrap_or_else(|| label.to_string());
    let mut parts: Vec<&str> = Vec::new();
    if category.is_some() {
        parts.push(label);
    }
    if let Some(d) = date {
        parts.push(d);
    }
    let subtitle = parts.join(" ");
    (title, subtitle)
}

/// 提取行程串：`北京南→上海虹桥`（支持 → / -> / 至 分隔）。
fn extract_route(text: &str) -> Option<String> {
    let chars: Vec<char> = text.chars().collect();
    let n = chars.len();
    for idx in 0..n {
        let is_arrow = chars[idx] == '→'
            || chars[idx] == '至'
            || (chars[idx] == '-' && idx + 1 < n && chars[idx + 1] == '>');
        if !is_arrow {
            continue;
        }
        let sep_len = if chars[idx] == '-' { 2 } else { 1 };
        let left: String = chars[..idx]
            .iter()
            .rev()
            .take_while(|c| is_cjk(**c))
            .collect::<Vec<_>>()
            .into_iter()
            .rev()
            .collect();
        let right: String = chars[idx + sep_len..]
            .iter()
            .take_while(|c| is_cjk(**c))
            .collect();
        if left.len() >= 2 && right.len() >= 2 {
            return Some(format!("{left}→{right}"));
        }
    }
    None
}

/// 提取站点行程：火车票无箭头分隔时，取前两个以「站」结尾的地名组成行程，
/// 如「北京西站\n西安北站」→「北京西站→西安北站」。
fn extract_station_route(text: &str) -> Option<String> {
    let chars: Vec<char> = text.chars().collect();
    let n = chars.len();
    let mut stations = Vec::new();
    let mut i = 0;
    while i < n {
        if is_cjk(chars[i]) {
            let start = i;
            while i < n && is_cjk(chars[i]) {
                i += 1;
            }
            let word: String = chars[start..i].iter().collect();
            // 形如「XX站」的地名（至少 3 个字符，避免单字误抓）。
            if word.ends_with('站') && word.chars().count() >= 3 {
                stations.push(word);
                if stations.len() == 2 {
                    break;
                }
            }
        } else {
            i += 1;
        }
    }
    if stations.len() >= 2 {
        Some(format!("{}→{}", stations[0], stations[1]))
    } else {
        None
    }
}

/// 是否为常用 CJK 表意文字（用于行程起点/终点提取）。
fn is_cjk(c: char) -> bool {
    ('\u{4e00}'..='\u{9fff}').contains(&c)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(text: &str) -> OcrParseResult {
        parse_ocr_text(text.to_string())
    }

    #[test]
    fn train_ticket() {
        let r = parse("铁路电子客票\nG123 北京南→上海虹桥\n2026年8月3日\n二等座\n合计 ¥553.00");
        assert!(r.ok);
        assert_eq!(r.category.as_deref(), Some("train"));
        assert_eq!(r.amount, Some(553.0));
        assert_eq!(r.title.as_deref(), Some("北京南→上海虹桥"));
    }

    #[test]
    fn flight_ticket() {
        let r = parse("航空运输电子客票行程单\n航班 CA1234\n2026/8/3\n票价 1290.50 元");
        assert!(r.ok);
        assert_eq!(r.category.as_deref(), Some("flight"));
        assert_eq!(r.amount, Some(1290.5));
    }

    #[test]
    fn hotel_receipt() {
        let r = parse("某某酒店住宿发票\n入住日期：2026-08-03\n房费\n金额 ￥3,261.00");
        assert!(r.ok);
        assert_eq!(r.category.as_deref(), Some("hotel"));
        assert_eq!(r.amount, Some(3261.0));
    }

    #[test]
    fn taxi_receipt() {
        let r = parse("出租车发票\n起步价 10 元\n2026-8-3\n合计 86.00 元");
        assert!(r.ok);
        assert_eq!(r.category.as_deref(), Some("car"));
        assert_eq!(r.amount, Some(86.0));
    }

    #[test]
    fn last_amount_wins() {
        // 金额乱序时取最后一个（合计在底部）。
        let r = parse("小计 100 元\n其他 50 元\n总计 200.5 元");
        assert_eq!(r.amount, Some(200.5));
    }

    #[test]
    fn no_amount_falls_back() {
        let r = parse("这是一段没有金额的普通文字");
        assert!(!r.ok);
        assert!(r.category.is_none());
        assert!(r.amount.is_none());
    }

    #[test]
    fn order_no_filtered() {
        // 长数字（订单号/证件号）超出金额范围被过滤。
        let r = parse("订单号 2485235576652567552\n金额 3261.0");
        assert_eq!(r.amount, Some(3261.0));
    }

    #[test]
    fn empty_input() {
        let r = parse("");
        assert!(!r.ok);
    }

    #[test]
    fn all_order_hints_extract_multiple() {
        // 长截图含多张订单卡片：按订单号切分，逐段提取。
        let text = "我的订单\nDC12345678901234567890\n¥86.00\nHO12345678901234567891\n¥3261.0\nDF12345678901234567892\n¥577.00"
            .to_string();
        let hints = extract_all_order_hints(text);
        assert_eq!(hints.len(), 3);
        assert_eq!(hints[0].order_type, "car");
        assert_eq!(hints[0].amount, Some(86.0));
        assert_eq!(hints[1].order_type, "hotel");
        assert_eq!(hints[1].amount, Some(3261.0));
        assert_eq!(hints[2].order_type, "flight");
        assert_eq!(hints[2].amount, Some(577.0));
    }

    #[test]
    fn all_order_hints_empty_without_order_id() {
        assert!(extract_all_order_hints("没有订单号".to_string()).is_empty());
    }

    #[test]
    fn real_screenshot_orders_paired_with_amounts() {
        // 用户真实订单列表截图：¥ 符号被 OCR 识别成 x 或丢失，
        // 金额（89.19 / 90.56 / 3339）全部挤在文末，按出现顺序与订单号配对。
        let text = "订单編号DC260712188429557710\n\
                    253-日常用车 -经济型 约车上车点 2026-07-12 23:29:23 乘车人:兴\n\
                    订单缩号DC260712188390654303\n\
                    253-日常用车 -经济型 2026-07-12 17:12:14 乘车人: 闫兴\n\
                    订单蝙号 HO20260712171800782163\n\
                    离店: 2026-07-24 入住人:闫兴 入住: 2026-07-12 1间12晚 星程酒店\n\
                    同程商旅 x89.19 90.56 同程商旅 自有酒店 3339"
            .to_string();
        let hints = extract_all_order_hints(text);
        assert_eq!(hints.len(), 3);
        assert_eq!(hints[0].order_type, "car");
        assert_eq!(hints[0].order_id, "DC260712188429557710");
        assert_eq!(hints[0].amount, Some(89.19));
        assert_eq!(hints[1].order_type, "car");
        assert_eq!(hints[1].order_id, "DC260712188390654303");
        assert_eq!(hints[1].amount, Some(90.56));
        assert_eq!(hints[2].order_type, "hotel");
        assert_eq!(hints[2].order_id, "HO20260712171800782163");
        assert_eq!(hints[2].amount, Some(3339.0));
    }

    #[test]
    fn amount_prefix_ocr_variant_x() {
        // ¥ 被 OCR 识别成 x。
        assert_eq!(extract_last_amount("同程商旅 x89.19"), Some(89.19));
    }

    #[test]
    fn amount_without_symbol_decimal() {
        // ¥ 符号丢失，只剩小数。
        assert_eq!(extract_last_amount("同程商旅 90.56"), Some(90.56));
    }

    #[test]
    fn amount_without_symbol_integer() {
        // ¥ 符号丢失，只剩整数（非年份）。
        assert_eq!(extract_last_amount("自有酒店 3339"), Some(3339.0));
    }

    #[test]
    fn date_and_model_fragments_ignored() {
        // 日期（2026-07-12）、时间（23:29:23）、型号（253-日常用车）都不应被当金额。
        assert_eq!(
            extract_last_amount("2026-07-12 23:29:23 253-日常用车 1间12晚"),
            None
        );
        // 年份（1900~2099）不作为无符号整数金额。
        assert_eq!(extract_last_amount("预订时间: 2026-07-12 17:18:51"), None);
    }

    // 回归：OCR 把多张订单卡片的金额统一输出在文末（OCR 未按卡分组时常见），
    // 此时每张订单的金额 = 自身订单号之后第一个 ¥ 金额。
    // 修复前按「切分到每段后取最后一个」会把所有金额判给末段，前两张卡的金额为 None。
    #[test]
    fn real_image_amounts_clustered_at_end() {
        let text = "\
订单编号 DC260712188429557710
253-日常用车 - 经济型
西安北站北广场-西停车楼B1层-网约车上车点
2026-07-12 23:29:23
西安高新锦业路轻居酒店
2026-07-13 00:10:51
乘车人：闫兴
订单编号 DC260712188390654303
253-日常用车 - 经济型
西安北站北广场-西停车楼B1层-网约车上车点
2026-07-12 23:39:24
西安高新锦业路轻居酒店
2026-07-13 00:16:25
乘车人：闫兴
订单编号 HO20260712171800782163
星程酒店(西安高新区锦业路店)
入住: 2026-07-12
离店: 2026-07-24
¥ 89.19
¥ 90.56
¥ 3339";
        let hints = extract_all_order_hints(text.to_string());
        assert_eq!(hints.len(), 3, "应识别出 3 张订单");
        assert_eq!(hints[0].order_id, "DC260712188429557710");
        assert_eq!(hints[0].order_type, "car");
        assert_eq!(
            hints[0].amount,
            Some(89.19),
            "DC1 应取其后第一个金额 89.19"
        );
        assert_eq!(hints[1].order_id, "DC260712188390654303");
        assert_eq!(hints[1].order_type, "car");
        assert_eq!(
            hints[1].amount,
            Some(90.56),
            "DC2 应取其后第一个金额 90.56"
        );
        assert_eq!(hints[2].order_id, "HO20260712171800782163");
        assert_eq!(hints[2].order_type, "hotel");
        assert_eq!(
            hints[2].amount,
            Some(3339.0),
            "HO 应取其后第一个金额 3339"
        );
    }

    #[test]
    fn real_image_multi_card_amounts_per_card() {
        // 同一张截图（按"订单编号"行切分）三张卡片各自取段内最后一个金额。
        let text = "\
订单编号 DC260712188429557710
¥ 89.19
订单编号 DC260712188390654303
¥ 90.56
订单编号 HO20260712171800782163
¥ 3339";
        let hints = extract_all_order_hints(text.to_string());
        assert_eq!(hints.len(), 3);
        assert_eq!(hints[0].order_id, "DC260712188429557710");
        assert_eq!(hints[0].amount, Some(89.19));
        assert_eq!(hints[1].order_id, "DC260712188390654303");
        assert_eq!(hints[1].amount, Some(90.56));
        assert_eq!(hints[2].order_id, "HO20260712171800782163");
        assert_eq!(hints[2].amount, Some(3339.0));
    }

    #[test]
    fn real_train_ticket_ocr() {
        // 用户真实火车票 OCR 文本：末尾「发货请到95306」易被误当金额，
        // 应优先取带 ¥ 符号的票价 547.50；行程取两行站名。
        let text = "电子发票(铁路电子客票)\n\
                    国家税务总局\n\
                    开票日期:2026年07月14日\n\
                    发票号码:26119121152005716099\n\
                    北京西站\n\
                    西安北站\n\
                    G323\n\
                    2026年06月23日\n\
                    二等座\n\
                    15:00开\n\
                    09车08A号\n\
                    票价:¥547.50\n\
                    闫兴\n\
                    电子客票号:21152A2086062390768052026\n\
                    购买方名称:北京长城航空测控技术研究所有限公司\n\
                    买票请到12306 发货请到95306\n\
                    中国铁路祝您旅途愉快"
            .to_string();
        let r = parse_ocr_text(text);
        assert!(r.ok);
        assert_eq!(r.category.as_deref(), Some("train"));
        assert_eq!(r.amount, Some(547.50));
        assert_eq!(r.title.as_deref(), Some("北京西站→西安北站"));
    }
}
