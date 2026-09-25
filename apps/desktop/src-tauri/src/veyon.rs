use crate::hosts::require_allowed_host;
use std::net::{TcpStream, ToSocketAddrs};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::Mutex;
use std::time::Duration;

static WEBAPI_START: Mutex<()> = Mutex::new(());

pub fn veyon_cli_path() -> Option<PathBuf> {
    if !cfg!(target_os = "windows") {
        return None;
    }
    let candidates = [
        PathBuf::from(r"C:\Program Files\Veyon\veyon-wcli.exe"),
        PathBuf::from(r"C:\Program Files\Veyon\veyon-cli.exe"),
    ];
    candidates.into_iter().find(|path| path.is_file())
}

pub fn check_port(host: &str) -> Result<bool, String> {
    require_allowed_host(host)?;
    let address = resolve_with_timeout(host, 11100, Duration::from_millis(1500))?;
    Ok(TcpStream::connect_timeout(&address, Duration::from_millis(1500)).is_ok())
}

pub fn open_remote(mode: &str, host: &str) -> Result<(), String> {
    if mode != "view" && mode != "control" {
        return Err("Mode de vue distant inconnu.".into());
    }
    require_allowed_host(host)?;
    let cli = veyon_cli_path().ok_or_else(|| "Veyon CLI introuvable. Installez Veyon sur le poste formateur.".to_string())?;
    Command::new(cli)
        .args(["remoteaccess", mode, host])
        .stdin(Stdio::null())
        .spawn()
        .map(|_| ())
        .map_err(|error| format!("Impossible d'ouvrir Veyon : {error}"))
}

pub async fn ensure_local_webapi() -> Result<(), String> {
    if !cfg!(target_os = "windows") {
        return Err("Le proxy Veyon est disponible sur le poste formateur Windows.".into());
    }
    if port_open("127.0.0.1", 11080) {
        return Ok(());
    }
    {
        let _guard = WEBAPI_START.lock().unwrap_or_else(|error| error.into_inner());
        if !port_open("127.0.0.1", 11080) {
            let cli = veyon_cli_path().ok_or_else(|| "Veyon CLI introuvable.".to_string())?;
            Command::new(cli)
                .args(["webapi", "runserver"])
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()
                .map_err(|error| format!("Démarrage du WebAPI local impossible : {error}"))?;
        }
    }
    for _ in 0..10 {
        if port_open("127.0.0.1", 11080) {
            return Ok(());
        }
        tokio::time::sleep(Duration::from_millis(300)).await;
    }
    Err("Le WebAPI Veyon n'écoute pas sur 127.0.0.1:11080.".into())
}

fn port_open(host: &str, port: u16) -> bool {
    let Ok(mut addresses) = format!("{host}:{port}").to_socket_addrs() else {
        return false;
    };
    let Some(address) = addresses.next() else {
        return false;
    };
    TcpStream::connect_timeout(&address, Duration::from_millis(200)).is_ok()
}

fn resolve_with_timeout(host: &str, port: u16, timeout: Duration) -> Result<std::net::SocketAddr, String> {
    let (sender, receiver) = std::sync::mpsc::channel();
    let target = host.to_string();
    std::thread::spawn(move || {
        let resolved = format!("{target}:{port}").to_socket_addrs();
        let _ = sender.send(resolved);
    });
    match receiver.recv_timeout(timeout) {
        Ok(Ok(mut addresses)) => addresses.next().ok_or_else(|| format!("Aucune adresse pour {host}.")),
        Ok(Err(error)) => Err(format!("Résolution impossible : {error}")),
        Err(_) => Err(format!("Délai DNS dépassé pour {host}.")),
    }
}
