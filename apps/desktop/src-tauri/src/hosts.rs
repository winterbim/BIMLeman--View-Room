use std::net::IpAddr;
use std::path::PathBuf;

pub fn builtin_hosts() -> Vec<String> {
    let mut hosts = Vec::with_capacity(24);
    for room in ["A", "B", "C"] {
        for seat in 1..=8 {
            hosts.push(format!("SALLE-{room}-PC{seat:02}"));
        }
    }
    hosts
}

pub fn is_managed_hostname(host: &str) -> bool {
    let bytes = host.as_bytes();
    if bytes.len() != 12 || !host.starts_with("SALLE-") || !host[7..].starts_with("-PC") {
        return false;
    }
    let room = bytes[6];
    if room != b'A' && room != b'B' && room != b'C' {
        return false;
    }
    let seat = &host[10..];
    matches!(seat, "01" | "02" | "03" | "04" | "05" | "06" | "07" | "08")
}

pub fn is_private_ipv4(value: &str) -> bool {
    let Ok(IpAddr::V4(ip)) = value.parse::<IpAddr>() else {
        return false;
    };
    let octets = ip.octets();
    match octets[0] {
        10 => true,
        172 => (16..=31).contains(&octets[1]),
        192 => octets[1] == 168,
        _ => false,
    }
}

pub fn is_allowed_host(host: &str) -> bool {
    let host = host.trim();
    if host.is_empty() || host.contains(['/', '\\', '?', '@', ' ', '\n']) {
        return false;
    }
    if builtin_hosts().iter().any(|item| item.eq_ignore_ascii_case(host)) {
        return true;
    }
    extra_hosts().iter().any(|item| item.eq_ignore_ascii_case(host))
}

pub fn require_allowed_host(host: &str) -> Result<(), String> {
    if is_allowed_host(host) {
        Ok(())
    } else {
        Err(format!("Hôte refusé, hors du parc BIMLéman : {host}"))
    }
}

fn extra_hosts() -> Vec<String> {
    let path = std::env::var("BIMLEMAN_INVENTORY")
        .ok()
        .map(PathBuf::from)
        .filter(|candidate| candidate.is_file());
    let Some(path) = path else {
        return Vec::new();
    };
    match std::fs::read_to_string(path) {
        Ok(text) => parse_inventory_hosts(&text),
        Err(_) => Vec::new(),
    }
}

pub fn parse_inventory_hosts(csv: &str) -> Vec<String> {
    let mut lines = csv.lines().filter(|line| !line.trim().is_empty());
    let Some(header) = lines.next() else {
        return Vec::new();
    };
    let columns: Vec<&str> = header.split(';').map(str::trim).collect();
    let Some(address_index) = columns.iter().position(|column| *column == "HostAddress") else {
        return Vec::new();
    };
    let Some(hostname_index) = columns.iter().position(|column| *column == "DesiredHostname") else {
        return Vec::new();
    };
    lines
        .filter_map(|line| {
            let cells: Vec<&str> = line.split(';').map(str::trim).collect();
            let address = cells.get(address_index).copied().unwrap_or("");
            let hostname = cells.get(hostname_index).copied().unwrap_or("");
            let candidate = if address.is_empty() { hostname } else { address };
            if is_managed_hostname(candidate) || is_private_ipv4(candidate) {
                Some(candidate.to_string())
            } else {
                None
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn builtin_park_has_24_hosts() {
        let hosts = builtin_hosts();
        assert_eq!(hosts.len(), 24);
        assert!(is_managed_hostname("SALLE-A-PC01"));
        assert!(is_managed_hostname("SALLE-C-PC08"));
        assert!(!is_managed_hostname("SALLE-A-PC09"));
        assert!(!is_managed_hostname("evil.example"));
        assert!(is_allowed_host("SALLE-B-PC04"));
    }

    #[test]
    fn inventory_accepts_only_park_and_private_addresses() {
        let csv = "\
RoomCode;DesiredHostname;HostAddress
A;SALLE-A-PC01;10.0.8.11
B;SALLE-B-PC01;8.8.8.8
C;SALLE-C-PC01;192.168.1.20
";
        let hosts = parse_inventory_hosts(csv);
        assert!(hosts.contains(&"10.0.8.11".to_string()));
        assert!(hosts.contains(&"192.168.1.20".to_string()));
        assert!(!hosts.iter().any(|host| host == "8.8.8.8"));
    }

    #[test]
    fn private_ranges_are_limited() {
        assert!(is_private_ipv4("10.1.2.3"));
        assert!(is_private_ipv4("172.16.0.4"));
        assert!(!is_private_ipv4("172.32.0.4"));
        assert!(is_private_ipv4("192.168.0.9"));
        assert!(!is_private_ipv4("127.0.0.1"));
        assert!(!is_private_ipv4("1.2.3.4"));
    }
}
