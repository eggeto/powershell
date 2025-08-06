#Detection Type Screen + Serial Number
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

if ($allConnectedScreens.Count -gt 0) {
    Write-Host $allConnectedScreens $env:HostIP
    exit 1
} else {
    Write-Host "no screen detected"
    exit 0
}

