# Destructive only inside a fresh GitHub runner. Never run this on a client PC.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') { throw 'Tests réservés à un runner GitHub hébergé jetable.' }
foreach ($hive in @('HKCU','HKLM')) {
    if (Test-Path "${hive}:\SOFTWARE\Veyon Solutions") { throw 'Configuration Veyon préexistante : test isolé refusé.' }
}
foreach ($script in Get-ChildItem "$PSScriptRoot/*.ps1") {
    $tokens = $null; $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
}
$out = Join-Path $PWD 'native-output'
$manifestPath = Join-Path $out 'manifest.json'
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$installed = Join-Path $env:LOCALAPPDATA "Programs/BIMLemanNative/$($manifest.buildId)"
$installer = Join-Path $out $manifest.installer
$evidence = Join-Path $out 'evidence'
# Exclude all build tools from PATH to expose missing DLLs/plugins.
$env:PATH = "$env:SystemRoot\System32;$env:SystemRoot"
$env:QT_PLUGIN_PATH = $null
$env:QML2_IMPORT_PATH = $null
$p = Start-Process $installer -ArgumentList @('/S') -PassThru -Wait
if ($p.ExitCode -ne 0) { throw "NSIS install failed: $($p.ExitCode)" }
$master = Join-Path $installed 'veyon-master.exe'
$cli = Join-Path $installed 'veyon-cli.exe'
if (-not (Test-Path $master)) { throw 'Native Master absent after installation.' }
function Run-Cli([string[]]$Arguments) {
    & $cli @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Native CLI failure: $Arguments ($LASTEXITCODE)" }
}
# Real upstream authentication, with an ephemeral keypair; no authentication bypass.
Run-Cli @('config','set','Authentication/Method','1')
Run-Cli @('config','set','Authentication/PrivateKeyBaseDir', (Join-Path $env:RUNNER_TEMP 'native-test-keys/private'))
Run-Cli @('config','set','Authentication/PublicKeyBaseDir', (Join-Path $env:RUNNER_TEMP 'native-test-keys/public'))
Run-Cli @('authkeys','create','nativeci')
$env:BIMLEMAN_EVIDENCE_DIR = $evidence
$env:QT_DEBUG_PLUGINS = '1'
$p = Start-Process $master -ArgumentList @('--bimleman-self-test') -PassThru -RedirectStandardError (Join-Path $evidence 'native-stderr.log') -RedirectStandardOutput (Join-Path $evidence 'native-stdout.log')
if (-not $p.WaitForExit(60000)) { $p.Kill(); throw 'Native GUI startup timed out.' }
$p.Refresh()
if ($p.ExitCode -ne 0) { throw "Native GUI failed: $($p.ExitCode); see native-stderr.log" }
$smoke = Get-Content (Join-Path $evidence 'native-smoke.json') -Raw | ConvertFrom-Json
$branding = Get-Content (Join-Path $evidence 'branding.json') -Raw | ConvertFrom-Json
if ($smoke.title -ne 'BIMLéman View Room' -or -not $smoke.iconLoaded -or -not $smoke.splashLoaded) { throw 'Incorrect native branding at runtime.' }
if ($smoke.'splash.png' -ne $branding.modified.'master/resources/splash.png' -or $smoke.'bimleman-icon.png' -ne $branding.modified.'master/resources/bimleman-icon.png') { throw 'Compiled resources differ from official branding.' }
foreach ($feature in @('RemoteView','RemoteControl','ScreenLock','TextMessage')) {
    if ($smoke.features -notcontains $feature) { throw "Native feature plugin not loaded: $feature" }
}
if ($smoke.version -notmatch '^4\.11\.3') { throw 'Wrong upstream version.' }
Add-Type -AssemblyName System.Drawing
$icon = [Drawing.Icon]::ExtractAssociatedIcon($master)
if (-not $icon) { throw 'No embedded Windows icon.' }
$bitmap = $icon.ToBitmap()
$bitmap.Save((Join-Path $evidence 'windows-extracted-icon.png'))
$expectedIcon = [Drawing.Icon]::new((Join-Path $installed 'brand.ico'), $icon.Size)
$expectedBitmap = $expectedIcon.ToBitmap()
for ($x = 0; $x -lt $bitmap.Width; $x++) {
    for ($y = 0; $y -lt $bitmap.Height; $y++) {
        if ($bitmap.GetPixel($x,$y).ToArgb() -ne $expectedBitmap.GetPixel($x,$y).ToArgb()) { throw 'Embedded PE icon differs from BIMLeman icon.' }
    }
}
$expectedBitmap.Dispose(); $expectedIcon.Dispose()
$bitmap.Dispose(); $icon.Dispose()
# Capture complete installed payload hashes before rollback.
$payload = @(Get-ChildItem $installed -File -Recurse | ForEach-Object {
    [pscustomobject]@{ Path = $_.FullName.Substring($installed.Length+1); SHA256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash }
})
$payload | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $evidence 'installed-files.json') -Encoding UTF8
# A second installation must refuse overwriting an existing candidate.
$p = Start-Process $installer -ArgumentList @('/S') -PassThru -Wait
if ($p.ExitCode -eq 0) { throw 'Existing candidate overwrite was incorrectly allowed.' }
# User data is outside the uninstall scope and must survive.
$sentinelDir = Join-Path $env:APPDATA 'Veyon'
New-Item -ItemType Directory -Force $sentinelDir | Out-Null
$sentinel = Join-Path $sentinelDir 'native-ci-preserve.txt'
Set-Content $sentinel 'must survive'
& "$out/Uninstall-Safe.ps1" -BuildId $manifest.buildId
if (-not (Test-Path $sentinel) -or (Get-Content $sentinel) -ne 'must survive') { throw 'Rollback deleted shared Veyon data.' }
if (Test-Path $master) { throw 'Rollback left native Master installed.' }
if (Get-Service VeyonService -ErrorAction SilentlyContinue) { throw 'Parallel installer unexpectedly created a service.' }
$manifest.windowsValidated = $true
$manifest | ConvertTo-Json -Depth 8 | Set-Content $manifestPath -Encoding UTF8
@{ installation = 'PASS'; nativeStartup = 'PASS'; embeddedIcon = 'MATCHED'; title = 'PASS'; splash = 'PASS'; uninstall = 'PASS'; sharedDataPreserved = 'PASS'; serviceUnchanged = 'PASS'; clientNetwork = 'PENDING-HARDWARE'; clientVersion = 'UNKNOWN'; signed = $false } | ConvertTo-Json | Set-Content (Join-Path $evidence 'windows-tests.json') -Encoding UTF8
