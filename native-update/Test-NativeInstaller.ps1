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
# Install a checksum-pinned OFFICIAL Veyon in this disposable runner as rollback baseline.
$officialSetup = Join-Path $env:RUNNER_TEMP 'official-veyon-4.11.3.0.exe'
Invoke-WebRequest 'https://github.com/veyon/veyon/releases/download/v4.11.3/veyon-4.11.3.0-win64-setup.exe' -OutFile $officialSetup -MaximumRetryCount 3
if ((Get-FileHash $officialSetup -Algorithm SHA256).Hash -ne '6acad4fc310e915a631477373f7649d51b74fbe8c41c5b0ab38d2fa852876b73') { throw 'Official reference installer checksum mismatch.' }
$reference = Start-Process $officialSetup -ArgumentList @('/S','/NoInterception') -Wait -PassThru
if ($reference.ExitCode -ne 0) { throw 'Official reference installation failed.' }
$originalDirectory = Join-Path $env:ProgramFiles 'Veyon'
$originalMaster = Join-Path $originalDirectory 'veyon-master.exe'
$originalHashes = @{}
Get-ChildItem $originalDirectory -Recurse -File | ForEach-Object { $originalHashes[$_.FullName] = (Get-FileHash $_.FullName -Algorithm SHA256).Hash }
if (-not $originalHashes.ContainsKey($originalMaster)) { throw 'Official Master missing.' }
$originalService = (Get-Service VeyonService).Status
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
# An overridden destination must be rejected before any file write.
$forbidden = Join-Path $env:RUNNER_TEMP 'native-forbidden-target'
$p = Start-Process $installer -ArgumentList @('/S', "/D=$forbidden") -PassThru -Wait
if ($p.ExitCode -eq 0 -or (Test-Path $forbidden)) { throw 'Installer accepted an unsafe custom destination.' }
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
if (Test-Path $installed) {
    Get-ChildItem $installed -Force -Recurse | Select-Object Name, Length | ConvertTo-Json | Set-Content (Join-Path $evidence 'rollback-remainders.json')
    throw 'Rollback left a candidate directory; see rollback-remainders.json.'
}
foreach ($file in $originalHashes.Keys) {
    if (-not (Test-Path $file) -or (Get-FileHash $file -Algorithm SHA256).Hash -ne $originalHashes[$file]) { throw "Official Veyon file changed: $file" }
}
if ((Get-Service VeyonService).Status -ne $originalService) { throw 'Parallel installation changed official Veyon service state.' }
# Confirm the original CLI still starts with its original native runtime after rollback.
& (Join-Path $originalDirectory 'veyon-cli.exe') help | Out-File (Join-Path $evidence 'official-cli-after-rollback.txt') -Encoding UTF8
if ($LASTEXITCODE -ne 0) { throw 'Official Veyon CLI no longer starts after rollback.' }
# Prove the official Master UI can be opened again on the same disposable desktop.
$reference = Start-Process $originalMaster -PassThru
$deadline = [DateTime]::UtcNow.AddSeconds(30)
do {
    Start-Sleep -Milliseconds 250
    $reference.Refresh()
} while (-not $reference.HasExited -and $reference.MainWindowTitle -ne 'Veyon Master' -and [DateTime]::UtcNow -lt $deadline)
if ($reference.HasExited -or $reference.MainWindowTitle -ne 'Veyon Master') {
    if (-not $reference.HasExited) { $reference.Kill() }
    throw 'Official Master did not reopen after rollback.'
}
[void]$reference.CloseMainWindow()
if (-not $reference.WaitForExit(15000)) { $reference.Kill(); throw 'Official Master did not close normally.' }
$manifest.windowsValidated = $true
$manifest | ConvertTo-Json -Depth 8 | Set-Content $manifestPath -Encoding UTF8
$safeWrapper = 'SKIPPED-NO-DISTRIBUTION-SCOPE'
if ($manifest.redistributionAuthorized) {
    # Production must remain blocked until a real classroom acceptance report exists.
    $refused = $false
    try { & "$out/Install-Safe.ps1" } catch {
        if ($_.Exception.Message -notlike '*Recette client non validée*') { throw }
        $refused = $true
    }
    if (-not $refused -or (Test-Path $installed)) { throw 'Production gate was bypassed.' }
    # Exercise the EXACT pilot wrapper provided to the teacher, including private backups.
    & "$out/Install-Safe.ps1" -Pilot
    if (-not (Test-Path $master)) { throw 'Pilot wrapper did not install native Master.' }
    $backupRoot = Join-Path $env:LOCALAPPDATA 'BIMLemanNativeBackups'
    $backups = @(Get-ChildItem $backupRoot -Directory)
    if ($backups.Count -ne 1) { throw 'Unexpected number of pilot backups.' }
    $backup = $backups[0].FullName
    if (-not (Get-Acl $backup).AreAccessRulesProtected) { throw 'Private backup inherits permissions.' }
    $permittedSids = @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value, 'S-1-5-18', 'S-1-5-32-544')
    foreach ($rule in (Get-Acl $backup).Access) {
        if ($rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -notin $permittedSids) { throw 'Unexpected backup access rule.' }
    }
    $backupMaster = Join-Path $backup 'original-installation/veyon-master.exe'
    if ((Get-FileHash $backupMaster -Algorithm SHA256).Hash -ne $originalHashes[$originalMaster]) { throw 'Official Master backup differs.' }
    foreach ($keyDir in @('PrivateKeyBaseDir','PublicKeyBaseDir')) {
        if (@(Get-ChildItem (Join-Path $backup $keyDir) -File -Recurse).Count -eq 0) { throw "External key directory not backed up: $keyDir" }
    }
    $backupIndex = @(Get-Content (Join-Path $backup 'checksums.json') -Raw -Encoding UTF8 | ConvertFrom-Json)
    foreach ($entry in $backupIndex) {
        if ((Get-FileHash (Join-Path $backup $entry.File) -Algorithm SHA256).Hash -ne $entry.SHA256) { throw 'Backup checksum mismatch.' }
    }
    & "$out/Uninstall-Safe.ps1" -BuildId $manifest.buildId
    foreach ($file in $originalHashes.Keys) {
        if ((Get-FileHash $file -Algorithm SHA256).Hash -ne $originalHashes[$file]) { throw 'Pilot wrapper changed original files.' }
    }
    if ((Get-Service VeyonService).Status -ne $originalService -or -not (Test-Path $sentinel)) { throw 'Pilot wrapper changed shared state.' }
    $safeWrapper = 'PASS'
}
Copy-Item $manifestPath (Join-Path $evidence 'manifest.json')
(Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $manifest.installer | Set-Content (Join-Path $evidence 'installer.sha256') -Encoding UTF8
@{ installation = 'PASS'; nativeStartup = 'PASS'; embeddedIcon = 'MATCHED'; title = 'PASS'; splash = 'PASS'; uninstall = 'PASS'; sharedDataPreserved = 'PASS'; serviceUnchanged = 'PASS'; officialMasterReopened = 'PASS'; originalFilesUnchanged = 'PASS'; safePilotWrapper = $safeWrapper; clientNetwork = 'PENDING-HARDWARE'; clientVersionDeclared = '4.11.3'; clientValidated = $false; signed = $false } | ConvertTo-Json | Set-Content (Join-Path $evidence 'windows-tests.json') -Encoding UTF8
