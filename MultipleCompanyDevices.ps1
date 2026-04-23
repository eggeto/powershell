<# 
    .SYNOPSIS
    Get the devices from user(s) with more then 1 device

    .DESCRIPTION
    For this script, you need to install the powershell mgraph module.
    It is made for filerting users with more then 1 Company Device(s)!
    from a group or single user
    You can modify the script, for example more then 3 company devices or Personal devices or ...
    

    .INPUTS
    Group Id with all users you want to check

    .OUTPUTS
    returns email, list with device names and the count for that user

    .NOTES
    Version:        1.1
    Author:         Eggeto
    Creation Date:  2025-10-08
    Requirements:   
    - PowerShell: 
    - Microsoft Graph PowerShell SDK modules
#>
###############  Intune  ###############
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
    $filter = "?`$select=DeviceName,azureADDeviceId,id,emailAddress"
    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"#$filter

    try {
        $intuneDevicesResponse = Get-GraphPagedResults -Uri $uri
        write-host "Got Intune devices" -ForegroundColor Green 
        return $intuneDevicesResponse
    } catch {
        write-host "failed getting Intune Devices: $_" -ForegroundColor Red
        return $Error
    }
}
#check if the intune device is copany or personal + intune device id is the same as Microsoft entra id => bad syncronised device
function CheckTheDeviceIds {
    param (
        $allIntuneDevices
    )
    $allTheBadSyncDevices = [System.Collections.Generic.List[object]]::new()
    foreach ($device in $allIntuneDevices) {
        if ($device.managedDeviceOwnerType -eq "personal") {
            continue
        }
        if ($device.azureADDeviceId -eq $device.id) {
            $allTheBadSyncDevices.Add($device.DeviceName)
        }
    }
    return $allTheBadSyncDevices
}
#Get all users from a group
function GetUserFromGroup {
    param (
        $groupId
    )
    $filter = "?`$select=mail"
    $uri = "https://graph.microsoft.com/v1.0/groups/$groupId/members$filter"
    try {
        $response = Get-GraphPagedResults -Uri $uri
        write-host "Got users from group" -ForegroundColor Green
        return $response
    }
    catch {
        return "MAYDAY for $upn, Error details: $($_.Exception.Message)"  
    }
}
#Search for users with more then 1 device
function SearchDoubleDevices {
    param (
        $user = "tom.eggermont@cevi.be"
    )
    $uri = "https://graph.microsoft.com/v1.0/users/$user/managedDevices"
    try {
        $response = (Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction SilentlyContinue -StatusCodeVariable "status1").value
        if ($response.count -gt 1) {
            $devices = [System.Collections.Generic.List[object]]::new()
            foreach ($device in $response) {
                $devices.Add($device.DeviceName)
            }
            $userInfo = [PSCustomObject]@{
                UserMail = $user
                DeviceNames = $devices
                count = $response.count
            }
            return $userInfo
        }
    }
    catch {
        #write-host "MAYDAY for $user, Error details: $($_.Exception.Message)"    
    }
}
###############  Main  ###############
function Main {
    param (
        $groupId
    )
    $allUsers = GetUserFromGroup -groupId $groupId
    $allUsersWithDoubleDevices = [System.Collections.Generic.List[object]]::new()
    foreach ($user in $allUsers) {

        $userMail = $user.mail
        if ($null -eq $userMail) {
            continue
        }
        $UsersWithDoubleDevice = SearchDoubleDevices -user $userMail
        if ($null -ne $UsersWithDoubleDevice) {
            $allUsersWithDoubleDevices.Add($UsersWithDoubleDevice)
        }   
    }
    write-host "The follow users have more then 1 device:" -ForegroundColor Yellow
    $allUsersWithDoubleDevices | Format-Table UserMail, DeviceNames, Count -AutoSize

    $allIntuneDevices = GetAllIntuneDevices
    $allBadSyncDevices = CheckTheDeviceIds -allIntuneDevices $allIntuneDevices
    Write-Host "The follow devices have the same Intune device id and Microsoft Entra id, they are not syncronised correctly with intune:" -ForegroundColor Yellow
    $allBadSyncDevices
}

Connect-mgGraph
$groupId = "291a3ee7-5fcb-4d8d-ac14-0b108f2b8f7c"
Main -groupId $groupId

#disConnect-mgGraph
