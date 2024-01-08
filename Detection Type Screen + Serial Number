#Detection Type Screen + Serial Number

$display = Get-CimInstance WmiMonitorID -Namespace root\wmi | 
ForEach-Object {($_.UserFriendlyName -ne 0 | 
    ForEach-Object {[char]$_}) -join ""; ($_.SerialNumberID -ne 0 | 
    ForEach-Object {[char]$_}) -join ""}


if ($display -gt 2){
    Write-host $display $env:HostIP
    exit 1
}
else {
    Write-Host "no screen detected"
    exit 0
}
