#detection
$xboxOnIt = Get-AppxPackage -AllUsers *Xbox* 
if ($xboxOnit){
    write-host "xbox apps are installed"
    foreach ($app in $xboxOnIt) {
        if ($app.NonRemovable) {
            Write-Output "Skip $($app.Name) - marked NonRemovable"
            continue
        }
        Write-Output "Got $($app.Name) - marked for removal"
    }
    exit 1
}
else {
    write-host "xbox apps are not installed"
    exit 0
}
