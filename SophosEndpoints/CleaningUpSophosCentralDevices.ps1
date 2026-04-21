<#
.SYNOPSIS
Automatically remove old devices/servers from Sophos Central, 
based on Intune device inventory (for devices) 
and last seen date (for servers).

.DESCRIPTION
Automatically remove old devices/servers from Sophos Central.
For the devices,
the script compares the device inventory in Sophos Central with the device inventory in Intune. 
If a device is not found in Intune, it is removed from Sophos Central.

For the servers,
the script checks the last seen date of the servers in Sophos Central.
If a server has not been seen for 6 or more months (can be modified), it is removed from Sophos Central.

!!CHECK THE OUTPUT CAREFULLY BEFORE REMOVING THE COMMAND FROM THE FUNCTION DeleteDevicesSophos, ONCE IT RUNS IT CAN'T BE UNDONE !!
don't forget to fill in the clientid & clientsecret!!

.EXAMPLE
=> .output

.INPUTS
nothing

.OUTPUTS
Got Intune devices
Got Token
Got tenant info
ARE YOU SURE YOU WANT TO REMOVE FOLLOWING DEVICES FROM SOPHOS CENTRAL: 
Devices not in Intune: 

hostname         lastSeenAt          type     os.name
--------         ----------          ----     -------
...                 ...               ...       ...

Servers not online for + 6 months:
hostname         lastSeenAt          type     os.name
--------         ----------          ----     -------
...                 ...               ...       ...

.NOTES
    Version:        1.0 
    Author:         eggeto
    Creation Date:  16/04/2026
    Requirements:   
    - PowerShell: 
    - Microsoft Graph PowerShell SDK modules
    - Sophos Central API credentials (client ID and client secret)
#>
###############  Intune  ###############
#paginated Graph API call for intune devices
function Get-GraphPagedResults {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )
    
    $results = @()
    $nextLink = $Uri
    
    do {
        try {
            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET
            if ($response.value) {
                $results += $response.value
            }
            $nextLink = $response.'@odata.nextLink'
        }
        catch {
            Write-Log "Error in pagination: $_"
            break
        }
    } while ($nextLink)
    
    return $results
}
#Get all Intune Devices by devicename
function GetAllIntuneDevices {
    param (
    )
    $filter = "?`$select=DeviceName"
    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices$filter"

    try {
        $intuneDevicesResponse = Get-GraphPagedResults -Uri $uri
        write-host "Got Intune devices" -ForegroundColor Green 
        return $intuneDevicesResponse
    } catch {
        write-host "failed getting Intune Devices: $_" -ForegroundColor Red
        return $Error
    }
}

###############  Sophos  ###############
#Create token
function GetSophosToken {
    param(
        $clientId,
        $clientSecret
    )
#Get Token
    try {
        $tokenResponse = Invoke-RestMethod -Method POST -Uri "https://id.sophos.com/api/v2/oauth2/token" -ContentType "application/x-www-form-urlencoded" -Body "grant_type=client_credentials&client_id=$clientId&client_secret=$clientSecret&scope=token"
        write-host "Got Token" -ForegroundColor Green
    }
    catch {
        write-host "failed getting token: $_" -ForegroundColor Red
        return $Error
    }
    $accessToken = $tokenResponse.access_token

#Get tenantId (tenant + region) 
    try {
        $tenantResponse = Invoke-RestMethod -Method GET -Uri "https://api.central.sophos.com/whoami/v1" -Headers @{ Authorization = "Bearer $accessToken" }
        write-host "Got tenant info" -ForegroundColor Green
    }
    catch {
        Write-Host "failed getting tenant info: $_" -ForegroundColor Red
        return $Error
    }

    #$tenantId = $tenantResponse.id
    #$baseUrl  = $tenantResponse.apiHosts.dataRegion

    $tenantInfo = @{
        accessToken = $accessToken
        tenantId = $tenantResponse.id
        baseUrl  = $tenantResponse.apiHosts.dataRegion
    }

    return $tenantInfo
}
#Will get all endpoints and servers!
function GetAllSophosDevices {
    param (
        $tenantInfo
    )
    $accessToken = $tenantInfo.accessToken
    $tenantId = $tenantInfo.tenantId
#Get all Sophos Devices with pagination
    $headers = @{
        Authorization = "Bearer $accessToken"
        "X-Tenant-ID" = $tenantId
    }

    $allDevices = @()
    $nextKey    = $null
    $page       = 1
    $baseUrl     = $tenantInfo.baseUrl
    do {
#Build URL  — nextKey added from page 2
        $url = "$baseUrl/endpoint/v1/endpoints?sort=lastSeenAt:asc&pageSize=100"
        if ($nextKey) {
            $url += "&pageFromKey=$nextKey"
        }

        #Write-Host "Collect page $page " -ForegroundColor Cyan

        $response = Invoke-RestMethod -Method GET -Uri $url -Headers $headers

        $allDevices += $response.items
        $nextKey     = $response.pages.nextKey
        $page++

    } while ($nextKey)

    #Write-Host "Total Sophos devices: $($allDevices.Count)" -ForegroundColor Green
    return $allDevices
}
#Remove old devices from Sophos Central (not in Intune and not active for + 6 months)
function DeleteDevicesSophos {
    param (
        $tenantInfo,
        $sortedDevices,
        $sortedServers
    )
#Merge the 2 lists
    $devicesToBeRemoved = $sortedDevices + $sortedServers
#connect to Sophos again
    $accessToken = $tenantInfo.accessToken
    $tenantId = $tenantInfo.tenantId
    $headers = @{
        Authorization = "Bearer $accessToken"
        "X-Tenant-ID" = $tenantId
    }
    $baseUrl= $tenantInfo.baseUrl

#removing the devices
    foreach ($device in $devicesToBeRemoved) {

        try {
            write-host "Removing device: $($device.hostname)" -ForegroundColor Yellow
#if you are pretty sure, you can command this
            Start-Sleep -Seconds 10
            Invoke-RestMethod -Method DELETE -Uri "$baseUrl/endpoint/v1/endpoints/$($device.id)" -Headers $headers | Out-Null
        }
        catch {
            Write-Warning "error removing device:  $($device.hostname): $_"
        }
    }
}
###############  Filtering/Sorting  ###############
#Sort clients that are not in Intune (by devicename/hostname)
function SortDevices {
    param (
        $listSophosDevices,
        $listIntuneDevices
    )
    $allNotMatched = [System.Collections.Generic.List[object]]::new()
    foreach ($sophosDevice in $listSophosDevices) {
        $deviceType = $sophosDevice.type
        if ($deviceType -eq "server"){
            continue
        }
        $found = $false
        foreach  ($intuneDevice  in $listIntuneDevices) {
            $sophosHostname = $sophosDevice.hostname
            $intuneDeviceName = $intuneDevice.DeviceName
            if ($sophosHostname -eq $intuneDeviceName) {
                $found = $true
                break
            }
        }
       
        if (-not $found -and $deviceType -ne "server") {
            #Write-Host "Not found: $sophosDevice"
            $allNotMatched.add($sophosDevice)
        } 
<#
        else {
            #Write-Host "Found: $sophosDevice"
        }   
#>
    }
    return $allNotMatched
}
#Sort servers that are not online for + 6 months 
function SortServers {
    param (
        $listSophosDevices
    )
#Get all non active servers
    $targetDate = (Get-Date).AddMonths(-6)

    $oldServers = [System.Collections.Generic.List[object]]::new()
    foreach ($device in $listSophosDevices) {
        $deviceDate = [datetime]$device.lastSeenAt #lastseen => it is a string!! 
        $deviceType = $device.type
        if ($deviceType -eq "server" -and $deviceDate -lt $targetDate) {
            $oldServers.Add($device) #start using method add() instead of += !!!!
        }
    }
    return $oldServers
}
###############  MAIN  ###############
Connect-MgGraph
$allIntuneDevices = GetAllIntuneDevices

#Config => in Sophos Central -> Global Settings -> API Credentials Management
$clientId     = "YOUR CLIENT ID"
$clientSecret = "TOYR CLIENT SECRET"

$tenantInfo = GetSophosToken -clientId $clientId -clientSecret $clientSecret
$allSophosDevices = GetAllSophosDevices -tenantInfo $tenantInfo

write-host "ARE YOU SURE YOU WANT TO REMOVE FOLLOWING DEVICES FROM SOPHOS CENTRAL: " -ForegroundColor Red
write-host "Devices not in Intune: " -ForegroundColor Yellow
$sortedDevices = SortDevices -listSophosDevices $allSophosDevices -listIntuneDevices $allIntuneDevices
$sortedDevices | Select-Object hostname,lastSeenAt,type,os.name | Format-Table -AutoSize
write-host "Servers not online for + 6 months: " -ForegroundColor Yellow
$sortedServers = SortServers -listSophosDevices $allSophosDevices 
$sortedServers | Select-Object hostname,lastSeenAt,type,os.name | Format-Table -AutoSize

#made it a command for your own safety :-), removing the command at your own risk
#DeleteDevicesSophos -tenantInfo $tenantInfo -sortedDevices $sortedDevices -sortedServers $sortedServers
disConnect-MgGraph
