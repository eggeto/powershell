<#
Beta!
made by Eggeto
devices not sync with Intune for x days
change $daysControl for returning all device above x days
#>

$uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/"
$responses = (Invoke-MgGraphRequest -Method GET -Uri $uri).value

$daysControl = 10

foreach ($device in $responses){
    $userDisplayName = $device.userDisplayName
    $deviceName = $device.deviceName
    $lastSyncDate = [Datetime]$device.lastSyncDateTime
    $currentDate = Get-Date
    $difference = (New-TimeSpan -Start $lastSyncDate -End $currentDate).Days

    if ($difference -gt $daysControl){
        Write-Host "Device: $deviceName from user: $userDisplayName has not sync with Intune for $difference days"
    }
}
