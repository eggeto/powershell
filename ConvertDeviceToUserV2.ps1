<#
.SYNOPSIS
convert a device group to a static user group

.DESCRIPTION
For this script, you need to install the powershell mggraph module.
It will convert an Device security group to an static User group.
Both groups must exist,
the script will NOT make the groups!
If a device has no primary user, it will be excluded

.INPUTS
group id from the user and device group

.OUTPUTS
return an custom PSobject
key = user email
value =     true                                         (if user is added to the group)
        or  list with error information + false          (if the user is NOT added to the group)

.MODULE
Microsoft.Graph.Authentication

.MADE
Eggeto

log:
25/01/2025
made script
13/06/2025
update output (psobject) + error info
#>

connect-mggraph -Scopes Group.ReadWrite.All, GroupMember.Read.All
#retrieve all device members from the group 
function GetMembersGroup {
    param (
        $groupId
    )
    $filter = "?`$select=id"
    $uridevice = "https://graph.microsoft.com/v1.0/groups/$groupId/members$filter"
    try {
        $deviceResponse = (Invoke-MgGraphRequest -Method GET -Uri $uridevice -ErrorAction SilentlyContinue -StatusCodeVariable "status1").value
    }
    catch {
        return "MAYDAY, Error details: $($_.Exception.Message)" 
    }
    $deviceResponse = @($deviceResponse)

    $listDeviceId = @()
    foreach ($device in $deviceResponse){
        $deviceId = $device.id
        $listDeviceId += $deviceId
    }
    #Write-Host $listDeviceId
    return $listDeviceId
}
#retrieve all users (registered Owners) from the Device group
function GetUserId {
    param (
        $allMembersGroup,
        $groupIdUser
    )
    $deviceWithoutUser = @()
    $listOutput = @()
    foreach ($deviceId in $allMembersGroup){
        #Write-Host $deviceId
        $filterUser = "?`$select=id,mail"
        $uriUserId = "https://graph.microsoft.com/v1.0/devices/$deviceId/registeredOwners$filterUser"
        try {
            $userResponse = (Invoke-MgGraphRequest -Method GET -Uri $uriUserId -ErrorAction SilentlyContinue -StatusCodeVariable "status1").value
        }
        catch {
            return "MAYDAY, Error details: $($_.Exception.Message)"  
        }
        if (-not $userResponse.id){
            $deviceWithoutUser += $deviceId
        }
        else{
            $userMail = $userResponse.mail
            $userId = $userResponse.id
            #Write-Host "User: $userMail" -ForegroundColor Green
            $output = PutUserInGroup -UserId $userId -groupIdUser $groupIdUser
            $outputInfo = [PSCustomObject]@{
                User = $userMail
                output = $output
            }
        $listOutput += $outputInfo
        }
    }
    return $listOutput
}
#add User to the user group
function PutUserInGroup{
    param (
        $UserId,
        $groupIdUser
    )
    #write-host $allDevicesIds
    $uriGroup = "https://graph.microsoft.com/v1.0/groups/$groupIdUser/members/`$ref"
    $jsonGroup = @{  
        "@odata.id" = "https://graph.microsoft.com/v1.0/users/$userId"  
    } | ConvertTo-Json
    
    try{
        $catch = Invoke-MgGraphRequest -Method POST -Uri $uriGroup -Body $jsonGroup -ContentType "application/json" -ErrorAction SilentlyContinue -StatusCodeVariable "status1" #$catch is needed for exculde $null in the output
        #write-host " is added to the User group" -ForegroundColor Green
        return $true
    }
    catch{
        $errorMessage = "An error occurred, Error details: $_.Exception.response"
        $jsonError = [regex]::Match($errorMessage, '\{"error":\{.*\}\}\}')
        $text = $jsonError | ConvertFrom-Json
        $message = $text.error.message
        #write-host "is not added to the group beacause: $message" -ForegroundColor Red
        return $message, $false
    }
    
}

#check if group exsist
function DoesGroupExist {
    param (
        $groupId
    )
    $uri = "https://graph.microsoft.com/v1.0/groups/$groupId"

    try {
        $catch = Invoke-MgGraphRequest -Method Get -Uri $uri -ErrorAction SilentlyContinue -StatusCodeVariable "status1"
        return "Group Excist"
    }
    catch {
        return "MAYDAY, Error details: $($_.Exception.Message)"  
    }
}

#the running part
$groupIdDevices = Read-Host "Enter the DEVICE security group ID"
DoesGroupExist -groupId $groupIdDevices
$groupIdUser = Read-Host "Enter the USER security group ID"
DoesGroupExist -groupId $groupIdUser

#Get all members from the device group
$allMembersGroup = GetMembersGroup -group $groupIdDevices

#Get the user Id's from the devices + Add the users to the user security group
GetUserId -allMembersGroup $allMembersGroup -groupIdUser $groupIdUser

disconnect-mggraph
