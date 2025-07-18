<#
.SYNOPSIS
convert a device group to a static user group
or convert a user group to a static device group

.DESCRIPTION
For this script, you need to install the powershell mggraph module.
It will convert an Device security group to an static User group
or visa versa
Both groups must exist,
the script will NOT make the groups!
If a device has no primary user, it will be excluded

.INPUTS
group name from the user and device group + type (read example)

.OUTPUTS
return an custom PSobject
key     = user email
value   = true 
    or    false + list with error information

.Example
ConvertGroup -nameDeviceGroup "YOUR GROUP NAME" -nameUserGroup "YOUR GROUP NAME" -type devices  ==>> convert a group with only devices to a group with the primary users from the devices
ConvertGroup -nameDeviceGroup "YOUR GROUP NAME" -nameUserGroup "YOUR GROUP NAME" -type users    ==>> convert a group with only users to a group with the devices the user is primary user from

.MODULE
Microsoft.Graph.Authentication

.MADE
Eggeto

log:
25/01/2025
made script
13/06/2025
update output (psobject) + error info
18/06/2025
Modify the input and the running function,
now you can convert a device group to a user group and a user group to a device group
changed the name to ConvertAGroup

TO DO:
make an Module from it
make also the group id possible as input
#>

connect-mggraph -Scopes Group.ReadWrite.All, GroupMember.Read.All
#Convert group name into group ID + check if group exist
function GetGroupId {
    param (
        $groupName
    )
    $filter = "?`$select=id,displayName&`$filter=displayname eq '$groupName'"
    $uri = "https://graph.microsoft.com/v1.0/groups$filter"
    try {
        $response = (Invoke-MgGraphRequest -Method Get -Uri $uri -ErrorAction SilentlyContinue -StatusCodeVariable "status1").value
        $groupId = $response.id
        if ($groupId) {
            return $true, $groupId
        }
        else {
            return $false, "Group Does Not Exist"
        }  
    }
    catch {
        return $false, "MAYDAY, Error details: $($_.Exception.Message)"  
    }
}
#retrieve all device members from the group 
function GetIdMembersGroup {
    param (
        $groupId,
        $type
    )
    $filter = switch ($type) {
        "devices" { "?`$select=id" }
        "users"   { "?`$select=userPrincipalName" }
    }
    $uri = "https://graph.microsoft.com/v1.0/groups/$groupId/members$filter"
    try {
        $response = (Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction SilentlyContinue -StatusCodeVariable "status1").value
    }
    catch {
        return "MAYDAY, Error details: $($_.Exception.Message)" 
    }
    $response = @($response)
    $listInformation = @()
    foreach ($item in $response) {
        switch ($type) {
            "devices" { $listInformation += $item.id }
            "users"   { $listInformation += $item.userPrincipalName }
        }
    }
    return $listInformation
}
#add User to the user group
function PutItemInGroup {
    param (
        $itemId, #for device => not the same as the intune device id or the entra device id => id from /devices!!
        $groupId,
        $type
    )
    $uriGroup = "https://graph.microsoft.com/v1.0/groups/$groupId/members/`$ref"
 
    $jsonGroup = @{  
        "@odata.id" = "https://graph.microsoft.com/v1.0/$type/$itemId"  
    } | ConvertTo-Json 
    try {
        $catch = Invoke-MgGraphRequest -Method POST -Uri $uriGroup -Body $jsonGroup -ContentType "application/json" -ErrorAction SilentlyContinue -StatusCodeVariable "status1" 
        return $true
        }
    catch {
        $errorMessage = "An error occurred, Error details: $_.Exception.response"
        $jsonPart = [regex]::Match($errorMessage, '\{"error":\{.*\}\}\}')
        $text = $jsonPart | ConvertFrom-Json
        $message = $text.error.message
        return $false, $message
    }
}
#retrieve all users (registered Owners) from the Device group
function GetUserId {
    param (
        $allIdMembersGroup,
        $userGroupId,
        $type  ##nodig???
    )
    $deviceWithoutUser = @()
    $listOutputUsers = @()
    foreach ($deviceId in $allIdMembersGroup){
        $filterUser = "?`$select=id,mail"
        $uriUserId = "https://graph.microsoft.com/v1.0/devices/$deviceId/registeredOwners$filterUser"
        try {
            $responseUsers = (Invoke-MgGraphRequest -Method GET -Uri $uriUserId -ErrorAction SilentlyContinue -StatusCodeVariable "status1").value
        }
        catch {
            return "MAYDAY, Error details: $($_.Exception.Message)"  
        }
        if (-not $responseUsers.id){
            $deviceWithoutUser += $deviceId
        }
        else{
            $userMail = $responseUsers.mail
            $itemId = $responseUsers.id
            #Write-Host "User: $userMail" -ForegroundColor Green
            $output = PutItemInGroup -itemId $itemId -groupId $userGroupId -type "users"
            $outputInfo = [PSCustomObject]@{
                User = $userMail
                output = $output
            }
        $listOutputUsers += $outputInfo
        }
    }
    return $listOutputUsers
}
#retrieve all Devices from the user group
function GetDevicesID {
    param (
        $allIdMembersGroup,
        $deviceGroupId
    )
    $listOutputDevices = @()
    foreach ($upn in $allIdMembersGroup){
        #from the user principal name, get the managed devices only
        $filter = "?`$select=deviceName"
        $urimanageddevices = "https://graph.microsoft.com/v1.0/users/$upn/managedDevices$filter"
        try {
            $responseDevices = (Invoke-MgGraphRequest -Method GET -Uri $urimanageddevices).value
        }
        catch {
            Write-Host "MAYDAY, $upn, Error details: $($_.Exception.Message)"
        }

        #check if an user has more then 1 device
        UserWithMoreDevices -upn $upn -devicePerUser $responseDevices

        foreach ($device in $responseDevices){
            $displayName = $device.Values #$responseDevices.displayname
            $filter = "?`$filter=displayName eq '$displayName'"
            $filter2 = "&`$select=id"
            $uriDeviceId = "https://graph.microsoft.com/v1.0/devices$filter$filter2"
            #write-host $uriDeviceId
            try {
                $responce = (Invoke-MgGraphRequest -Method GET -Uri $uriDeviceId).value
                $idDevice = $responce.id
                $output = PutItemInGroup -itemId $idDevice -groupId $deviceGroupId -type "devices"
                $outputInfo = [PSCustomObject]@{
                    User = $upn
                    output = $output
                }
                $listOutputDevices += $outputInfo
            }
            catch {
                return "MAYDAY, Error details: $($_.Exception.Message)"
            }  
        }
    }
    return $listOutputDevices
}
#User with more then one device
function UserWithMoreDevices {
    param (
        $upn,
        $devicePerUser
    )
    $listDeviceNames = @()
    foreach ($device in $devicePerUser){
        $deviceName = $device.deviceName
        $listDeviceNames += $deviceName
    }

    $countDevice = $listDeviceNames.Count
    if ($countDevice -gt 1){
        write-host "User: $upn has $countDevice managed device $listDeviceNames" -ForegroundColor Green
    }
    else {
        write-host "User: $upn has 1 managed device $listDeviceNames" -ForegroundColor Green
    }
}
function ConvertGroup {
    param (
        [Parameter(Mandatory = $true)]
        [string]$nameDeviceGroup,
        [Parameter(Mandatory = $true)]
        [string]$nameUserGroup,
        [Parameter(Mandatory = $true)]
        [ValidateSet('users', 'devices')]
        [string]$type
    )
    $deviceGroupId = GetGroupId -groupName $nameDeviceGroup
    $userGroupId = GetGroupId -groupName $nameUserGroup

    if ($deviceGroupId[0] -and $userGroupId[0]) {
        switch ($type) {
            'devices' {
                $allIdMembersGroup = GetIdMembersGroup -groupId  $deviceGroupId[1] -type $type
                GetUserId -allIdMembersGroup $allIdMembersGroup -userGroupId $userGroupId[1] -type $type
                }
            'users' {
                $allIdMembersGroup = GetIdMembersGroup -groupId  $userGroupId[1] -type $type
                GetDevicesID -allIdMembersGroup $allIdMembersGroup -deviceGroupId $deviceGroupId[1] -type $type
            }
        }
    }
    else {
        return $deviceGroupId[1], $userGroupId[1]
    }
}

disconnect-mggraph
