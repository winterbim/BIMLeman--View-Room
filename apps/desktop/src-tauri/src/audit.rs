use serde::Deserialize;
use std::path::PathBuf;

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AuditInput {
    pub actor: String,
    pub action: String,
    pub result: String,
    pub computer_id: Option<String>,
    pub room_id: Option<String>,
}

pub fn append_audit(event: AuditInput) -> Result<(), String> {
    validate_audit(&event)?;
    let path = audit_path()?;
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|_| "Dossier de journal inaccessible.".to_string())?;
    }
    let line = serde_json::json!({
        "at": chrono_lite_timestamp(),
        "actor": event.actor,
        "action": event.action,
        "result": event.result,
        "computerId": event.computer_id,
        "roomId": event.room_id
    });
    use std::io::Write;
    let mut file = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .map_err(|_| "Journal d'audit inaccessible.".to_string())?;
    writeln!(file, "{line}").map_err(|_| "Écriture du journal impossible.".to_string())?;
    Ok(())
}

fn validate_audit(event: &AuditInput) -> Result<(), String> {
    let allowed = [
        "probe", "view", "control", "lock", "unlock", "message", "openWebsite", "reboot", "shutdown",
    ];
    if !allowed.contains(&event.action.as_str()) {
        return Err("Action d'audit inconnue.".into());
    }
    if event.result != "success" && event.result != "failure" {
        return Err("Résultat d'audit invalide.".into());
    }
    for value in [&event.actor, &event.action, event.computer_id.as_deref().unwrap_or(""), event.room_id.as_deref().unwrap_or("")] {
        if value.len() > 80 || value.contains("PRIVATE") || value.contains("data:image") || value.contains('\n') {
            return Err("Événement d'audit refusé.".into());
        }
    }
    Ok(())
}

fn audit_path() -> Result<PathBuf, String> {
    if let Ok(path) = std::env::var("BIMLEMAN_AUDIT_PATH") {
        return Ok(PathBuf::from(path));
    }
    if cfg!(target_os = "windows") {
        Ok(PathBuf::from(r"C:\ProgramData\BIMLeman\ViewRoom\audit.jsonl"))
    } else {
        Ok(PathBuf::from("runtime/audit.jsonl"))
    }
}

fn chrono_lite_timestamp() -> String {
    let seconds = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .unwrap_or(0);
    format!("{seconds}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn audit_rejects_screen_and_secrets() {
        let mut event = AuditInput {
            actor: "formateur".into(),
            action: "message".into(),
            result: "success".into(),
            computer_id: Some("A-01".into()),
            room_id: Some("room-a".into()),
        };
        assert!(validate_audit(&event).is_ok());
        event.actor = "-----BEGIN PRIVATE KEY-----".into();
        assert!(validate_audit(&event).is_err());
        event.actor = "formateur".into();
        event.action = "data:image/png;base64".into();
        assert!(validate_audit(&event).is_err());
    }
}
