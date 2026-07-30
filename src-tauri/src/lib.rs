mod commands;
mod config;
mod error;
mod models;
mod services;
mod utils;

use commands::update::PendingDownload;
use services::database::Database;
use std::sync::Mutex;
use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .init();

    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_mlkit_text::init())
        .manage(PendingDownload(Mutex::new(None)))
        .invoke_handler(tauri::generate_handler![
            commands::recognition::recognize_image_uri,
            commands::recognition::recognize_from_text,
            commands::recognition::recognize_from_qr,
            commands::update::check_for_update,
            commands::update::download_update,
            commands::update::install_update,
            commands::history::save_history,
            commands::history::get_history_list,
            commands::history::get_history_detail,
            commands::history::delete_history,
        ])
        .setup(|app| {
            let database = Database::open(app.handle()).map_err(|e| {
                tracing::error!("failed to open database: {}", e);
                e
            })?;
            app.manage(database);
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
