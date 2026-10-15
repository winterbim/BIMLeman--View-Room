param([switch]$Pilot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not [Environment]::Is64BitOperatingSystem -or -not [Environment]::Is64BitProcess) { throw 'PowerShell Windows x64 requis.' }
$repo = 'winterbim/BIMLeman--View-Room'
$tag = 'native-v4.11.3-fe9f2d92-pilot'
$commit = 'fe9f2d92e182d9d885f107834fe37f1863914b65'
$base = "https://github.com/$repo/releases/download/$tag"
# Short work root: TEMP on the client host can exceed MAX_PATH.
$root = Join-Path $env:LOCALAPPDATA 'bn'
$dir = Join-Path $root 'r'
if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$names = @(
    'manifest.json',
    'Get-VeyonInstallation.ps1',
    'Install-Safe.ps1',
    'Uninstall-Safe.ps1',
    'BIMLeman-4.11.3-fe9f2d92-setup.exe'
)
foreach ($name in $names) {
    if ([IO.Path]::GetFileName($name) -ne $name -or $name.Contains('..')) { throw 'Chemin de paquet invalide.' }
    Invoke-WebRequest -UseBasicParsing -Uri ("$base/" + $name) -OutFile (Join-Path $dir $name)
}
$manifestPath = Join-Path $dir 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.schema -ne 1 -or -not $manifest.native -or -not $manifest.windowsValidated) { throw 'Candidat natif non validé sous Windows : installation refusée.' }
if (-not $manifest.redistributionAuthorized) { throw 'Redistribution Interception non autorisée : installation refusée.' }
if ($manifest.redistributionScope -ne 'non-commercial') { throw 'Ce candidat est réservé à un usage strictement non commercial.' }
if (-not $manifest.clientValidated -and -not $Pilot) { throw 'Recette client non validée. Installation de production refusée. Le mode -Pilot est réservé à la recette parallèle documentée.' }
if ($manifest.commit -ne $commit) { throw "Commit livré $($manifest.commit) différent de $commit : installation refusée." }
foreach ($entry in $manifest.files.psobject.Properties) {
    if ([IO.Path]::GetFileName($entry.Name) -ne $entry.Name -or $entry.Name.Contains('..')) { throw 'Chemin invalide dans le manifeste.' }
    $path = Join-Path $dir $entry.Name
    if (-not (Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.Value) { throw "Somme SHA256 incorrecte : $($entry.Name)" }
}
Write-Host "Candidat natif vérifié : $($manifest.buildId) ; commit $($manifest.commit) ; préversion $tag"
& (Join-Path $dir 'Install-Safe.ps1') -Pilot:$Pilot
if ($LASTEXITCODE) { exit $LASTEXITCODE }
