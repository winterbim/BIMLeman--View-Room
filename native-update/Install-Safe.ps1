param([switch]$Pilot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not [Environment]::Is64BitOperatingSystem -or -not [Environment]::Is64BitProcess) { throw 'PowerShell Windows x64 requis.' }
if ([Environment]::OSVersion.Version.Build -lt 17763) { throw 'Windows 10 1809 ou ultérieur requis par ce Qt.' }
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
if ($manifest.schema -ne 1 -or -not $manifest.native -or -not $manifest.windowsValidated) { throw 'Candidat natif non validé sous Windows : installation refusée.' }
if (-not $manifest.redistributionAuthorized) { throw 'Redistribution Interception non autorisée : installation refusée.' }
if (-not $manifest.clientValidated -and -not $Pilot) { throw 'Recette client non validée. Installation de production refusée. Le mode -Pilot est réservé à la recette parallèle documentée.' }
if ($manifest.buildId -notmatch '^4\.11\.3-[0-9a-f]{8}$' -or $manifest.installer -ne "BIMLeman-$($manifest.buildId)-setup.exe") { throw 'Identité du paquet invalide.' }
foreach ($entry in $manifest.files.psobject.Properties) {
    if ([IO.Path]::GetFileName($entry.Name) -ne $entry.Name -or $entry.Name.Contains('..')) { throw 'Chemin de paquet invalide.' }
    $file = Join-Path $PSScriptRoot $entry.Name
    if (-not (Test-Path -LiteralPath $file) -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.Value) { throw "Intégrité du paquet invalide : $($entry.Name)" }
}
. (Join-Path $PSScriptRoot 'Get-VeyonInstallation.ps1')
$existing = Get-VeyonInstallation
$v = [version]$existing.Version
if ($v.Major -ne 4 -or $v.Minor -ne 11 -or $v.Build -ne 3) { throw "Version client $v différente de 4.11.3 : aucune compatibilité certifiée, installation refusée." }
if (Get-Process -Name veyon-master,veyon-configurator -ErrorAction SilentlyContinue) { throw 'Fermez Master et Configurator avant la sauvegarde.' }
$destination = Join-Path $env:LOCALAPPDATA "Programs/BIMLemanNative/$($manifest.buildId)"
if (Test-Path -LiteralPath $destination) { throw 'Ce candidat est déjà présent. Aucun écrasement autorisé.' }
$backup = Join-Path $env:LOCALAPPDATA ('BIMLemanNativeBackups/' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $backup -Force | Out-Null
# Private data backup readable only by this user, SYSTEM and local Administrators.
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
foreach ($identity in @($sid.Value, 'S-1-5-18', 'S-1-5-32-544')) {
    $rule = New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($identity)), 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
}
Set-Acl -LiteralPath $backup -AclObject $acl
$existing | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backup 'before.json') -Encoding UTF8
function Backup-Tree([string]$Source, [string]$Name) {
    if (-not (Test-Path -LiteralPath $Source)) { return }
    $links = @(Get-ChildItem -LiteralPath $Source -Recurse -Force -Attributes ReparsePoint -ErrorAction Stop)
    if ($links.Count) { throw "Lien de système de fichiers dans $Source : sauvegarde manuelle requise." }
    & robocopy $Source (Join-Path $backup $Name) /E /COPY:DAT /DCOPY:DAT /XJ /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Sauvegarde incomplète de $Source. Installation refusée." }
}
Backup-Tree $existing.Directory 'original-installation'
Backup-Tree $existing.ProgramData 'program-data'
Backup-Tree $existing.UserData 'user-data'
foreach ($hive in @('HKLM','HKCU')) {
    $key = "${hive}\SOFTWARE\Veyon Solutions"
    if (Test-Path "${hive}:\SOFTWARE\Veyon Solutions") {
        & reg.exe export $key (Join-Path $backup "$hive.reg") /y | Out-Null
        if ($LASTEXITCODE) { throw "Sauvegarde du registre $hive impossible." }
    }
}
# Keys/certificates in configured external directories stay in place. Save them too.
$auth = 'HKLM:\SOFTWARE\Veyon Solutions\Veyon\Authentication'
if (Test-Path $auth) {
    foreach ($name in @('PrivateKeyBaseDir','PublicKeyBaseDir')) {
        $value = (Get-Item $auth).GetValue($name, '')
        if ($value) {
            $path = [Environment]::ExpandEnvironmentVariables($value.Replace('%GLOBALAPPDATA%', $existing.ProgramData).Replace('%APPDATA%', $existing.UserData))
            if (-not [IO.Path]::IsPathRooted($path) -or $path.Contains('%')) { throw "Chemin de clé non résolu : $name" }
            Backup-Tree $path $name
        }
    }
}
$checksums = @(Get-ChildItem -LiteralPath $backup -File -Recurse | ForEach-Object {
    [pscustomobject]@{ File = $_.FullName.Substring($backup.Length+1); SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
})
$checksums | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $backup 'checksums.json') -Encoding UTF8
$installer = Join-Path $PSScriptRoot $manifest.installer
$result = Start-Process -FilePath $installer -ArgumentList @('/S') -Wait -PassThru
if ($result.ExitCode -ne 0 -or -not (Test-Path (Join-Path $destination 'veyon-master.exe'))) { throw "Installation échouée ($($result.ExitCode)). Veyon original reste à $($existing.Directory). Sauvegarde : $backup" }
$after = Get-VeyonInstallation
if ($after.SHA256 -ne $existing.SHA256 -or $after.ServiceStatus -ne $existing.ServiceStatus) { throw "État Veyon inattendu. Ne lancez pas le candidat. Sauvegarde : $backup" }
Write-Host "Application native installée en parallèle : $destination"
Write-Host "Sauvegarde privée : $backup"
Write-Host "Aucun service ni poste élève modifié. Lancez le raccourci pour la recette."
