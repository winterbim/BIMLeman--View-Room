param(
  [string]$InventoryPath = "$PSScriptRoot\..\..\inventory\pc-inventory.csv",
  [switch]$ClearExisting
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $InventoryPath)) { throw "Inventaire introuvable: $InventoryPath" }

$cli = "C:\Program Files\Veyon\veyon-wcli.exe"
if (-not (Test-Path -LiteralPath $cli)) { $cli = "C:\Program Files\Veyon\veyon-cli.exe" }
if (-not (Test-Path -LiteralPath $cli)) { throw "Veyon CLI introuvable." }

$rows = Import-Csv -LiteralPath $InventoryPath -Delimiter ";"
if ($ClearExisting) {
  & $cli networkobjects clear
  if ($LASTEXITCODE -ne 0) { throw "Nettoyage du répertoire Veyon échoué." }
}

foreach ($roomName in ($rows.Room | Sort-Object -Unique)) {
  & $cli networkobjects add location $roomName
  if ($LASTEXITCODE -ne 0) { throw "Ajout du lieu $roomName échoué." }
}

foreach ($row in $rows) {
  $targetHost = if ($row.HostAddress) { $row.HostAddress } else { $row.DesiredHostname }
  $macAddress = if ($row.MAC) { $row.MAC } else { "" }
  & $cli networkobjects add computer $row.DesiredHostname $targetHost $macAddress $row.Room
  if ($LASTEXITCODE -ne 0) { throw "Ajout de $($row.DesiredHostname) échoué." }
}

& $cli networkobjects list
if ($LASTEXITCODE -ne 0) { throw "Lecture du répertoire Veyon échouée." }
Write-Host "Répertoire Veyon mis à jour: $($rows.Count) postes." -ForegroundColor Green
