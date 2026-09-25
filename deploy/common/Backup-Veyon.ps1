param([string]$Output = "C:\BIMLeman-View-Room-Backup")
$ErrorActionPreference = "Stop"
$cli = "C:\Program Files\Veyon\veyon-wcli.exe"
if (-not (Test-Path -LiteralPath $cli)) { $cli = "C:\Program Files\Veyon\veyon-cli.exe" }
if (-not (Test-Path -LiteralPath $cli)) { throw "Veyon CLI introuvable." }

New-Item -ItemType Directory -Force -Path $Output | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$configFile = Join-Path $Output "veyon-config-$stamp.json"
$networkFile = Join-Path $Output "veyon-networkobjects-$stamp.csv"
& $cli config export $configFile
if ($LASTEXITCODE -ne 0) { throw "Export de configuration échoué." }
& $cli networkobjects export $networkFile "%type%;%name%;%host%;%mac%;%location%"
if ($LASTEXITCODE -ne 0) { throw "Export du répertoire échoué." }

$exported = Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue
if ($exported -match "BEGIN PRIVATE KEY") {
  Remove-Item -LiteralPath $configFile -Force
  throw "L'export contient une clé privée et a été supprimé."
}

Write-Host "Sauvegarde Veyon: $Output" -ForegroundColor Green
Write-Host "Cette sauvegarde ne remplace pas la conservation séparée de teacher/private." -ForegroundColor Yellow
