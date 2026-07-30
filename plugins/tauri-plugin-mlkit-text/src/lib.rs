use serde::{Deserialize, Serialize};
use tauri::{
    plugin::{Builder, PluginHandle, TauriPlugin},
    Runtime,
};

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("ML Kit inference failed: {0}")]
    Inference(String),
    #[error("ML Kit plugin not available on this platform")]
    Unavailable,
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
    /// ponytail: run_mobile_plugin 是 mobile 专有 API，桌面编译时返回 Unavailable。
    ///   移动端编译时走真 API；桌面端仅用于 UI 开发预览，不会真正调用。
    pub fn recognize(&self, uri: &str) -> Result<String, Error> {
        #[cfg(mobile)]
        {
            let resp = self
                .0
                .run_mobile_plugin::<RecognizeResponse>(
                    "recognize",
                    RecognizeArgs {
                        uri: uri.to_string(),
                    },
                )
                .map_err(|e| Error::Inference(e.to_string()))?;
            Ok(resp.text)
        }
        #[cfg(not(mobile))]
        {
            let _ = uri;
            Err(Error::Unavailable)
        }
    }
}

/// Registers the Kotlin plugin class. Package must match the Kotlin file's
/// `package` declaration and `tauri.conf.json` identifier suffix.
pub fn init<R: Runtime>() -> TauriPlugin<R> {
    Builder::new("mlkit-text")
        .setup(|_app, api| {
            #[cfg(mobile)]
            {
                let handle = api.register_android_plugin(
                    "cn.sanxiaoxing.snapclaim.plugin",
                    "MlkitTextPlugin",
                )?;
                _app.manage(MlkitText(handle));
            }
            Ok(())
        })
        .build()
}
