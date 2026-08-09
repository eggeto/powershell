#remediation
$xboxOnIt = Get-AppxPackage -AllUsers *Xbox*
foreach ($app in $xboxOnIt) {
    if ($app.NonRemovable) {
        Write-Output "$($app.Name) is not removable "
        continue
    }
    try {
        $app | Remove-AppxPackage -AllUsers -ErrorAction Stop
        Write-Output "Removed $($app.Name)"
    }
    catch {
        Write-Output "Failed to remove $($app.Name): $($_.Exception.Message)"
    }
}