# SnapClaim Mobile Implementation Plan

> Companion to `MOBILE_SPEC.md`. Contains concrete code for all net-new
> components. Verbatim copies from desktop are listed, not repeated.

---

## 0. What Is New vs What Is Copied

**Copied verbatim from desktop (`snap-claim-rs`)**:

| Source (desktop) | Destination (mobile) |
|---|---|
| `src-tauri/src/services/recognition_service.rs` | `src-tauri/src/services/recognition_service.rs` |
| `src-tauri/src/services/expense_calculator.rs` | `src-tauri/src/services/expense_calculator.rs` |
| `src-tauri/src/config/rules.yaml` | `src-tauri/src/config/rules.yaml` |
| `src-tauri/src/config/mod.rs` | `src-tauri/src/config/mod.rs` |
| `src-tauri/src/models/mod.rs` | `src-tauri/src/models/mod.rs` |
| `src-tauri/src/commands/history.rs` | `src-tauri/src/commands/history.rs` |
| `src-tauri/src/commands/update.rs` | `src-tauri/src/commands/update.rs` (CrabNebula endpoint, §7) |
| `src-tauri/src/utils/mod.rs` | `src-tauri/src/utils/mod.rs` |  # expense_calculator 依赖
| `src-tauri/src/utils/amount_converter.rs` | `src-tauri/src/utils/amount_converter.rs` |  # calc_totals → convert(total)
| `src-tauri/src/error.rs` | `src-tauri/src/error.rs`（裁剪，见 §5） |
| `src/services/ocr/imageHint.ts` | `src/services/imageHint.ts` |
| `src/types/index.ts` | `src/types/index.ts` |

> 注：`models/mod.rs` 含 `UpdateInfo` 结构体，`update.rs` 依赖它，原样复制即可。

**Copied with one-line change**:

| File | Change |
|---|---|
| `database.rs` | `Database::open()` takes `&AppHandle`, path = `app.path().app_data_dir()/snap_claim.db` |
| `commands/recognition.rs` | drop `recognize_invoices`、`read_image_bytes`；新增 `recognize_image_uri`、`recognize_from_qr`（见 §5）；`recognize_from_text` 原样 |
| `commands/mod.rs` | 只留 `history` / `recognition` / `update`（去 `excel`、`pdf`），见 §5 |
| `services/mod.rs` | 只留 `database` / `expense_calculator` / `recognition_service` + 新增 `normalize`（去 `excel_service`、`pdf_service`），见 §5 |

**Net-new (this document)**:

1. `plugins/tauri-plugin-mlkit-text` — Rust + Kotlin plugin (§2, §3)
2. `src-tauri/src/services/normalize.rs` — text normalization (§4)
3. `src-tauri/src/commands/recognition.rs::recognize_image_uri` — OCR command (§5)
4. `src-tauri/src/commands/recognition.rs::recognize_from_qr` — 扫码 → 记录 command (§5)
5. `src/lib/tauri.ts` mobile functions (§6)
6. Project scaffolding + configs (§1, §7)

---

## 1. Scaffolding

```bash
cd ~/Desktop/Code
# ponytail: 项目已存在为 snap-claim-android，沿用其 Cargo name=snapclaim / lib=snapclaim_lib
# / identifier=cn.sanxiaoxing.snapclaim，不再改名以最小化 diff。
npm create tauri-app@latest snap-claim-android -- --template react-ts --manager npm
cd snap-claim-android
npm install

# Mobile target
rustup target add aarch64-linux-android armv7-linux-androideabi
npm run tauri android init

# Plugins
npm run tauri add dialog
npm run tauri add barcode-scanner
npm run tauri add updater

# Updater signing keypair（CrabNebula 发布签名，私钥保密）
npm run tauri signer generate -- -w ~/.tauri/snapclaim-android.key
```

`src-tauri/Cargo.toml` (desktop deps minus dropped ones; 相对当前模板还要去掉 `tauri-plugin-opener`):

```toml
[package]
name = "snapclaim"
version = "0.1.0"
edition = "2021"

[lib]
name = "snapclaim_lib"
crate-type = ["staticlib", "cdylib", "rlib"]

[build-dependencies]
tauri-build = { version = "2", features = [] }

[dependencies]
tauri = { version = "2", features = [] }
tauri-plugin-dialog = "2"
tauri-plugin-barcode-scanner = "2"
tauri-plugin-updater = "2"
tauri-plugin-mlkit-text = { path = "../plugins/tauri-plugin-mlkit-text" }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
thiserror = "1.0"
serde_yaml = "0.9"
regex = "1"
rusqlite = { version = "0.31", features = ["bundled"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
```

Dropped vs desktop: `pdfium-render`, `rxing`, `rust_xlsxwriter`,
`tauri-plugin-shell`, `tauri-plugin-single-instance`.

`package.json` 前端依赖（scaffolding 后手动调整）：
- **保留**：`@tauri-apps/api`、`@tauri-apps/plugin-dialog`、`@tauri-apps/plugin-updater`、
  `react`、`react-dom`、`tailwindcss`（+ autoprefixer/postcss）、`gsap`、`lucide-react`、
  `clsx`、`tailwind-merge`（UI 组件复用桌面样式）
- **新增**：`@tauri-apps/plugin-barcode-scanner`（§1 `npm run tauri add barcode-scanner` 已装）
- **删除**：`@paddleocr/paddleocr-js`（ML Kit 替代）、`@tauri-apps/plugin-shell`（无 shell）
- **devDeps**：`vitest`/`jsdom`/`@testing-library/*` 保留与否取决于是否写前端单测；
  normalize.rs 的自检在 Rust 侧（§4 `#[cfg(test)]`），前端可不写测试

`src-tauri/src/main.rs` 已是 `snapclaim_lib::run()`，无需改。

---

## 2. Plugin: Rust Side

`plugins/tauri-plugin-mlkit-text/Cargo.toml`:

```toml
[package]
name = "tauri-plugin-mlkit-text"
version = "0.1.0"
edition = "2021"

[dependencies]
tauri = { version = "2", features = [] }
serde = { version = "1", features = ["derive"] }
thiserror = "1.0"
```

`plugins/tauri-plugin-mlkit-text/src/lib.rs`:

```rust
use serde::{Deserialize, Serialize};
use tauri::{
    plugin::{Builder, PluginHandle, TauriPlugin},
    Runtime,
};

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("ML Kit inference failed: {0}")]
    Inference(String),
    #[cfg(mobile)]
    #[error(transparent)]
    PluginInvoke(#[from] tauri::plugin::mobile::PluginInvokeError),
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct RecognizeArgs {
    uri: String,
}

#[derive(Deserialize)]
struct RecognizeResponse {
    text: String,
}

/// Handle to the Kotlin plugin. Registered as Tauri state by the app.
pub struct MlkitText<R: Runtime>(PluginHandle<R>);

impl<R: Runtime> MlkitText<R> {
    /// Run ML Kit OCR on a content:// URI. Returns reading-ordered plain text.
    /// Blocking: Kotlin resolves via ML Kit's Tasks API (addOnSuccessListener).
    pub fn recognize(&self, uri: &str) -> Result<String, Error> {
        let resp = self
            .0
            .run_mobile_plugin::<RecognizeResponse>(
                "recognize",
                RecognizeArgs { uri: uri.to_string() },
            )
            .map_err(Error::PluginInvoke)?;
        Ok(resp.text)
    }
}

/// Registers the Kotlin plugin class. Package must match the Kotlin file's
/// `package` declaration and `tauri.conf.json` identifier suffix.
pub fn init<R: Runtime>() -> TauriPlugin<R> {
    Builder::new("mlkit-text")
        .setup(|app, api| {
            #[cfg(mobile)]
            {
                let handle = api.register_android_plugin(
                    "cn.sanxiaoxing.snapclaim.plugin",
                    "MlkitTextPlugin",
                )?;
                app.manage(MlkitText(handle));
            }
            Ok(())
        })
        .build()
}
```

---

## 3. Plugin: Kotlin Side

`plugins/tauri-plugin-mlkit-text/android/build.gradle.kts`:

```kotlin
dependencies {
    // Bundled Chinese text recognition — no Play Services delivery required.
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
}
```

`plugins/tauri-plugin-mlkit-text/android/src/main/java/cn/sanxiaoxing/snapclaim/plugin/MlkitTextPlugin.kt`:

```kotlin
package cn.sanxiaoxing.snapclaim.plugin

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import app.tauri.annotation.Command
import app.tauri.annotation.InvokeArg
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import kotlin.math.abs

@InvokeArg
class RecognizeArgs {
    lateinit var uri: String
}

@TauriPlugin
class MlkitTextPlugin(private val activity: Activity) : Plugin(activity) {

    private val recognizer by lazy {
        TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
    }

    @Command
    fun recognize(invoke: Invoke) {
        val args = invoke.parseArgs(RecognizeArgs::class.java)
        val bitmap = try {
            decodeBitmap(Uri.parse(args.uri))
        } catch (e: Exception) {
            invoke.reject("decode image failed: ${e.message}")
            return
        }

        recognizer.process(InputImage.fromBitmap(bitmap, 0))
            .addOnSuccessListener { result ->
                val ret = JSObject()
                ret.put("text", toReadingOrderedText(result))
                invoke.resolve(ret)
            }
            .addOnFailureListener { e ->
                invoke.reject("ML Kit failed: ${e.message}")
            }
    }

    /// content:// URI → software Bitmap (ML Kit rejects hardware bitmaps).
    private fun decodeBitmap(uri: Uri): Bitmap {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val source = ImageDecoder.createSource(activity.contentResolver, uri)
            ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }
        } else {
            @Suppress("DEPRECATION")
            MediaStore.Images.Media.getBitmap(activity.contentResolver, uri)
        }
    }

    /// Flatten blocks→lines, sort into reading order, join with \n.
    /// ML Kit does NOT guarantee reading order — same fix as desktop §9.3.
    private fun toReadingOrderedText(result: Text): String {
        val lines = result.textBlocks.flatMap { it.lines }
        val sorted = lines.sortedWith { a, b ->
            val aTop = a.boundingBox?.top ?: 0
            val bTop = b.boundingBox?.top ?: 0
            if (abs(aTop - bTop) < 10) {
                (a.boundingBox?.left ?: 0) - (b.boundingBox?.left ?: 0)
            } else {
                aTop - bTop
            }
        }
        return sorted.joinToString("\n") { it.text }
    }
}
```

Register in `gen/android/app/src/main/java/.../MainActivity.kt` is automatic via
`register_android_plugin` — no manual Activity edits needed.

---

## 4. normalize.rs (new service)

`src-tauri/src/services/normalize.rs`:

```rust
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
```

Register in `services/mod.rs`: `pub mod normalize;`

---

## 5. Command Layer

`src-tauri/src/commands/recognition.rs` (mobile version):

```rust
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
    let raw = mlkit.recognize(&uri).map_err(|e| AppError::Ocr(e.to_string()))?;
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
        &text, &qr_codes, &rules, image_hint.as_ref(),
    );
    let fields = recognition_service::extract_fields(
        &text, &invoice_type, from_qr, &qr_codes, &rules, image_hint.as_ref(),
    );
    let record = recognition_service::build_invoice_record(
        &fields, &invoice_type, &filename, &full_path, page_number,
    );

    let amount = fields.get("amount").and_then(|v| v.as_f64());
    tracing::info!("[image-ocr] 识别完成 类型={} 金额={:?}", invoice_type, amount);
    Ok(record)
}

/// 扫码路径：etrip 确认函二维码 → 记录（新增命令）。
/// ponytail: detect_invoice_type 的 etrip QR 分支以 text.contains("确认函") 为门控
/// （recognition_service.rs L43-62），扫码无文本，这里传 "确认函" 作合成信号进入 QR 分支。
/// ceiling: 仅 etripCar:// / etripHotel:// / etrip:// 系列；
///   增值税发票二维码（01,... 格式）后端未实现解析。
/// 升级路径: 在 recognition_service 增加 VAT QR 分支后，本命令改传真实文本即可。
#[tauri::command]
pub fn recognize_from_qr(
    qr: String,
    filename: String,
    full_path: String,
) -> Result<InvoiceRecord, AppError> {
    let rules = RulesConfig::load().map_err(AppError::RulesLoad)?;
    let qr_codes = vec![qr];
    let (invoice_type, from_qr) =
        recognition_service::detect_invoice_type("确认函", &qr_codes, &rules, None);
    let fields = recognition_service::extract_fields(
        "确认函", &invoice_type, from_qr, &qr_codes, &rules, None,
    );
    Ok(recognition_service::build_invoice_record(
        &fields, &invoice_type, &filename, &full_path, 1,
    ))
}
```

> 注：`recognize_image_uri` 的 `State<'_, MlkitText<tauri::Wry>>` 中 `Wry` 沿用 §2 插件定义；若移动端编译报 Runtime 不匹配，按编译器提示改为对应 Runtime 类型（§2 已有的小风险点）。

`src-tauri/src/error.rs`: 相对桌面版去掉 `PdfParse`/`QrRead`/`ExcelExport`（对应模块已删），
**保留 `Updater`**（update.rs 依赖），新增 `Ocr`（recognize_image_uri 用）：

```rust
use serde::Serialize;

#[derive(Debug, thiserror::Error, Serialize)]
#[serde(tag = "kind", content = "message")]
pub enum AppError {
    #[error("IO 错误: {0}")]
    #[serde(rename = "IO")]
    Io(String),
    #[error("规则加载失败: {0}")]
    #[serde(rename = "RulesLoad")]
    RulesLoad(String),
    #[error("数据库错误: {0}")]
    #[serde(rename = "Database")]
    Database(String),
    #[error("更新检查失败: {0}")]
    #[serde(rename = "Updater")]
    Updater(String),
    #[error("OCR 错误: {0}")]
    #[serde(rename = "Ocr")]
    Ocr(String),
}

impl From<std::io::Error> for AppError {
    fn from(e: std::io::Error) -> Self { Self::Io(e.to_string()) }
}
impl From<serde_json::Error> for AppError {
    fn from(e: serde_json::Error) -> Self { Self::Io(e.to_string()) }
}
impl From<rusqlite::Error> for AppError {
    fn from(e: rusqlite::Error) -> Self { Self::Database(e.to_string()) }
}
```

`src-tauri/src/commands/mod.rs`（移动端：去掉 `excel`、`pdf`）：

```rust
pub mod history;
pub mod recognition;
pub mod update;
```

`src-tauri/src/services/mod.rs`（移动端：去掉 `excel_service`、`pdf_service`；加 `normalize`）：

```rust
pub mod database;
pub mod expense_calculator;
pub mod normalize;
pub mod recognition_service;
```

`src-tauri/src/utils/mod.rs` 原样复制（`pub mod amount_converter;`）。

`src-tauri/src/lib.rs`:

```rust
mod commands;
mod config;
mod error;
mod models;
mod services;

use commands::update::PendingDownload;
use services::database::Database;
use std::sync::Mutex;
use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_barcode_scanner::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_mlkit_text::init())
        .manage(PendingDownload(Mutex::new(None)))
        .invoke_handler(tauri::generate_handler![
            commands::recognition::recognize_image_uri,
            commands::recognition::recognize_from_text,
            commands::recognition::recognize_from_qr,
            commands::history::save_history,
            commands::history::get_history_list,
            commands::history::get_history_detail,
            commands::history::delete_history,
            commands::update::check_for_update,
            commands::update::download_update,
            commands::update::install_update,
        ])
        .setup(|app| {
            let db = Database::open(app.handle())?;
            app.manage(db);
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

`database.rs` 唯一改动：`open()` 签名 + 路径来源。其余（`HistorySummary`/`HistoryDetail`
结构体、`save_history`/`get_history_list`/`get_history_detail`/`delete_history`、
`chrono_now`/`timestamp_to_ymdhms`/`days_to_date`/`is_leap` 工具函数）原样复制。
**删掉桌面版 `get_db_path()`**（基于 `current_exe()`，移动端不适用）：

```rust
pub fn open(app: &tauri::AppHandle) -> Result<Self, crate::error::AppError> {
    let dir = app
        .path()
        .app_data_dir()
        .map_err(|e| crate::error::AppError::Io(e.to_string()))?;
    std::fs::create_dir_all(&dir)?;
    let conn = rusqlite::Connection::open(dir.join("snap_claim.db"))?;
    conn.execute_batch("PRAGMA journal_mode=WAL;")?;
    // ……桌面版建表 SQL 原样（history_records + history_items + 两个索引）……
    Ok(Database { conn: std::sync::Mutex::new(conn) })
}
```

`lib.rs` setup 里 `Database::open(app.handle())` 与之对应。`commands/history.rs` 原样复制
（自带 `generate_name`/`days_to_date`/`is_leap`）。

---

## 6. Frontend

`src/lib/tauri.ts` (mobile subset):

```ts
import { invoke, convertFileSrc } from '@tauri-apps/api/core'
import { Channel } from '@tauri-apps/api/core'
import { scan, Format } from '@tauri-apps/plugin-barcode-scanner'
import type { InvoiceRecord, Totals, PreviewRow, HistorySummary, HistoryDetail, UpdateInfo } from '../types'

// ── 图片识别（NEW：OCR 源头换成 ML Kit 插件，其余与桌面 recognizeImage 同形）──
// 输入是 content:// URI（由 tauri-plugin-dialog 的 open() 在 Android 返回）。
export async function recognizeImage(
  uri: string,
  onRecord?: (record: InvoiceRecord) => void,
): Promise<InvoiceRecord[]> {
  const { splitOrderSegments, extractImageHint } = await import('../services/imageHint')
  const filename = uri.split('/').pop() ?? uri

  const rawText = await invoke<string>('recognize_image_uri', { uri })
  const segments = splitOrderSegments(rawText)

  if (segments.length === 0) {
    const record = await recognizeFromText(rawText, filename, uri, 1, null)
    onRecord?.(record)
    return [record]
  }

  const records: InvoiceRecord[] = []
  for (const seg of segments) {
    const hint = extractImageHint(seg)
    const record = await recognizeFromText(seg, filename, uri, 1, hint)
    onRecord?.(record)
    records.push(record)
  }
  return records
}

// 预览图片用：content:// URI → WebView 可加载的 URL（OCR 命令收的是原始 uri，不是这个）
export function uriToDisplay(uri: string): string {
  return convertFileSrc(uri)
}

// 与桌面版 recognizeFromText 逐字相同
export async function recognizeFromText(
  text: string,
  filename: string,
  fullPath: string,
  pageNumber: number,
  imageHint: { orderType: string; orderId: string; amount: number | null } | null = null,
): Promise<InvoiceRecord> {
  try {
    return await invoke<InvoiceRecord>('recognize_from_text', {
      text, filename, fullPath, pageNumber, imageHint,
    })
  } catch (e) {
    throw new Error(typeof e === 'string' ? e : JSON.stringify(e))
  }
}

// ── 扫码：官方插件扫 QR 字符串 → 新命令 recognize_from_qr 出记录（NEW）──
export async function scanInvoiceQr(): Promise<string | null> {
  const result = await scan({ windowed: false, formats: [Format.QRCode] })
  return result.content || null
}

export async function recognizeFromQr(
  qr: string,
  filename = 'qr',
  fullPath = '',
): Promise<InvoiceRecord> {
  try {
    return await invoke<InvoiceRecord>('recognize_from_qr', { qr, filename, fullPath })
  } catch (e) {
    throw new Error(typeof e === 'string' ? e : JSON.stringify(e))
  }
}

// ── 历史记录：与桌面版逐字相同 ──
// saveHistory / getHistoryList / getHistoryDetail / deleteHistory —— 复制桌面实现
// （见 snap-claim-rs/src/lib/tauri.ts）

// ── 自动更新：与桌面版逐字相同（checkForUpdate / downloadUpdate / installDownloadedUpdate）──
// 连同 DownloadProgressEvent 接口一并搬过来。UpdateDialog + UpdateProgressWidget 组件
// 搬过来改移动端样式即可，update.rs 三命令 + Channel 进度事件 Android 上行为一致，
// 区别仅在 install 时桌面是重启安装、Android 是拉起系统包安装器。
```

> **删除的桌面函数**（移动端不需要）：`pickFiles`、`readImageBytes`、`mimeFromExt`、
> `mergePdfs`、`exportExcel`、`recognizeInvoices`、`isImagePath`、`isPdfPath`、`IMAGE_EXTS`、`pickSavePath`。
> 新增 `pickImage`（gallery 走 dialog，返回 content URI）；`pickFiles` 不搬——桌面版
> 同时处理图片+PDF，移动端无 PDF，单写一个更直白。

`src/lib/tauri.ts` 补 `pickImage`（gallery 主路径，dialog 返回 content URI）：

```ts
import { open } from '@tauri-apps/plugin-dialog'

export async function pickImage(): Promise<string | null> {
  const selected = await open({
    multiple: false,
    // ponytail: 不加 filters.directory —— Android Photo Picker 走系统 UI，
    // extensions 过滤在 content URI 上不可靠；后端 ML Kit 自己解码，扩展名不重要。
    filters: [{ name: '图片', extensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'] }],
  })
  return typeof selected === 'string' ? selected : null
}
```

`src/pages/CapturePage.tsx` 输入获取（gallery 走 dialog 主路径，相机走 `<input capture>`）：

```tsx
import { pickImage, recognizeImage, uriToDisplay } from '../lib/tauri'

// 相册：dialog.open() 在 Android 返回 content:// URI，直接喂给 recognize_image_uri
<button onClick={async () => {
  const uri = await pickImage()
  if (uri) handleImageUri(uri)
}}>从相册选择</button>

// 拍照：WebView 原生 <input capture>，零原生代码
// ponytail: M1 真机验证 <input capture> 返回的 URI 是否能喂给 ML Kit；
//   不行则切到 tauri-plugin-camera（已知可行，但多一个原生插件依赖）。
<input
  type="file"
  accept="image/*"
  capture="environment"
  onChange={(e) => {
    const file = e.target.files?.[0]
    if (file) handleImageUri(URL.createObjectURL(file))
  }}
  style={{ display: 'none' }}
/>
```

> **为什么 gallery 不用 `<input type="file">`**：Android WebView 的 `<input type=file>`
> 返回的是 blob:// URL 或无路径的 File 对象，传给 Rust 侧 ML Kit 无法解码
> （需要 content:// URI 让 Kotlin 用 ContentResolver 读）。`dialog.open()` 直接
> 返回 content:// URI，与 `recognize_image_uri` 命令的入参形状一致，零转换。

---

## 7. tauri.conf.json Deltas

```json
{
  "productName": "SnapClaim Mobile",
  "identifier": "cn.sanxiaoxing.snapclaim",
  "app": {
    "windows": [{ "title": "SnapClaim", "width": 400, "height": 800 }],
    "security": { "csp": null }
  },
  "bundle": {
    "active": true,
    "targets": ["apk", "aab"],
    "android": { "minSdkVersion": 26 },
    "createUpdaterArtifacts": true
  },
  "plugins": {
    "updater": {
      "active": true,
      "endpoints": [
        "https://cdn.crabnebula.app/update/{ORG}/snapclaim-android/{{target}}-{{arch}}/{{current_version}}"
      ],
      "dialog": false,
      "pubkey": "<~/.tauri/snapclaim-android.key.pub 内容>"
    }
  }
}
```

要点：
- `dialog: false` —— 复用桌面自研 UpdateDialog 流程（检查 → 弹窗 → 下载进度 → 安装）
- Android 上 `install()` 拉起系统包安装器，用户点一次确认
- **两层签名缺一不可**：updater 私钥签发布包（CrabNebula Action 做）+ Android keystore 签 APK（丢了用户只能卸载重装，keystore 务必备份）

`capabilities/default.json` 需声明权限：

```json
{
  "permissions": [
    "barcode-scanner:allow-scan",
    "dialog:default",
    "updater:allow-check",
    "updater:allow-download",
    "updater:allow-install"
  ]
}
```

Android 权限（`gen/android/app/src/main/AndroidManifest.xml`）：

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
<!-- 读图：Photo Picker 无需权限；若走 MediaStore 旧路径补 READ_MEDIA_IMAGES -->
```

发布管线：CrabNebula Cloud GitHub Action（构建 + updater 签名 + draft release），
release 发布后全量设备下次检查即可见。与桌面版更新渠道互相独立。

---

## 8. Milestone Tasks

### M1 — Skeleton + Plugin（目标：拍到文字）

1. §1 脚手架跑通 `tauri android dev` 黑屏 → Hello 页
2. §2/§3 插件写完，`recognize_image_uri("content://...")` 在真机返回文本
3. `<input capture>` 真机验证（失败则切 plugin-dialog）
4. **验收**：拍一张发票照片，屏幕上显示 ML Kit 原始文本

### M2 — Rules Integration（目标：出记录）

1. vendor 复制 §0 表格全部文件
2. §4 normalize + §5 命令接好
3. **验收**：已知发票照片 → `InvoiceRecord.type == "invoice"` 且金额正确；
   发票二维码 → 走 `from_qr` 路径，不经过 OCR 文本匹配

### M3 — Full Flow（目标：算对账）

1. 4 个页面 + 日期区间 + 用车分类弹窗
2. **验收**：同一批输入，移动端 `Totals` 与桌面端逐项相等

### M4 — History（目标：存得住）

1. database.rs（§5 改动）+ history 命令
2. **验收**：保存/列表/详情/删除全通；数据库 schema 与桌面一致

### M5 — Updates（目标：发得出去、装得回来）

1. `npm run tauri signer generate` 生成密钥对，pubkey 写入 §7 配置
2. CrabNebula Cloud 建 app，接 GitHub Action 发布管线
3. Android keystore 生成 + 备份（`keytool -genkey`），构建签名 APK
4. 装 v0.1.0 → 发布 v0.1.1 → 应用内检查更新 → 下载 → 系统安装器完成升级
5. **验收**：真机走完「检查 → 弹窗 → 下载进度 → 安装 → 版本号变化」全链路

---

## 9. Explicitly Not Planned

- Excel/PDF 导出、PDF 识别、合并
- 应用市场上架（分发 = sideload APK + CrabNebula 应用内更新）
- iOS、KMP、Flutter
- 服务端 OCR
- Rust 端跑 PaddleOCR（已验证失败，见 desktop 回退记录）
- 增值税发票二维码字段解析（recognition_service.rs 的 `from_qr` 路径仅识别
  etrip 确认函 QR；VAT 发票 QR `01,kind,code,number,...` 后端未实现拆字段。
  升级路径：先在 recognition_service.rs 加 VAT QR 分支，移动端 `recognize_from_qr`
  改传真实 QR 文本即可，无需改命令签名）
