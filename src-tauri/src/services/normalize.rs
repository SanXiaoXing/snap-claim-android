/// ML Kit 输出归一化：让 rules.yaml 的 PaddleOCR 取向正则在 ML Kit 文本上同样命中。
/// 每条规则只修一个已知的输出差异，不做通用 unicode 归一化。
pub fn normalize_ocr_text(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let line = line.replace('￥', "¥").replace('：', ":");
        let line = collapse_cjk_spaces(&line);
        out.push_str(&line);
        out.push('\n');
    }
    out.trim_end().to_string()
}

/// 两个 CJK 字符之间的空格删掉（"发 票" → "发票"）。
fn collapse_cjk_spaces(s: &str) -> String {
    let chars: Vec<char> = s.chars().collect();
    let mut out = String::with_capacity(s.len());
    for (i, &c) in chars.iter().enumerate() {
        if c == ' ' {
            let prev = chars[..i].iter().rev().find(|&&x| x != ' ');
            let next = chars[i + 1..].iter().find(|&&x| x != ' ');
            if let (Some(&p), Some(&n)) = (prev, next) {
                if is_cjk(p) && is_cjk(n) {
                    continue;
                }
            }
        }
        out.push(c);
    }
    out
}

fn is_cjk(c: char) -> bool {
    ('\u{4e00}'..='\u{9fff}').contains(&c)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_known_mismatches() {
        assert_eq!(normalize_ocr_text("发 票 代码：123"), "发票代码:123");
        assert_eq!(normalize_ocr_text("￥ 128.00\n\n\n"), "¥ 128.00");
        // 中英文之间的空格保留（不影响现有正则）
        assert_eq!(normalize_ocr_text("车次 G123"), "车次 G123");
    }
}
