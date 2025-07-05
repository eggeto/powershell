<#
THIS IS A BETA!!!!
.SYNOPSIS
Get a tree kind of view frome nested groups where there is a connection between them.

.DESCRIPTION
find all higher groups, groups from the same level and 1 level lower 
with a connection between each other from and the input group
apps are yet not posible or i coudn't find it.
NEED MORE DEBUGGING FOR THE LOWER GROUPS!!!! DON'T ALWAYS SHOW THEM
and display them in order + give some basic group info

.EXAMPLE

.INPUT
A group name or A group id 

.OUTPUT
|   testgroep1 
|   -  testgroep2 
|   -  -  testgroep3
|   -  -  -  testgroep6 StartGroup => startGroup is Group name from the input
|   -  -  -  -  testgroep7

doesGroupExcist : True
groupId         : blabla
groupName       : testgroep1
groupType       : StaticMembership
level           : 0

doesGroupExcist : True
groupId         : blabla
groupName       : testgroep2
groupType       : StaticMembership
level           : 1

doesGroupExcist : True
groupId         : blabla
groupName       : testgroep3
groupType       : StaticMembership
level           : 2

doesGroupExcist : True
groupId         : blabla
groupName       : testgroep6
groupType       : StaticMembership
level           : 3
StartGroup      : StartGroup

doesGroupExcist : True
groupId         : blabla
groupName       : testgroep7
groupType       : StaticMembership
level           : 4

.NOTES
    Version:        1
    Author:         eggeto
    Creation Date:  2025-04-30
    Requirements:   
    - PowerShell
    - Microsoft Graph PowerShell SDK modules
#>
#return group information
function GroupInformation {
    param (
        $groupInfo
    )
    #Does $groupInfo match name or id
    $pattern = "^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$"
    $filterSelect = "?`$select=groupTypes,id,displayname,type"
    if ($groupInfo -match $pattern){
        #$filter = "/$groupInfo" #use filter because otherwise you don't need ().value for displayname you need to use ().value 
        $filter1 = "&`$filter=id eq '$groupInfo'"
    }
    else {
        $filter1 = "&`$filter=displayname eq '$groupInfo'" 
    }
    $uri = "https://graph.microsoft.com/v1.0/groups$filterSelect$filter1"
    try {
        $response = (Invoke-MgGraphRequest -Method Get -Uri $uri -ErrorAction SilentlyContinue -StatusCodeVariable "status1").value
        $groupId = $response.id
        if ($groupId) {
            $groupInformationComplete = [PSCustomObject] @{
                doesGroupExcist = $true
                groupId = $groupId
                groupName = $response.displayName
                groupType = if ($null -eq $response.groupTypes){"StaticMembership"} else {$response.groupTypes}
            }
            return $groupInformationComplete
        }
        else {
            return $false, "Group Does Not Exist"
        }  
    }
    catch {
        return $false, "MAYDAY, Error details: $($_.Exception.Message)"  
    }
}
#output only the Id from a certain type (user/device/groups) from a group input should be the type you want + id, odata from all the members from the group
function SortByGroupMembersType {
    param (
        $type,
        $inputInfo
    )
    $filter = switch ($type){
        "group"     {"#microsoft.graph.group"}
        "user"      {"#microsoft.graph.user"}
        "device"    {"#microsoft.graph.device"}
    }
    $inputInfo = @($inputInfo)
    $listInformationType = @()
    foreach ($item in $inputInfo) {
        #only the groups will be added not the user or devices or ...
        if ($item."@odata.type" -like $filter) {
            $typeItem = [PSCustomObject] @{
                Id = $item.Id
            }
            $listInformationType += $typeItem
        }
    } 
    return $listInformationType
    else {
        return $false
    }
}

# is the group member from another group => met transitiveMemberOf zie je de bovenliggen nested groups but not in the correcte order maar niet de onderliggende groepen
#/transitiveMembers zie je de onderliggende groepen
#met /memberOf zie de eerst bovenliggende groep
#met /members de huidige members behalve de apps
#members en membersof is 1 niveau - transitiveMembers and transitiveMemberOf zijn alle niveau's

#return all the group id's from the higher groups -> not the user, devices or ...
function GroupMemberFromHigherGroups { 
    param (
        $groupId
    )
    $filter = "?`$select=id"

    $uri = "https://graph.microsoft.com/v1.0/groups/$groupId/transitiveMemberOf$filter"
    try {
        $response = (Invoke-MgGraphRequest -Method GET -Uri $uri).value
        $output = SortByGroupMembersType -type "Group" -input $response
        return $output.id
    }
    catch {
        <#Do this if a terminating exception happens#>
    }
}
#return the first higher group
function TheFollowHigherGroup { 
    param (
        $groupId
    )
    $filter = "?`$select=id"
    $uri = "https://graph.microsoft.com/v1.0/groups/$groupId/MemberOf$filter"
    try {
        $response = (Invoke-MgGraphRequest -Method GET -Uri $uri).value
        $output = SortByGroupMembersType -type "Group" -input $response
        return $output.id
    }
    catch {
        <#Do this if a terminating exception happens#>
    }
}
#return all the group id's from the lower groups -> not the user, devices or ...
function GroupMemberFromLowerGroups { # kijken om enkel groepen of apps weer te even
    param (
        $groupId
    )
        $filter = "?`$select=id,type"

    $uri = "https://graph.microsoft.com/v1.0/groups/$groupId/transitiveMembers$filter"
    try {
        $response = (Invoke-MgGraphRequest -Method GET -Uri $uri).value
        $output = SortByGroupMembersType -type "Group" -input $response
        return $output.id
    }
    catch {
        <#Do this if a terminating exception happens#>
    }
}
#return the lower group
function TheFollowLowerGroup { #below
    param (
        $groupId
    )
    $filter = "?`$select=id"
    $uri = "https://graph.microsoft.com/v1.0/groups/$groupId/Members$filter"
    try {
        $response = (Invoke-MgGraphRequest -Method GET -Uri $uri).value
        $output = SortByGroupMembersType -type "Group" -input $response
        return $output.id
    }
    catch {
        <#Do this if a terminating exception happens#>
    }
}

#-------------------------Higher----------------------------------------------- (+/- ok) ik wil de uitkomst in omgekeerde volgerde eerst  level 0 dan level 2 3 4 ...
#ook controleren als de groupid in de loop wel overeenkomt met $allabove en $all below
function GetAllHigherGroups {
    param (
        $currentGroupMain,
        $level,
        $count
    )
    $listAllHigherGroups = @()
    #loop for the next higher group 
    $currentGroup = $currentGroupMain.groupId
    for ($i = 0; $i -lt $Count; $i++) {
        $currentGroup = TheFollowHigherGroup -groupId $currentGroup
        $currentinfo = GroupInformation -groupInfo $currentGroup
        $level = ($level - 1)
        if ($currentinfo.doesGroupExcist){
            $currentinfo | Add-Member -MemberType NoteProperty -Name 'level' -Value $level
            $listAllHigherGroups += $currentinfo
        }   
    }
    return $listAllHigherGroups
}
#------------------------------------LOWER---------------------------------------------- loopt vast bij de 2de group id, testgroep 6 ontbreekt, bij testgroep 1 staat ook 2 maal tesgroep 2
function GetAllLowerGroups {
    param (
        $currentGroupMain,
        $level,
        $count
    )
    $listAllLowerGroups = @()
    $currentGroup = $currentGroupMain.groupId
    for ($i = 0; $i -lt $Count; $i++) {
        $currentGroup = TheFollowLowerGroup -groupId $currentGroup
        if ($currentGroup.count -gt 1){
            $level = ($level + 1)
            foreach ($group in $currentGroup) {
                $currentInfoSameLevel = GroupInformation -groupInfo $group
                if ($currentInfoSameLevel.doesGroupExcist){
                    $currentInfoSameLevel | Add-Member -MemberType NoteProperty -Name 'level' -Value $level
                    $listAllLowerGroups += $currentInfoSameLevel
                }
            }
        }
        else {
            $currentinfo = GroupInformation -groupInfo $currentGroup
            $level = ($level + 1)
            if ($currentinfo.doesGroupExcist){
                $currentinfo | Add-Member -MemberType NoteProperty -Name 'level' -Value $level
                $listAllLowerGroups += $currentinfo
            }
        }
        $currentinfo = GroupInformation -groupInfo $currentGroup
        $level = ($level + 1)
        if ($currentinfo.doesGroupExcist){
            $currentinfo | Add-Member -MemberType NoteProperty -Name 'level' -Value $level
            $listAllLowerGroups += $currentinfo
        }
    }
    return $listAllLowerGroups
}

#-----------------------------MAIN-----------------------------------------
Connect-MgGraph -scope Group.Read.All, GroupMember.Read.All
$groupInfo = "YOUR GROUPNAME OR GROUPID"

$currentGroupMain = GroupInformation -groupInfo $groupInfo
#check if the group excist
if ($currentGroupMain.doesGroupExcist){
    #how many groups above + ID
    $allHigher = GroupMemberFromHigherGroups -groupId $currentGroupMain.groupId
    $countHigher = $allHigher.Count
    $level = $allHigher.Count
    $currentGroupMain | Add-Member -MemberType NoteProperty -Name 'level' -Value $level
    $currentGroupMain | Add-Member -MemberType NoteProperty -Name 'StartGroup' -Value "StartGroup"

    $higher = GetAllHigherGroups -currentGroupMain $currentGroupMain -level $level -count $countHigher

    $allLower = GroupMemberFromLowerGroups -groupId $currentGroupMain.groupId
    $countLower = $allLower.Count

    $lower = GetAllLowerGroups -currentGroupMain $currentGroupMain -level $level -count $countLower
}

$listTotal = @()
$listTotal += $higher
$listTotal += $lower
$listTotal += $currentGroupMain
$listTotal = $listTotal | Sort-Object level

foreach ($item in $listTotal) {
    $start = "| "
    if ($item.doesGroupExcist) {
        $startGroup = if($item.startGroup){$item.startGroup} else {""}
        write-host $start ( " - " * $item.Level ) $item.groupName $startGroup
    }
}
$listTotal

disConnect-MgGraph
