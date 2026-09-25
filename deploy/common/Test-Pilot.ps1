param(
  [Parameter(Mandatory = $true)][ValidateSet("Teacher", "Client")][string]$Role,
  [string]$PilotHost = "SALLE-A-PC01",
  [string]$KeyName = "teacher",
  [string]$ReportPath = "$PSScriptRoot\pilot-report.csv"
)
$ErrorActionPreference = "Stop"
$checks = @()

function Add-Check {
  param([string]$Name, [bool]$Passed, [string]$Detail)
  $script:checks += [PSCustomObject]@{
    Role = $Role
    Check = $Name
    Result = $(if ($Passed) { "PASS" } else { "FAIL" })
    Detail = $Detail
    CheckedAt = (Get-Date).ToString("s")
  }
}

$cli = "C:\Program Files\Veyon\veyon-wcli.exe"
if (-not (Test-Path -LiteralPath $cli)) { $cli = "C:\Program Files\Veyon\veyon-cli.exe" }
$cliFound = Test-Path -LiteralPath $cli
Add-Check -Name "Veyon CLI" -Passed $cliFound -Detail $cli

if ($cliFound) {
  $listed = (& $cli authkeys list 2>&1 | Out-String)
  $hasPrivate = $listed -match [regex]::Escape("$KeyName/private")
  $hasPublic = $listed -match [regex]::Escape("$KeyName/public")
  if ($Role -eq "Teacher") {
    Add-Check -Name "Clé privée teacher présente" -Passed $hasPrivate -Detail "teacher/private attendue uniquement ici"
    Add-Check -Name "Clé publique teacher présente" -Passed $hasPublic -Detail "teacher/public"
  } else {
    Add-Check -Name "Aucune clé privée sur le client" -Passed (-not $hasPrivate) -Detail "teacher/private interdit"
    Add-Check -Name "Clé publique teacher présente" -Passed $hasPublic -Detail "teacher/public"
  }
}

$tcp = New-Object System.Net.Sockets.TcpClient
$pilotOk = $false
try {
  $async = $tcp.BeginConnect($PilotHost, 11100, $null, $null)
  $pilotOk = $async.AsyncWaitHandle.WaitOne(1500, $false)
  if ($pilotOk) { $tcp.EndConnect($async) | Out-Null }
} catch {
  $pilotOk = $false
} finally {
  $tcp.Close()
}
Add-Check -Name "TCP 11100 pilote" -Passed $pilotOk -Detail $PilotHost

$checks | Export-Csv -LiteralPath $ReportPath -Delimiter ";" -NoTypeInformation -Encoding UTF8
$checks | Format-Table -AutoSize
$failed = @($checks | Where-Object { $_.Result -eq "FAIL" }).Count
if ($failed -gt 0) {
  Write-Host "Recette pilote: $failed échec(s). Voir $ReportPath" -ForegroundColor Red
  exit 1
}
Write-Host "Recette pilote: PASS" -ForegroundColor Green
