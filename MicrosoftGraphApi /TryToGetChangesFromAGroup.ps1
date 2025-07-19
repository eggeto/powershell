<#
!!!!!!!!!!!!!!work in progress!!!!!!!!!!!!!!!!!!

!!!!!!!!!!!! works only for groups >> user/device/group added/deleted from a group >> No date available!!!!!!!!!!!!!!

.SYNOPSIS

get recent changes made to a certan group using delta
delta returns an entra id object,
there is no pattern to identify if the id is a user, group, device ...
with directoryObject we try do identifie the id
with delta there is no date available when an item is added or deleted
the usable info for me is: id (group id), displayname (name from the group) and members (users added or delted)

#when an item is removed
@odata.type                    #microsoft.graph.device
id                             xxxxxxxxxxxxxxxxxxxxxxxxx
@removed                       {[reason, deleted]}
when an items is added
@odata.type                    #microsoft.graph.user
id                             xxxxxxxxxxxxxxxxxxxxxxxxx

both user and device use displayName => can't use displayName unless i add something specifiek for a device, i choose "managementType"

output:
device => mdm == microsoft intune
DeviceEntraId => mdm == none == azure registered
user == user
group == group

.INPUTS
group id from an entra group or type all for all groups

.MODULE
Microsoft.Graph.Authentication

.MADE
Eggeto

logs:
09/02/2025
made working script
#>

Connect-MgGraph
function TryToGetItemInfo {
    param (
        $changeId
    )
    $informationItem = @{}
    try {
        $uriId = "https://graph.microsoft.com/v1.0/directoryObjects/$changeId"
        $response = Invoke-MgGraphRequest -Method GET -Uri $uriId -StatusCodeVariable "status"
        $manType = $response.managementType
        $deviceName = $response.displayName
        $userMail = $response.Mail
        $folderDescription = $response.description
        if ($null -ne $deviceName -and $null -ne $manType){
            $informationItem["Device"] += $deviceName
            return $informationItem
        }
        elseif ($null -ne $userMail) {
            $informationItem["User"] += $userMail
            return $informationItem
        }
        elseif ($null -ne $folderDescription) {
            $informationItem["Group"] += $response.description
            return $informationItem
        }
        elseif ($null -ne $deviceName) {
            $informationItem["DeviceEntraId"] += $deviceName
            return $informationItem
        }
    }
    catch {
        write-host "the id: $changeId is not found"
    }
}
#Get Information About A group
function GetInformationAboutAgroup {
    param (
        $groupId
    )
    $filter = "?`$select=id,displayName,members"
    $uri = "https://graph.microsoft.com/v1.0/groups/delta$filter"

    $response = (Invoke-MgGraphRequest -Method GET -uri $uri).value
    #the id from the group you want to see the changes made

    #collection of all the changes made
    $listAllChangesMade = @()

    foreach ($item in $response){
        $id = $item.id
        if ($id -eq $groupId){
            $allChanges = $item.'members@delta'
            if ($allChanges -isnot [system.array]) {
                $allChanges = @($allChanges)
                }
            #$allChanges
            #$allChanges[-1]
            foreach ($change in $allchanges){
                $hashInformation = @{}
                $changeId = $change.id
                #return key (object type(user,device,group)) : value (namedevice/group/email)
                $whatKindOf = TryToGetItemInfo -changeId $changeId
                $kindOf = $whatKindOf.Keys
                $name = $whatKindOf.Values
                #$change
                #$change.'@removed'

                if ($null -eq $change.'@removed'){
                    $hashInformation[$kindOf] = @($name, "added")
                    $listAllChangesMade += $hashInformation
                    #Write-Host "$kindOf : $name is added to the group"
                }
                else {
                    $hashInformation[$kindOf] = @($name, "removed")
                    $listAllChangesMade += $hashInformation
                    #Write-Host "$kindOf : $name is deleted from the group"
                }
            }
        }
    }
    return $listAllChangesMade
}

$uriGroup = "https://graph.microsoft.com/v1.0/groups/delta"
$responseGroup = (Invoke-MgGraphRequest -Method GET -uri $urigroup).value
$groups = Read-Host "type 'all' if you want the information of all groups or give one group Id"
if ($groups -eq "all") {
    foreach ($group in $responseGroup) {
        $groupsId = $group.id
        $informationAllGroups = GetInformationAboutAgroup -groupId $groupsId
        $tryGetGroupName = TryToGetItemInfo -changeId $groupsId
        $groupName = $tryGetGroupName.Values[0]
        write-host $groupName -ForegroundColor Green
        $informationAllGroups
    }
}
else {
    $infromationOneGroup = GetInformationAboutAgroup -groupId $groups
    $groupName = TryToGetItemInfo -changeId $groupsId
    $tryGetGroupName = TryToGetItemInfo -changeId $groupsId
    $groupName = $tryGetGroupName.Values[0]
    write-host $groupName -ForegroundColor Green
    $infromationOneGroup
}
Disconnect-MgGraph


<#

#return information about a deleted user
function InformationDeletedUser {
    param (
        $userId
    )
    $filter = "?`$select=displayName,jobTitle"
    $uriDeletedUser = "https://graph.microsoft.com/v1.0/directory/deletedItems/$userId$filter"
    $response = Invoke-MgGraphRequest -Method GET -uri $uriDeletedUser
    $response

    
}

$filter = "?`$select=id,mail"
$uriUsers = "https://graph.microsoft.com/v1.0/users/delta$filter"
$response = (Invoke-MgGraphRequest -Method GET -uri $uriUsers).value

https://graph.microsoft.com/v1.0/devices/delta
https://graph.microsoft.com/v1.0/users/delta > from removed users you can't get the name only the id > https://graph.microsoft.com/v1.0/directory/deletedItems/id no date available
https://graph.microsoft.com/v1.0/applications/microsoft.graph.delta() > displayname, createdatetime

#>
