# Read-only detection. Do not invoke Veyon CLI, a service or key-generation command here.
Set-StrictMode -Version Latest
function Get-VeyonInstallation {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Veyon/veyon-master.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Veyon/veyon-master.exe')
    )
    $appPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\veyon-master.exe'
    if (Test-Path $appPath) { $candidates += (Get-Item $appPath).GetValue('') }
    $found = @($candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -Unique)
    if ($found.Count -ne 1) { throw "Détection Veyon ambiguë ou absente ($($found.Count) installation(s)). Aucun changement effectué." }
    $exe = Get-Item -LiteralPath $found[0]
    $version = [version]$exe.VersionInfo.FileVersion
    $service = Get-Service -Name VeyonService -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Master = $exe.FullName
        Directory = $exe.DirectoryName
        Version = $version.ToString()
        SHA256 = (Get-FileHash -LiteralPath $exe.FullName -Algorithm SHA256).Hash
        ServiceStatus = if ($service) { $service.Status.ToString() } else { 'Absent' }
        ProgramData = (Join-Path $env:ProgramData 'Veyon')
        UserData = (Join-Path $env:APPDATA 'Veyon')
    }
}
if ($MyInvocation.InvocationName -ne '.') { Get-VeyonInstallation | ConvertTo-Json }
