param(
  [string]$InventoryPath = "$PSScriptRoot\..\..\inventory\pc-inventory.csv",
  [string]$ReportPath = "$PSScriptRoot\connectivity-report.csv",
  [int]$TimeoutMs = 1500
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $InventoryPath)) { throw "Inventaire introuvable: $InventoryPath" }

function Test-TcpPort {
  param([string]$ComputerName, [int]$Port, [int]$Timeout)
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $async = $client.BeginConnect($ComputerName, $Port, $null, $null)
    $ok = $async.AsyncWaitHandle.WaitOne($Timeout, $false)
    if (-not $ok) { return $false }
    $client.EndConnect($async) | Out-Null
    return $true
  } catch {
    return $false
  } finally {
    $client.Close()
  }
}

$rows = Import-Csv -LiteralPath $InventoryPath -Delimiter ";"
$results = foreach ($row in $rows) {
  $targetHost = if ($row.HostAddress) { $row.HostAddress } else { $row.DesiredHostname }
  $reachable = Test-TcpPort -ComputerName $targetHost -Port 11100 -Timeout $TimeoutMs
  [PSCustomObject]@{
    Room = $row.Room
    Seat = $row.Seat
    Host = $targetHost
    Veyon11100 = $reachable
    CheckedAt = (Get-Date).ToString("s")
  }
}

$results | Export-Csv -LiteralPath $ReportPath -Delimiter ";" -NoTypeInformation -Encoding UTF8
$results | Format-Table -AutoSize
$ok = @($results | Where-Object { $_.Veyon11100 -eq $true }).Count
Write-Host "Veyon joignable: $ok / $($results.Count)" -ForegroundColor $(if ($ok -eq 24) { "Green" } else { "Yellow" })
if ($results.Count -ne 24 -or $ok -ne 24) { exit 2 }
