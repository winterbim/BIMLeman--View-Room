param(
  [Parameter(Mandatory = $true)][ValidateSet("A", "B", "C")][string]$Room,
  [Parameter(Mandatory = $true)][ValidateRange(1, 8)][int]$Seat,
  [Parameter(Mandatory = $true)][string]$VeyonInstaller,
  [Parameter(Mandatory = $true)][string]$ConfigPath,
  [Parameter(Mandatory = $true)][string]$PublicKeyPath,
  [string]$KeyName = "teacher",
  [switch]$RenameComputer
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
foreach ($file in @($VeyonInstaller, $ConfigPath, $PublicKeyPath)) {
  if (-not (Test-Path -LiteralPath $file)) { throw "Fichier introuvable: $file" }
}

$targetName = "SALLE-$Room-PC$($Seat.ToString("00"))"
$config = (Resolve-Path -LiteralPath $ConfigPath).Path
$installer = (Resolve-Path -LiteralPath $VeyonInstaller).Path
$publicKey = (Resolve-Path -LiteralPath $PublicKeyPath).Path
$installArgs = "/S /NoMaster /ApplyConfig=`"$config`""

$process = Start-Process -FilePath $installer -ArgumentList $installArgs -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Installation Veyon échouée: $($process.ExitCode)" }

$cli = "C:\Program Files\Veyon\veyon-wcli.exe"
if (-not (Test-Path -LiteralPath $cli)) { $cli = "C:\Program Files\Veyon\veyon-cli.exe" }
if (-not (Test-Path -LiteralPath $cli)) { throw "Veyon CLI introuvable après installation." }

& $cli authkeys import "$KeyName/public" $publicKey
if ($LASTEXITCODE -ne 0) { throw "Import de la clé publique échoué." }

& $cli config set WebAPI/HttpServerEnabled false
& $cli config set WebAPI/HttpsEnabled false
if ($LASTEXITCODE -ne 0) { throw "Désactivation du WebAPI client échouée." }

$listed = (& $cli authkeys list 2>&1 | Out-String)
if ($listed -match [regex]::Escape("$KeyName/private")) {
  throw "Clé privée détectée sur un poste élève. Installation interrompue."
}

& "$PSScriptRoot\..\common\Set-VeyonFirewall.ps1" -Role Client
& $cli service restart
if ($LASTEXITCODE -ne 0) { throw "Redémarrage du service Veyon échoué." }

if ($RenameComputer -and $env:COMPUTERNAME -ne $targetName) {
  Rename-Computer -NewName $targetName -Force
  Write-Host "Renommage programmé en $targetName. Redémarrage requis." -ForegroundColor Yellow
}

Write-Host "Client configuré: $targetName / clé publique uniquement." -ForegroundColor Green
