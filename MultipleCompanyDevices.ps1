<# 
    .SYNOPSIS
    Get the devices from user(s) with more then 1 device

    .DESCRIPTION
    For this script, you need to install the powershell mgraph module.
    It is made for filerting users with more then 1 Company Device(s)!
    from a group or single user
    You can modify the script, for example more then 3 company devices or Personal devices or ...

    .INPUTS
    A group Id from a group, where the member(s) are user(s) => UsersWithMoreCompanyDevices -groupId $groupId
    or for one user, principal name or email => CountCompanyDevices -upn $upn

    .OUTPUTS
    The output is an psobject, contains the user mail and the device names in a list
    you can modify this also to an array or ...

    Made by Eggeto

    .logs
    made 02/06/2025
    added a filter in function UsersWithMoreCompanyDevices,
    no filter yet for function CountCompanyDevices, need to think about that

    .to do
    ask what the user preffer, number of devices, company or personal
#>

Connect-MgGraph -Scopes User.Read.All,GroupMember.Read.All,Group.Read.All
#Check if a list with devices are company or personal
function IsCompanyDevice {
    param (
        $response    
    )
    $listCompanyOwnedDevices = @()
    $listPersonalOwnedDevices = @()
    foreach ($device in $response) {
        if($device.managedDeviceOwnerType -contains "company"){
            $listCompanyOwnedDevices += $device
        }
        else {
            $listPersonalOwnedDevices += $device
        }
    }  
    return $listCompanyOwnedDevices  
}
#return psobject when a user have more then 1 company device
function CountCompanyDevices { #i want every one with mor then 1 device
    param (
        $upn
    )
    $uri = "https://graph.microsoft.com/v1.0/users/$upn/managedDevices"
    try {
        $response = (Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction SilentlyContinue -StatusCodeVariable "status1").value
    }
    catch {
        return "MAYDAY for $upn, Error details: $($_.Exception.Message)"  
    }
    $response = @($response)
    #$arrayCompanyOwnedDevices = @{}
    $companyOwnedDevices = IsCompanyDevice -response $response

    $count = $companyOwnedDevices.deviceName.count # count is 55?

    if($count -gt 1){ #change this to whatever you want
        $resultCompanyOwnedDevices = [PSCustomObject]@{
            Name = $upn
            Devices = $companyOwnedDevices.deviceName
        }
        return $resultCompanyOwnedDevices
        #return $upn, $companyOwnedDevices.deviceName 
        #or
        #$arrayCompanyOwnedDevices[$upn] = $companyOwnedDevices.deviceName
        #return $arrayCompanyOwnedDevices
    }
    else {
        write-host "$upn has 1 or null device"
        return $null
    } 
}
#looping a user group
function UsersWithMoreCompanyDevices {
    param (
        $groupId
    )
    $filter = "?`$select=mail"
    $uri = "https://graph.microsoft.com/v1.0/groups/$groupId/members$filter"
    try {
        $response = (Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction SilentlyContinue -StatusCodeVariable "status1").value
    }
    catch {
        Write-Host "MAYDAY for $upn"
        return "Error details: $($_.Exception.Message)"  
    }
    $response = @($response)
    $userFromGroup = $response.mail #$response.userPrincipalName

    $listUserDevice = @()
    foreach ($user in $userFromGroup) {
        $outputUser = CountCompanyDevices -upn "$user"
        $listUserDevice += $outputUser
    }
    $listUserDevice
}

$groupId = "YOUR GROUP ID"
UsersWithMoreCompanyDevices -groupId $groupId

DisConnect-MgGraph
