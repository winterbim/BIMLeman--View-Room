param(
  [Parameter(Mandatory = $true)][string]$VeyonInstaller,
  [string]$ConfigPath = "",
  [string]$KeyName = "teacher",
  [string]$PublicKeyOutput = "C:\BIMLeman-View-Room-Deploy\teacher-public.key",
  [string]$InventoryPath = "",
  [switch]$CreateNetworkObjects
)
$ErrorActionPreference = "Stop"

function Assert-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Exécuter PowerShell en administrateur."
  }
}

Assert-Admin
if (-not (Test-Path -LiteralPath $VeyonInstaller)) { throw "Installateur Veyon introuvable: $VeyonInstaller" }

$installArgs = "/S"
if ($ConfigPath) {
  if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Configuration Veyon introuvable: $ConfigPath" }
  $absoluteConfig = (Resolve-Path -LiteralPath $ConfigPath).Path
  $installArgs = "/S /ApplyConfig=`"$absoluteConfig`""
}

$process = Start-Process -FilePath (Resolve-Path -LiteralPath $VeyonInstaller).Path -ArgumentList $installArgs -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Installation Veyon échouée: $($process.ExitCode)" }

$cli = "C:\Program Files\Veyon\veyon-wcli.exe"
if (-not (Test-Path -LiteralPath $cli)) { $cli = "C:\Program Files\Veyon\veyon-cli.exe" }
if (-not (Test-Path -LiteralPath $cli)) { throw "Veyon CLI introuvable après installation." }

$existing = (& $cli authkeys list 2>&1 | Out-String)
if ($existing -notmatch [regex]::Escape("$KeyName/private")) {
  & $cli authkeys create $KeyName
  if ($LASTEXITCODE -ne 0) { throw "Création de la paire de clés échouée." }
} else {
  Write-Host "Paire de clés $KeyName déjà présente : conservation de l'existant." -ForegroundColor Yellow
}

foreach ($groupName in @("Users", "Utilisateurs")) {
  & $cli authkeys setaccessgroup "$KeyName/private" $groupName
  if ($LASTEXITCODE -eq 0) { break }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $PublicKeyOutput) | Out-Null
& $cli authkeys export "$KeyName/public" $PublicKeyOutput
if ($LASTEXITCODE -ne 0) { throw "Export de la clé publique échoué." }

& $cli config set WebAPI/HttpServerEnabled true
& $cli config set WebAPI/HttpServerPort 11080
& $cli config set WebAPI/HttpsEnabled false
& $cli config set WebAPI/ConnectionLimit 48
if ($LASTEXITCODE -ne 0) { throw "Configuration du WebAPI local échouée." }

& "$PSScriptRoot\..\common\Set-VeyonFirewall.ps1" -Role Teacher

if ($CreateNetworkObjects) {
  if (-not $InventoryPath) { $InventoryPath = Join-Path $PSScriptRoot "..\..\inventory\pc-inventory.csv" }
  & "$PSScriptRoot\..\common\Create-NetworkObjects.ps1" -InventoryPath $InventoryPath -ClearExisting
}

& $cli service restart
if ($LASTEXITCODE -ne 0) { throw "Redémarrage du service Veyon échoué." }

Write-Host "Poste formateur prêt. Clé publique: $PublicKeyOutput" -ForegroundColor Green
Write-Host "Le WebAPI reste bloqué en entrée. L'application l'utilise uniquement via 127.0.0.1." -ForegroundColor Green
Write-Host "NE COPIEZ JAMAIS teacher/private sur les postes élèves." -ForegroundColor Yellow
