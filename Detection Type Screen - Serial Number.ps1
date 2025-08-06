#Detection Type Screen + Serial Number
$displays = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID

$displayInfo = foreach ($display in $displays) {
    $nameChars = $display.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }
    $serialChars = $display.SerialNumberID | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }

    $nameScreen = ($nameChars -join "").Trim()
    $serialScreen = ($serialChars -join "").Trim()

    "$nameScreen ($serialScreen)"
}

if ($displayInfo.Count -gt 0) {
    Write-Host "$($displayInfo -join ', ') $env:HostIP"
    exit 1
} else {
    Write-Host "no screen detected"
    exit 0
}
