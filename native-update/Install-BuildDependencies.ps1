$ErrorActionPreference = 'Stop'
$packages = Get-Content "$PSScriptRoot/msys2-lock.json" -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force 'native-packages' | Out-Null
$packages | ForEach-Object -Parallel {
    $ErrorActionPreference = 'Stop'
    $dest = Join-Path (Join-Path $using:PWD 'native-packages') ([IO.Path]::GetFileName($_.url))
    if (-not (Test-Path $dest)) { Invoke-WebRequest $_.url -OutFile $dest -MaximumRetryCount 3 }
    if ((Get-FileHash $dest -Algorithm SHA256).Hash.ToLowerInvariant() -ne $_.sha256) {
        throw "Checksum mismatch: $($_.name)"
    }
} -ThrottleLimit 6
