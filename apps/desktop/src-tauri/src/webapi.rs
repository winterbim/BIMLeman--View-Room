use crate::hosts::require_allowed_host;
use base64::Engine;
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Mutex;
use std::time::{Duration, Instant};

const AUTH_KEYS_METHOD: &str = "0c69b301-81b4-42d6-8fae-128cdd113314";
const SCREEN_LOCK: &str = "ccb535a2-1d24-4cc1-a709-8b47d2b2ac79";
const REBOOT: &str = "4f7d98f0-395a-4fff-b968-e49b8d0f748c";
const POWER_DOWN: &str = "6f5a27a0-0e2f-496e-afcc-7aae62eede10";
const OPEN_WEBSITE: &str = "8a11a75d-b3db-48b6-b9cb-f8422ddd5b0c";
const TEXT_MESSAGE: &str = "e75ae9c8-ac17-4d00-8f0d-019348346208";

#[derive(Clone)]
struct CachedConnection {
    uid: String,
    refreshed_at: Instant,
}

pub struct WebApi {
    http: reqwest::Client,
    connections: Mutex<HashMap<String, CachedConnection>>,
    key_cache: Mutex<Option<String>>,
}

pub struct FeatureCall {
    pub uuid: String,
    pub body: Value,
}

impl WebApi {
    pub fn new() -> Self {
        let http = reqwest::Client::builder()
            .timeout(Duration::from_secs(8))
            .connect_timeout(Duration::from_secs(3))
            .redirect(reqwest::redirect::Policy::none())
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());
        Self {
            http,
            connections: Mutex::new(HashMap::new()),
            key_cache: Mutex::new(None),
        }
    }

    pub async fn thumbnail(&self, host: &str) -> Result<String, String> {
        require_allowed_host(host)?;
        let base = webapi_base()?;
        crate::veyon::ensure_local_webapi().await?;
        let bytes = match self.framebuffer(&base, host, false).await {
            Err(message) if message == "session-expired" => {
                self.invalidate(host);
                self.framebuffer(&base, host, true).await?
            }
            other => other?,
        };
        if bytes.len() > 2_000_000 {
            return Err("Miniature trop volumineuse.".into());
        }
        let encoded = base64::engine::general_purpose::STANDARD.encode(bytes);
        Ok(format!("data:image/jpeg;base64,{encoded}"))
    }

    pub async fn feature(&self, host: &str, action: &str, payload: Option<String>) -> Result<(), String> {
        require_allowed_host(host)?;
        let call = feature_call(action, payload.as_deref())?;
        let base = webapi_base()?;
        crate::veyon::ensure_local_webapi().await?;
        match self.put_feature(&base, host, &call).await {
            Err(message) if message == "session-expired" => {
                self.invalidate(host);
                self.put_feature(&base, host, &call).await
            }
            other => other,
        }
    }

    async fn framebuffer(&self, base: &str, host: &str, force: bool) -> Result<Vec<u8>, String> {
        let uid = self.connection_uid(base, host, force).await?;
        let response = self
            .http
            .get(format!("{base}/api/v1/framebuffer?format=jpeg&quality=40&width=320"))
            .header("Connection-Uid", &uid)
            .send()
            .await
            .map_err(|error| format!("Miniature injoignable : {}", redact(&error.to_string())))?;
        let status = response.status();
        if status.as_u16() == 401 {
            return Err("session-expired".into());
        }
        if !status.is_success() {
            return Err(format!("Miniature refusée ({status})."));
        }
        response
            .bytes()
            .await
            .map(|bytes| bytes.to_vec())
            .map_err(|_| "Lecture de la miniature impossible.".to_string())
    }

    async fn put_feature(&self, base: &str, host: &str, call: &FeatureCall) -> Result<(), String> {
        let uid = self.connection_uid(base, host, false).await?;
        let response = self
            .http
            .put(format!("{base}/api/v1/feature/{}", call.uuid))
            .header("Connection-Uid", &uid)
            .json(&call.body)
            .send()
            .await
            .map_err(|error| format!("Fonction Veyon injoignable : {}", redact(&error.to_string())))?;
        ensure_success(response).await
    }

    async fn connection_uid(&self, base: &str, host: &str, force: bool) -> Result<String, String> {
        if !force {
            if let Some(uid) = self.cached_uid(host) {
                return Ok(uid);
            }
        } else {
            self.invalidate(host);
        }
        let key = self.private_key()?;
        let response = self
            .http
            .post(format!("{base}/api/v1/authentication/{host}"))
            .json(&json!({
                "method": AUTH_KEYS_METHOD,
                "credentials": { "keyname": key_name(), "keydata": key }
            }))
            .send()
            .await
            .map_err(|_| "WebAPI local injoignable. Vérifiez que Veyon est démarré sur le poste formateur.".to_string())?;
        let status = response.status();
        if status.as_u16() == 401 || status.as_u16() == 400 {
            return Err("Authentification Veyon refusée. La clé privée teacher doit rester uniquement sur le poste formateur.".into());
        }
        if !status.is_success() {
            return Err(format!("Authentification Veyon impossible ({status})."));
        }
        let payload: AuthResponse = response.json().await.map_err(|_| "Réponse d'authentification illisible.".to_string())?;
        if payload.connection_uid.trim().is_empty() {
            return Err("Veyon n'a pas fourni de connexion.".into());
        }
        let mut guard = self.connections.lock().unwrap_or_else(|error| error.into_inner());
        guard.insert(host.to_string(), CachedConnection {
            uid: payload.connection_uid.clone(),
            refreshed_at: Instant::now(),
        });
        Ok(payload.connection_uid)
    }

    fn cached_uid(&self, host: &str) -> Option<String> {
        let guard = self.connections.lock().unwrap_or_else(|error| error.into_inner());
        let cached = guard.get(host)?;
        if cached.refreshed_at.elapsed() > Duration::from_secs(45) {
            return None;
        }
        Some(cached.uid.clone())
    }

    fn invalidate(&self, host: &str) {
        let mut guard = self.connections.lock().unwrap_or_else(|error| error.into_inner());
        guard.remove(host);
    }

    fn private_key(&self) -> Result<String, String> {
        if let Some(cached) = self.key_cache.lock().unwrap_or_else(|error| error.into_inner()).clone() {
            return Ok(cached);
        }
        let path = private_key_path()?;
        let pem = std::fs::read_to_string(&path).map_err(|_| {
            format!("Clé privée introuvable ({}). Elle ne doit jamais être placée dans l'application.", path.display())
        })?;
        if pem.trim().is_empty() || pem.contains("BEGIN PUBLIC KEY") && !pem.contains("PRIVATE") {
            return Err("Le fichier de clé du formateur est vide ou public.".into());
        }
        let mut guard = self.key_cache.lock().unwrap_or_else(|error| error.into_inner());
        *guard = Some(pem.clone());
        Ok(pem)
    }
}

#[derive(Deserialize)]
struct AuthResponse {
    #[serde(rename = "connection-uid")]
    connection_uid: String,
}

pub fn webapi_base() -> Result<String, String> {
    let configured = std::env::var("BIMLEMAN_VEYON_WEBAPI").unwrap_or_else(|_| "http://127.0.0.1:11080".to_string());
    assert_loopback(&configured)?;
    Ok(configured.trim_end_matches('/').to_string())
}

pub fn assert_loopback(value: &str) -> Result<(), String> {
    let Ok(url) = reqwest::Url::parse(value) else {
        return Err("Adresse WebAPI invalide.".into());
    };
    if url.scheme() != "http" {
        return Err("Le WebAPI formateur doit rester en HTTP sur localhost.".into());
    }
    let host = url.host_str().unwrap_or("");
    if host != "127.0.0.1" && host != "localhost" {
        return Err("Le WebAPI doit écouter uniquement sur le poste formateur (localhost).".into());
    }
    Ok(())
}

pub fn redact(input: &str) -> String {
    let mut output = input.to_string();
    while let Some(start) = output.find("-----BEGIN") {
        if let Some(relative_end) = output[start..].find("-----END") {
            let after = start + relative_end;
            let end = output[after..].find('\n').map(|index| after + index + 1).unwrap_or(output.len());
            output.replace_range(start..end, "[clé masquée]");
        } else {
            output.replace_range(start.., "[clé masquée]");
            break;
        }
    }
    output
}

pub fn feature_call(action: &str, payload: Option<&str>) -> Result<FeatureCall, String> {
    let (uuid, active, arguments) = match action {
        "lock" => (SCREEN_LOCK, true, json!({})),
        "unlock" => (SCREEN_LOCK, false, json!({})),
        "reboot" => (REBOOT, true, json!({})),
        "shutdown" => (POWER_DOWN, true, json!({})),
        "message" => {
            let text = payload.unwrap_or("").trim();
            if text.is_empty() {
                return Err("Le message est vide.".into());
            }
            if text.chars().count() > 500 {
                return Err("Le message dépasse 500 caractères.".into());
            }
            (TEXT_MESSAGE, true, json!({ "text": text }))
        }
        "openWebsite" => {
            let url = validate_website(payload.unwrap_or(""))?;
            (OPEN_WEBSITE, true, json!({ "websiteUrls": [url] }))
        }
        _ => return Err("Action inconnue.".into()),
    };
    Ok(FeatureCall {
        uuid: uuid.to_string(),
        body: json!({ "active": active, "arguments": arguments }),
    })
}

pub fn validate_website(value: &str) -> Result<String, String> {
    let Ok(url) = reqwest::Url::parse(value.trim()) else {
        return Err("Adresse web invalide.".into());
    };
    if url.scheme() != "http" && url.scheme() != "https" {
        return Err("Seules les adresses http et https sont autorisées.".into());
    }
    if !url.username().is_empty() || url.password().is_some() {
        return Err("Les identifiants dans l'adresse sont refusés.".into());
    }
    Ok(url.to_string())
}

fn key_name() -> String {
    std::env::var("BIMLEMAN_VEYON_KEY_NAME").unwrap_or_else(|_| "teacher".to_string())
}

fn private_key_path() -> Result<PathBuf, String> {
    if let Ok(path) = std::env::var("BIMLEMAN_VEYON_PRIVATE_KEY_PATH") {
        return Ok(PathBuf::from(path));
    }
    let candidates = [
        PathBuf::from(r"C:\ProgramData\Veyon\keys\private\teacher\key"),
        PathBuf::from(r"C:\ProgramData\Veyon\keys\teacher\private\key"),
    ];
    candidates
        .into_iter()
        .find(|path| path.is_file())
        .ok_or_else(|| "Clé privée teacher introuvable sur ce poste. Elle ne doit pas être embarquée dans l'application.".to_string())
}

async fn ensure_success(response: reqwest::Response) -> Result<(), String> {
    let status = response.status();
    if status.as_u16() == 401 {
        return Err("session-expired".into());
    }
    if status.is_success() {
        return Ok(());
    }
    Err(format!("Veyon a refusé l'action ({status})."))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn webapi_stays_on_loopback() {
        assert!(assert_loopback("http://127.0.0.1:11080").is_ok());
        assert!(assert_loopback("http://localhost:11080").is_ok());
        assert!(assert_loopback("http://10.0.0.5:11080").is_err());
        assert!(assert_loopback("https://127.0.0.1:11080").is_err());
    }

    #[test]
    fn secrets_are_redacted() {
        let input = "avant -----BEGIN PRIVATE KEY-----\nSECRET\n-----END PRIVATE KEY-----\naprès";
        let redacted = redact(input);
        assert!(!redacted.contains("SECRET"));
        assert!(redacted.contains("[clé masquée]"));
    }

    #[test]
    fn features_map_to_official_uids() {
        let lock = feature_call("lock", None).expect("lock");
        assert_eq!(lock.uuid, SCREEN_LOCK);
        assert_eq!(lock.body["active"], true);
        let unlock = feature_call("unlock", None).expect("unlock");
        assert_eq!(unlock.body["active"], false);
        let message = feature_call("message", Some("Bonjour")).expect("message");
        assert_eq!(message.uuid, TEXT_MESSAGE);
        assert_eq!(message.body["arguments"]["text"], "Bonjour");
        let site = feature_call("openWebsite", Some("https://exemple.test/cours")).expect("url");
        assert_eq!(site.uuid, OPEN_WEBSITE);
        assert!(feature_call("openWebsite", Some("javascript:alert(1)")).is_err());
        assert!(feature_call("message", Some("")).is_err());
        assert_eq!(feature_call("shutdown", None).expect("shutdown").uuid, POWER_DOWN);
        assert_eq!(feature_call("reboot", None).expect("reboot").uuid, REBOOT);
    }
}
