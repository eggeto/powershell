#detection
$xboxOnIt = Get-AppxPackage -AllUsers *Xbox* 
if ($xboxOnit){
    write-host "xbox apps are installed"
    foreach ($app in $xboxOnIt) {
        if ($app.NonRemovable) {
            Write-Output "Skipping $($app.Name) - marked NonRemovable"
            continue
        }
    }
    exit 1
}
else {
    write-host "xbox apps are not installed"
    exit 0
}
