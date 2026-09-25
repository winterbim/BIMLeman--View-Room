param(
  [Parameter(Mandatory = $true)][ValidateSet("Client", "Teacher")][string]$Role
)
$ErrorActionPreference = "Stop"

function Assert-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Exécuter PowerShell en administrateur."
  }
}

function Remove-BimlemanRule {
  param([string]$DisplayName)
  Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
}

Assert-Admin

if ($Role -eq "Client") {
  Remove-BimlemanRule "BIMLeman View Room Veyon 11100"
  New-NetFirewallRule -DisplayName "BIMLeman View Room Veyon 11100" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 11100 -Profile Domain, Private | Out-Null
}

Remove-BimlemanRule "BIMLeman View Room Block WebAPI 11080"
New-NetFirewallRule -DisplayName "BIMLeman View Room Block WebAPI 11080" -Direction Inbound -Action Block -Protocol TCP -LocalPort 11080 -Profile Any | Out-Null

Write-Host "Pare-feu $Role configuré. Le port 11080 n'est pas exposé au réseau." -ForegroundColor Green
if ($Role -eq "Client") {
  Write-Host "TCP 11100 autorisé en entrée sur les profils Domaine et Privé." -ForegroundColor Green
}
