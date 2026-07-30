use crate::config::RulesConfig;
use crate::error::AppError;
use crate::models::InvoiceRecord;
use crate::services::{normalize, recognition_service};
use tauri::State;
use tauri_plugin_mlkit_text::MlkitText;

/// 图片 OCR：content URI → ML Kit 文本 → 归一化。
/// 后续拆分/解析与桌面一致，由前端 splitOrderSegments + recognize_from_text 驱动。
#[tauri::command]
pub fn recognize_image_uri(
    uri: String,
    mlkit: State<'_, MlkitText<tauri::Wry>>,
) -> Result<String, AppError> {
    let raw = mlkit
        .recognize(&uri)
        .map_err(|e| AppError::Ocr(e.to_string()))?;
    Ok(normalize::normalize_ocr_text(&raw))
}

/// 从纯文本识别单据 —— 与桌面版逐字相同（snap-claim-rs recognition.rs L123-175）。
/// 图片输入无二维码，qr_codes 传空。
#[tauri::command]
pub fn recognize_from_text(
    text: String,
    filename: String,
    full_path: String,
    page_number: u32,
    image_hint: Option<recognition_service::ImageHint>,
) -> Result<InvoiceRecord, AppError> {
    let rules = RulesConfig::load().map_err(AppError::RulesLoad)?;
    let qr_codes: Vec<String> = vec![];

    if let Some(h) = image_hint.as_ref() {
        tracing::info!(
            "[image-ocr] 订单号={} 类型提示={} 金额提示={:?}",
            h.order_id.as_deref().unwrap_or("(none)"),
            h.order_type.as_deref().unwrap_or("(none)"),
            h.amount,
        );
    }

    let (invoice_type, from_qr) = recognition_service::detect_invoice_type(
        &text,
        &qr_codes,
        &rules,
        image_hint.as_ref(),
    );
    let fields = recognition_service::extract_fields(
        &text,
        &invoice_type,
        from_qr,
        &qr_codes,
        &rules,
        image_hint.as_ref(),
    );
    let record = recognition_service::build_invoice_record(
        &fields,
        &invoice_type,
        &filename,
        &full_path,
        page_number,
    );

    let amount = fields.get("amount").and_then(|v| v.as_f64());
    tracing::info!(
        "[image-ocr] 识别完成 类型={} 金额={:?}",
        invoice_type,
        amount,
    );

    Ok(record)
}

/// 扫码路径：etrip 确认函二维码 → 记录（新增命令）。
/// ponytail: detect_invoice_type 的 etrip QR 分支以 text.contains("确认函") 为门控
/// （recognition_service.rs L43-62），扫码无文本，这里传 "确认函" 作合成信号进入 QR 分支。
/// ceiling: 仅 etripCar:// / etripHotel:// / etrip:// 系列；
///   增值税发票二维码（01,kind,...）后端未实现拆字段，扫码扫到此类 QR 会落到 unknown。
///   升级路径：先在 recognition_service.rs 加 VAT QR 分支，本命令改传真实 QR 文本即可，
///   命令签名无需改动。
#[tauri::command]
pub fn recognize_from_qr(
    qr: String,
    filename: String,
    full_path: String,
) -> Result<InvoiceRecord, AppError> {
    let rules = RulesConfig::load().map_err(AppError::RulesLoad)?;
    // 合成 "确认函" 文本进入 detect_invoice_type 的 QR 分支
    let text = "确认函".to_string();
    let qr_codes = vec![qr.clone()];

    let (invoice_type, from_qr) =
        recognition_service::detect_invoice_type(&text, &qr_codes, &rules, None);
    let fields = recognition_service::extract_fields(
        &text,
        &invoice_type,
        from_qr,
        &qr_codes,
        &rules,
        None,
    );
    let record = recognition_service::build_invoice_record(
        &fields,
        &invoice_type,
        &filename,
        &full_path,
        1,
    );

    tracing::info!(
        "[qr] 扫码识别完成 类型={} 金额={:?}",
        invoice_type,
        record.amount,
    );

    Ok(record)
}
