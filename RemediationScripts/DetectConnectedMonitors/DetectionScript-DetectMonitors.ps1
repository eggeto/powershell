#detection display(s) connected device NEWER VERSION!!!!
$allDisplays = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID


if ($allDisplays.count -gt 1){
    write-host "screens detected remediation will run"
    exit 1
}
else {
    Write-Host "no screen detected"
    exit 0
}