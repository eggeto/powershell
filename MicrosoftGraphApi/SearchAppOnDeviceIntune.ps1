<#


search for a specific app on all the devices in your tenant
returns a hash table, ($deviceWithApp)
as key the device name
as value an arrey with the appname, verion and other information

there is an arrey ($deviceWithNoApp),
that return the devices where the app is not installed

Need to run in BETA (ms graph) at the moment (not v1)!!!


made by Eggeto

log:
jun 25 2024
created Beta app

aug 31 2024
Version V1 finished

08/06/2025
update
#>

#connect to microsoft graph
Connect-MgGraph #-scope !!yet to find out!!

#search for app, change this!!!!!!!!
$search = Read-Host "Enter the name of a program"
$searchApp = "*$($search)*"

#get all devices
$filter = "?`$select=id, deviceName" #intune ID
$uriAllDevice = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices$filter"
try {
    $responseAllDevices = (Invoke-MgGraphRequest -uri $uriAllDevice -Method Get -OutputType PSObject -ErrorAction SilentlyContinue -StatusCodeVariable "status1").value
}
catch {
    #return "MAYDAY for $upn, Error details: $($_.Exception.Message)"
}

#Creating data structure
$deviceWithApp = @{}
$deviceWithNoApp = @()

#loop all the devices
foreach ($device in $responseAllDevices){
    #Get all detected Apps for intune device id
    $uriDetectedApps = "https://graph.microsoft.com/beta/deviceManagement/manageddevices/$intuneId/detectedApps"
    try {
        $responsesApps = (Invoke-MgGraphRequest -uri $uriDetectedApps -Method Get -OutputType PSObject -ErrorAction SilentlyContinue -StatusCodeVariable "status1").value
    }
    catch {
    #return "MAYDAY for $upn, Error details: $($_.Exception.Message)"
    }
    
    #looking for specific app
    $appsPerDevice = @()
    foreach ($app in $responsesApps){
        if ($app.displayName -like $searchApp){
            $appsPerDevice += $app
        }
    }

    #if search app on device add to hash table + app info
    $deviceName = [string]$device.deviceName
    if ($appsPerDevice.count -gt 0){

        $deviceWithApp[$deviceName] = $appsPerDevice
    } else { # add to arrey where the app is not found on the device
        $deviceWithNoApp += $deviceName
    }
}    

#output
#loop hash table
foreach ($key in $deviceWithApp.keys){
    write-host $key -ForegroundColor Green -
    foreach ($value in $deviceWithApp[$key]) {
        $value 
    }
}

write-host "devices with the app not installed: $deviceWithNoApp"

#Disconnect from ms graph
Disconnect-MgGraph
