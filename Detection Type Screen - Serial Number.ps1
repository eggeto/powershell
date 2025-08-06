$allDisplays = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID

$allConnectedScreens = @()
foreach ($display in $allDisplays) {
    $nameChars = $display.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }
    $serialChars = $display.SerialNumberID | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }

    $nameScreen = ($nameChars -join "").Trim()
    $serialScreen = ($serialChars -join "").Trim()
    
    $connectedScreen = [PSCustomObject]@{
        nameScreen = $nameScreen
        serialScreen = $serialScreen
    }
    $allConnectedScreens += $connectedScreen
}
$ipAdres = $env:HostIP
$allConnectedScreens += $ipAdres
$allConnectedScreens.Count
if ($allConnectedScreens.Count -gt 0) {
    Write-Host $allConnectedScreens
    exit 1
} else {
    Write-Host "no screen detected"
    exit 0
}

