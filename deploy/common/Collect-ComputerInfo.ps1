param([Parameter(Mandatory=$true)][ValidateSet('A','B','C')][string]$Room,[Parameter(Mandatory=$true)][ValidateRange(1,8)][int]$Seat,[string]$Output="$PSScriptRoot\collected")
New-Item -ItemType Directory -Force $Output|Out-Null
$net=Get-NetIPConfiguration|Where-Object{$_.IPv4Address -and $_.NetAdapter.Status -eq 'Up'}|Select-Object -First 1
[PSCustomObject]@{Room=$Room;Seat=$Seat;Hostname=$env:COMPUTERNAME;IPv4=$net.IPv4Address.IPAddress;MAC=$net.NetAdapter.LinkLayerAddress;OS=(Get-CimInstance Win32_OperatingSystem).Caption;Timestamp=(Get-Date).ToString('s')} |
  Export-Csv (Join-Path $Output "$env:COMPUTERNAME.csv") -Delimiter ';' -NoTypeInformation -Encoding UTF8
