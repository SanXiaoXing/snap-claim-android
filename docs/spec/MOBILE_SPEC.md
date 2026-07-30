# SnapClaim Mobile Specification

> Version: 1.0.0
> Status: Proposed
> Target: SnapClaim Mobile 0.1.0 (new repository)
> Platform: Android First (iOS explicitly out of scope)
> Runtime: Tauri 2 Mobile + Rust + React + TypeScript + ML Kit

---

## 1. Overview

SnapClaim Mobile is a companion application for on-the-go expense capture:
take a photo of an invoice or order screenshot, recognize it locally, and store
the structured record. It is built in a **new repository**, sharing no build
with the desktop app, but reusing the desktop's core business logic verbatim.

Key decisions that shape this spec:

- **Tauri 2 Mobile** (not pure-native Kotlin): keeps the React/TS frontend stack
  and, more importantly, keeps the rules engine in Rust — zero porting, zero drift.
- **ML Kit for OCR** (not PaddleOCR.js/WASM, not Rust-ported PaddleOCR):
  platform-native inference is free, offline, millisecond-level, and accurate
  for Chinese text. The failed Rust PaddleOCR port (see desktop history) is
  not retried.
- **Feature subset**: capture + recognize + history. No Excel export, no PDF
  merge, no PDF recognition, no auto-updater.

---

## 2. Goals

### 2.1 Primary Goals

The system MUST:

1. Capture invoice/order images via camera (CameraX through WebView input or plugin).
2. Pick images from gallery (Photo Picker / file dialog).
3. Recognize text locally on-device via ML Kit Text Recognition (Chinese model).
4. Scan invoice QR codes via ML Kit Barcode Scanning.
5. Parse recognized text into `InvoiceRecord` using the **same rules engine
   code as desktop** (`recognition_service.rs` + `rules.yaml`), unmodified.
6. Compute expense totals using the desktop `expense_calculator.rs`, unmodified.
7. Persist history records in a local SQLite database (same schema as desktop).
8. Support long-screenshot order splitting (`splitOrderSegments` logic).
9. Support car-record sub-classification (市内交通 / 往返交通, `is_round_trip`).
10. Support trip date-range selection driving `days`-based subsidy calculation.
11. Work fully offline after installation.
12. Prompt for in-app updates distributed outside app markets (CrabNebula Cloud
    + tauri-plugin-updater, sideload APK install).

### 2.2 Secondary Goals

The system SHOULD:

1. Prefer the QR fast path when an invoice QR code is present (higher accuracy
   than OCR text matching).
2. Keep `InvoiceRecord` JSON field names identical to desktop for future
   interop (e.g., phone captures → desktop aggregates).
3. Keep startup OCR-free: ML Kit model loads lazily on first recognition.

---

## 3. Non-Goals

The system MUST NOT (in v1):

1. Export Excel (.xlsx) reports.
2. Merge or parse PDF files.
3. Distribute through app markets (Google Play / 国内厂商商店) — distribution
   is sideload APK + in-app update prompts instead (§14).
4. iOS support.
5. Cloud sync, accounts, multi-device.
6. Server-side OCR.
7. Native menus, drag-drop, file associations (desktop-only interactions).

---

## 4. Core Design Principles

### 4.1 Rules Engine Is the Product — Keep It in Rust

`recognition_service.rs` (474 lines), `expense_calculator.rs` (234 lines), and
`rules.yaml` (84 lines) are copied into the new repo **verbatim**. All parsing
improvements happen in one codebase lineage; the mobile repo tracks the
desktop repo's `src-tauri/src/services/` and `src-tauri/src/config/` manually
(vendor copy, not shared crate — two repos, no build coupling).

### 4.2 OCR Is a Replaceable Edge

OCR sits at the system boundary behind one Rust command. Desktop uses
PaddleOCR.js; mobile uses ML Kit. The rules engine never sees the OCR engine —
only normalized plain text.

### 4.3 Normalize Before Rules

ML Kit output differs from PaddleOCR output (line granularity, CJK/latin
spacing, full/half-width symbols). A **normalization layer** runs between OCR
text and the rules engine so `rules.yaml` patterns stay valid without
platform-specific forks (see §10).

### 4.4 Reading Order Is Not Free

Neither ML Kit nor paddle-ocr-rs guarantees reading order (lesson from the
failed Rust port). Text blocks/lines MUST be sorted by position —
clustered into lines by y-coordinate, sorted left-to-right within each line —
before joining into text (see §9.3).

---

## 5. Technology Stack

| Layer | Choice | Notes |
|---|---|---|
| Shell | Tauri 2 Mobile (`tauri android`) | New repo, Android only |
| Frontend | React 19 + TypeScript + Tailwind | Mobile UI rewritten; services patterns carried over |
| Backend | Rust (same crate layout as desktop `src-tauri`) | Commands + services + models |
| OCR | ML Kit Text Recognition v2 (Chinese) | Via custom Tauri plugin (§9) |
| QR | `tauri-plugin-barcode-scanner` | Official plugin, wraps ML Kit Barcode |
| Camera | WebView `<input capture>` first; CameraX via plugin if insufficient | Decide in milestone M1 |
| Gallery | `tauri-plugin-dialog` file picker / Photo Picker | Returns content URI |
| Database | rusqlite (bundled SQLite) | Same schema as desktop |
| Rules | `rules.yaml` via serde_yaml | Verbatim copy from desktop |
| Updates | `tauri-plugin-updater` + CrabNebula Cloud | Sideload APK install (§14); updater supports Android |

---

## 6. Repository Layout

```
snap-claim-mobile/
├── src/                          # React frontend (mobile UI)
│   ├── pages/                    # Capture, Records, History, HistoryDetail
│   ├── components/
│   ├── lib/tauri.ts              # invoke wrappers (mobile subset)
│   └── services/
│       └── imageHint.ts          # splitOrderSegments + extractImageHint (ported, 75 lines)
├── src-tauri/
│   ├── src/
│   │   ├── commands/
│   │   │   ├── recognition.rs    # recognize_image_uri, recognize_from_text, recognize_from_qr, history cmds
│   │   │   └── history.rs        # copied from desktop
│   │   ├── services/
│   │   │   ├── recognition_service.rs  # VERBATIM from desktop
│   │   │   ├── expense_calculator.rs   # VERBATIM from desktop
│   │   │   ├── normalize.rs            # NEW: ML Kit text normalization (§10)
│   │   │   └── database.rs             # desktop schema; path → app_data_dir
│   │   ├── config/rules.yaml           # VERBATIM from desktop
│   │   └── models/mod.rs               # InvoiceRecord etc., VERBATIM
│   └── capabilities/
└── plugins/
    └── tauri-plugin-mlkit-text/  # The only net-new native component (§9)
        ├── src/lib.rs
        └── android/src/main/java/.../MlkitTextPlugin.kt
```

---

## 7. Recognition Architecture

```
┌─────────────┐   photo / gallery / QR scan
│  React UI   │──────────────┐
└─────────────┘              ↓
                    ┌─────────────────┐
                    │  Rust commands  │
                    └─────────────────┘
                       │            │
              images → │            │ ← QR string (barcode plugin)
                       ↓            │
              ┌─────────────────┐   │
              │ ML Kit plugin   │   │
              │ (Kotlin)        │   │
              │ · decode bitmap │   │
              │ · ML Kit infer  │   │
              │ · sort lines    │   │
              └─────────────────┘   │
                       │ raw text   │
                       ↓            ↓
              ┌──────────────────────────┐
              │ normalize.rs (§10)       │
              └──────────────────────────┘
                       ↓
              splitOrderSegments (if long screenshot)
                       ↓ per segment
              ┌──────────────────────────┐
              │ recognition_service.rs   │
              │ detect_invoice_type      │
              │ extract_fields           │
              │ build_invoice_record     │
              └──────────────────────────┘
                       ↓ InvoiceRecord(s)
              expense_calculator.rs → Totals
                       ↓
              database.rs (history)
```

### 7.1 QR Fast Path

Chinese VAT invoice QR codes encode a structured string
(`01,kind,code,number,amount,date,checksum,...`). When a QR is found
(camera frame or image), the record is built **from QR fields directly**
(existing `from_qr` path in `recognition_service.rs`), skipping OCR text
matching. This is strictly more accurate than the desktop image path.

Flow: scan/photo → try barcode first → if invoice QR found, use it;
else fall back to ML Kit OCR path.

---

## 8. Image Input Handling

### 8.1 Content URIs, Not File Paths

Android delivers images as `content://` URIs. The desktop assumption
"everything is a filesystem path" does not hold. Therefore:

- The Rust command takes a URI string: `recognize_image_uri(uri: String)`.
- The **Kotlin plugin resolves the URI** to a `Bitmap` via
  `ContentResolver`, runs ML Kit, returns text. Rust never touches the bytes.
- Camera capture: WebView `<input type="file" accept="image/*" capture="environment">`
  is the first choice (zero native code). If reliability is insufficient in M1,
  add CameraX to the plugin behind the same command.

### 8.2 Supported Formats

JPEG, PNG, WebP, HEIC (via `ImageDecoder`). No PDF (non-goal).

---

## 9. ML Kit Text Plugin (tauri-plugin-mlkit-text)

The only net-new component.

### 9.1 Responsibilities (Kotlin side)

1. Resolve `content://` URI → `Bitmap` (`ImageDecoder.decodeBitmap`).
2. Run ML Kit Text Recognition with `ChineseTextRecognizerOptions`.
3. Collect `Text.Line` results with bounding boxes.
4. **Sort into reading order** (§9.3).
5. Return joined plain text (one line per `\n`).

### 9.2 Interface

```rust
// Rust side — single command, mirrors desktop's OCR boundary
#[tauri::command]
async fn recognize_image_uri(uri: String) -> Result<String, AppError>
```

```kotlin
// Kotlin side (sketch)
class MlkitTextPlugin(private val activity: Activity) {
    fun recognize(uri: String): String {
        val bitmap = decodeUri(uri)
        val lines = recognizer.process(bitmap, 0).get().textBlocks
            .flatMap { it.lines }
        return sortReadingOrder(lines).joinToString("\n") { it.text }
    }
}
```

### 9.3 Reading-Order Sort (mandatory)

```
lines.sort: group by boundingBox.top (tolerance ~10px = same line),
then by boundingBox.left within each group.
```

Same algorithm as the fix applied (and later reverted with the whole port) on
desktop. Skipping this scrambles text order and silently breaks `rules.yaml`
position-sensitive patterns.

### 9.4 Model Distribution: Bundled, Not Unbundled

ML Kit offers two delivery modes:

- **Unbundled**: model delivered by Google Play Services on first use.
  Fails on devices without GMS (Huawei and other mainland-CN devices).
- **Bundled**: model packed into the APK (+~4 MB).

**Decision: bundled.** Target users are mainland-China; GMS cannot be assumed.

```kotlin
// bundled: com.google.mlkit:text-recognition-chinese:16.0.x
val options = ChineseTextRecognizerOptions.Builder().build()
```

---

## 10. Text Normalization Layer (normalize.rs)

ML Kit output ≠ PaddleOCR output. Before rules matching, normalize:

| Rule | Example |
|---|---|
| Collapse spaces between CJK chars | `发 票` → `发票` |
| Unify full/half-width colon | `：` → `:` (or keep both in patterns — already the case) |
| Unify currency symbol | `￥` → `¥` |
| Trim per-line, drop empty lines | |

Keep the layer **small and additive**: each rule exists only to fix a mismatch
observed against `rules.yaml`. Do not pre-build a general unicode normalizer.

Fallback (if normalization proves insufficient in practice): add
`mobile_overrides:` section to `rules.yaml`. Deferred until needed.

---

## 11. Data Model

`InvoiceRecord`, `Totals`, `PreviewRow`, `RecognitionResult`, `HistorySummary`,
`HistoryDetail` — copied verbatim from desktop `src-tauri/src/models/mod.rs`.
JSON field names identical (serde camelCase), so mobile history exports could
be consumed by desktop later.

`full_path` semantics change: holds the content URI or an app-private cached
file path on Android. Downstream code only uses it as an opaque identifier —
no filesystem assumptions allowed.

---

## 12. Database

Same two tables as desktop (`history_records`, `history_items`), same column
set. Location: `app_data_dir/snap_claim.db` via `app.path().app_data_dir()`
(desktop uses its own resolution — the only intentional diff in database.rs).

rusqlite `bundled` feature — SQLite compiles into the app, no system
dependency. Already proven to work on Android targets.

---

## 13. UI / UX

Four screens (vs desktop's single-window layout):

1. **Capture**: camera button + gallery button + scan-QR button. Recent
   records list below.
2. **Records**: current recognition results; trip date-range picker (drives
   `days`); car-classification entry when car records exist (市内/往返 —
   required, totals depend on `is_round_trip`).
3. **History**: saved record list (name, date range, totals).
4. **History Detail**: read-only record view.

UI is a rewrite, not a port: desktop panels/tables don't fit mobile.
`lib/tauri.ts` wrapper pattern and `services/imageHint.ts` carry over.

---

## 14. Distribution & Updates

Distribution bypasses app markets entirely: users install the APK directly
(sideload). Update delivery uses **CrabNebula Cloud + tauri-plugin-updater**,
which supports Android.

### 14.1 Flow

1. App launch + manual "检查更新" both call `check_for_update`.
2. Updater queries the CrabNebula endpoint; on new version, the frontend shows
   an update dialog (same component pattern as desktop `UpdateDialog`).
3. User confirms → download with progress → `install_update`.
4. On Android, `Update::install()` hands the signed APK to the **system package
   installer**; the user taps through the standard install sheet.

### 14.2 Requirements

- **Updater signature**: keypair via `cargo tauri signer generate`; pubkey in
  `tauri.conf.json`, private key signs releases (same as desktop).
- **Android keystore**: the APK must always be signed with the SAME keystore,
  or Android refuses the update install. This is independent of the updater
  signature — two signing layers, both mandatory.
- **Permission**: `REQUEST_INSTALL_PACKAGES` in AndroidManifest (Android asks
  the user once to allow installs from this app).
- **Endpoint**:
  `https://cdn.crabnebula.app/update/{ORG}/{APP}/{{target}}-{{arch}}/{{current_version}}`

### 14.3 Release Pipeline

CrabNebula Cloud GitHub Action builds + signs + drafts the release; publishing
makes it available to all installs on next update check. Same release cadence
as desktop, independent version numbers.

---

## 15. Tauri Commands (mobile subset)

| Command | Source |
|---|---|
| `recognize_image_uri(uri)` → records via events | NEW (wraps ML Kit plugin + rules) |
| `recognize_from_text(...)` | copied from desktop (used per segment after split) |
| `recognize_from_qr(qr, filename, full_path)` → `InvoiceRecord` | NEW (扫码路径，合成 "确认函" 文本走 etrip QR 分支；见 plan §5) |
| `save_history` / `get_history_list` / `get_history_detail` / `delete_history` | copied from desktop |
| `check_for_update` / `download_update` / `install_update` | copied from desktop (§14) |
| `scan` (barcode plugin API) | official plugin (`@tauri-apps/plugin-barcode-scanner`) |

Events `recognition://record` and `recognition://progress` reused for
incremental UI updates, same as desktop.

---

## 16. Build & Toolchain

One-time environment setup:

```bash
rustup target add aarch64-linux-android armv7-linux-androideabi
# Android Studio + SDK + NDK (via SDK Manager)
npm run tauri android init
npm run tauri android dev        # device/emulator
npm run tauri android build      # APK/AAB
```

---

## 17. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| ML Kit accuracy differs from PaddleOCR on order screenshots | Normalization layer (§10); QR fast path (§7.1); tune `rules.yaml` jointly after M2 with real samples |
| Plugin JNI/Kotlin bridge is new territory | Single command, narrow interface; official barcode plugin source as reference template |
| `<input capture>` camera reliability varies by WebView | M1 validates on a real device first; CameraX fallback planned |
| GMS-less devices | Bundled ML Kit model (§9.4) — no Play Services dependency |
| Sideload update friction | Updater APK install requires one-time "allow installs from this app" grant; keystore must be backed up — losing it means all users must reinstall |
| Rules drift between repos over time | rules.yaml changes reviewed against both repos; mobile tracks desktop as upstream |

---

## 18. Milestones

| Milestone | Deliverable | Exit Criteria |
|---|---|---|
| M1 | Skeleton + plugin | `tauri android dev` runs; camera input → ML Kit → raw text on screen |
| M2 | Rules integration | Photo of known invoice → correct `InvoiceRecord` (type + amount); QR invoice → QR fast path record |
| M3 | Full flow | Records list, date range, car classification, totals correct vs desktop for same inputs |
| M4 | History | Save/list/detail/delete via SQLite; schema verified identical to desktop |
| M5 | Updates | CrabNebula release published; test APK on device detects, downloads, and installs an update |

---

## 19. Open Questions

1. CameraX vs `<input capture>` — decided in M1 by device testing.
2. Batch capture (multiple photos before one recognition run) — v1.1?
3. History export/import between mobile and desktop — out of scope, model
   alignment keeps the door open.
