param([Parameter(Mandatory=$true)][ValidatePattern('^4\.11\.3-[0-9a-f]{8}$')][string]$BuildId)
$ErrorActionPreference = 'Stop'
$target = Join-Path $env:LOCALAPPDATA "Programs/BIMLemanNative/$BuildId"
$exe = Join-Path $target 'Uninstall.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'Candidat absent.' }
$running = @(Get-Process -Name veyon-master,veyon-server,veyon-worker,veyon-cli,veyon-wcli,veyon-configurator -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($target + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) })
if ($running.Count) { throw 'Fermez le candidat avant sa désinstallation.' }
$result = Start-Process -FilePath $exe -ArgumentList @('/S', "_?=$target") -Wait -PassThru
if ($result.ExitCode -ne 0 -or (Test-Path (Join-Path $target 'veyon-master.exe'))) { throw 'Désinstallation incomplète.' }
# _?= makes NSIS wait in place, so Windows keeps its executable locked until exit.
# Delete only that known executable now; preserve any unexpected user-added file.
if (Test-Path -LiteralPath $exe) { Remove-Item -LiteralPath $exe -Force }
if ((Test-Path -LiteralPath $target) -and @(Get-ChildItem -LiteralPath $target -Force).Count -eq 0) {
    Remove-Item -LiteralPath $target
}
Write-Host 'Candidat retiré. Utilisez le raccourci Veyon original. Les sauvegardes et paramètres partagés sont conservés.'
