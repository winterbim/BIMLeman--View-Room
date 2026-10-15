param([switch]$Pilot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = 'winterbim/BIMLeman--View-Room'
$workflow = 'build-native-veyon.yml'
$branch = 'feature/veyon-native-bimleman'
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI requis : winget install --id GitHub.cli -e ; puis gh auth login' }
& gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Authentification GitHub nécessaire : gh auth login' }
$runsJson = & gh run list -R $repo -w $workflow -b $branch --limit 20 --json databaseId,conclusion,status,headSha,createdAt
if ($LASTEXITCODE) { throw 'Lecture des builds GitHub impossible.' }
$runs = @($runsJson | ConvertFrom-Json | Where-Object { $_.status -eq 'completed' -and $_.conclusion -eq 'success' } | Sort-Object createdAt -Descending)
foreach ($run in $runs) {
    $dir = Join-Path $env:TEMP ('BIMLemanNative-' + $run.databaseId + '-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    & gh run download $run.databaseId -R $repo -n BIMLeman-Native-Veyon-Candidate -D $dir 2>$null
    if ($LASTEXITCODE -ne 0) { continue }
    $manifestPath = Join-Path $dir 'manifest.json'
    if (-not (Test-Path $manifestPath)) { continue }
    $manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.commit -ne $run.headSha -or -not $manifest.native -or -not $manifest.windowsValidated -or -not $manifest.redistributionAuthorized) { continue }
    if (-not $manifest.clientValidated -and -not $Pilot) { continue }
    foreach ($entry in $manifest.files.psobject.Properties) {
        if ([IO.Path]::GetFileName($entry.Name) -ne $entry.Name -or $entry.Name.Contains('..')) { throw 'Chemin invalide dans le manifeste.' }
        $path = Join-Path $dir $entry.Name
        if (-not (Test-Path $path) -or (Get-FileHash $path -Algorithm SHA256).Hash -ne $entry.Value) { throw "Somme SHA256 incorrecte : $($entry.Name)" }
    }
    Write-Host "Candidat natif vérifié : $($run.headSha) ; run $($run.databaseId)"
    & (Join-Path $dir 'Install-Safe.ps1') -Pilot:$Pilot
    return
}
throw 'Aucune livraison native autorisée et validée disponible. Installation refusée ; consultez le rapport et les preuves GitHub.'
