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
    #[error("更新检查失败: {0}")]
    #[serde(rename = "Updater")]
    Updater(String),
    #[error("数据库错误: {0}")]
    #[serde(rename = "Database")]
    Database(String),
    #[error("OCR 识别失败: {0}")]
    #[serde(rename = "Ocr")]
    Ocr(String),
}

impl From<std::io::Error> for AppError {
    fn from(e: std::io::Error) -> Self {
        Self::Io(e.to_string())
    }
}

impl From<serde_json::Error> for AppError {
    fn from(e: serde_json::Error) -> Self {
        Self::Io(e.to_string())
    }
}

impl From<rusqlite::Error> for AppError {
    fn from(e: rusqlite::Error) -> Self {
        Self::Database(e.to_string())
    }
}
