mod audit;
mod hosts;
mod veyon;
mod webapi;

use audit::AuditInput;
use serde::Serialize;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct PlatformInfo {
    os: String,
    veyon_found: bool,
    mode: String,
}

struct AppState {
    webapi: webapi::WebApi,
}

#[tauri::command]
fn platform_info() -> PlatformInfo {
    let found = veyon::veyon_cli_path().is_some();
    let real = cfg!(target_os = "windows") && found;
    PlatformInfo {
        os: std::env::consts::OS.to_string(),
        veyon_found: found,
        mode: if real { "real" } else { "mock" }.to_string(),
    }
}

#[tauri::command]
fn check_veyon_host(host: String) -> Result<bool, String> {
    veyon::check_port(&host)
}

#[tauri::command]
fn open_remote_view(host: String) -> Result<(), String> {
    veyon::open_remote("view", &host)
}

#[tauri::command]
fn open_remote_control(host: String) -> Result<(), String> {
    veyon::open_remote("control", &host)
}

#[tauri::command]
async fn webapi_thumbnail(state: tauri::State<'_, AppState>, host: String) -> Result<String, String> {
    state.webapi.thumbnail(&host).await
}

#[tauri::command]
async fn webapi_feature(
    state: tauri::State<'_, AppState>,
    host: String,
    action: String,
    payload: Option<String>,
) -> Result<(), String> {
    state.webapi.feature(&host, &action, payload).await
}

#[tauri::command]
fn append_audit(event: AuditInput) -> Result<(), String> {
    audit::append_audit(event)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let application = tauri::Builder::default()
        .manage(AppState {
            webapi: webapi::WebApi::new(),
        })
        .invoke_handler(tauri::generate_handler![
            platform_info,
            check_veyon_host,
            open_remote_view,
            open_remote_control,
            webapi_thumbnail,
            webapi_feature,
            append_audit
        ])
        .run(tauri::generate_context!());
    if let Err(error) = application {
        eprintln!("BIMLéman View Room a quitté avec une erreur: {error}");
        std::process::exit(1);
    }
}
