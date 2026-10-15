# BIMLéman View Room — installation depuis GitHub Actions
# N'altère pas le service ni la configuration Veyon.
$ErrorActionPreference = 'Stop'
$repo = 'winterbim/BIMLeman--View-Room'
$workflow = 'branding-update.yml'
$branch = 'feature/veyon-native-bimleman'
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw 'GitHub CLI absent. Installez-le : winget install --id GitHub.cli -e'
}
& gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Connectez GitHub CLI avec : gh auth login' }
$runs = & gh run list -R $repo -w $workflow -b $branch --limit 15 --json databaseId,conclusion,status,headSha,createdAt | ConvertFrom-Json
$run = $runs | Where-Object { $_.status -eq 'completed' -and $_.conclusion -eq 'success' } | Sort-Object createdAt -Descending | Select-Object -First 1
if (-not $run) { throw 'Aucun build Windows réussi disponible. Consultez les Actions GitHub avant toute installation.' }
$dir = Join-Path $env:TEMP ('BIMLeman-Update-' + $run.databaseId)
New-Item -ItemType Directory -Force -Path $dir | Out-Null
& gh run download $run.databaseId -R $repo -n BIMLeman-View-Room-Update -D $dir
if ($LASTEXITCODE -ne 0) { throw 'Téléchargement du build échoué.' }
$installer = Join-Path $dir 'BIMLeman-View-Room-Update.exe'
if (-not (Test-Path $installer)) { throw "Installateur introuvable : $installer" }
Write-Host "Build GitHub : $($run.headSha)" -ForegroundColor Cyan
Write-Host "SHA256 : $((Get-FileHash $installer -Algorithm SHA256).Hash)" -ForegroundColor Cyan
Write-Host 'Ce paquet est un lanceur personnalisé, pas encore un fork intégral de Veyon Master.' -ForegroundColor Yellow
$answer = Read-Host 'Lancer cette mise à jour ? (O/N)'
if ($answer -notin @('O','o','oui','OUI')) { Write-Host 'Annulé.'; exit 0 }
Start-Process -FilePath $installer -Wait
