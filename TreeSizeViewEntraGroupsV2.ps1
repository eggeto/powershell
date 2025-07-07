<#
.SYNOPSIS
TreeSize view for Entra Groups, ONLY GROUPS!

.DESCRIPTION
Tree size view entra id groups 
entra-id groups should be flat ... :-) 
it's not pretty, but it works :-)
if i find some extra time, i will improve it

The more groups the longer it takes! just saying

.EXAMPLE
=> .output

.INPUTS
nothing

.OUTPUTS
the output is like follow:
|   testgroep1
|   -  testgroep2
|   -  -  testgroep3
|   -  -  test group
|   testtest
|   -  testgroep5
|   -  -  testgroep4
|   Test - device to user (device)
|   -  Test user to device


.NOTES
    Version:        2
    Author:         eggeto
    Creation Date:  2025-07-05
    Requirements:   
    - PowerShell
    - Microsoft Graph PowerShell SDK modules
#>
#input = group name or group id => check if group excist + gave basic info
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
#Get the Id from all the Main Level Groups
function GetAllMainGroups {
    param (   
    )
    $filter = "?`$select=id"
    $uri = "https://graph.microsoft.com/v1.0/groups$filter"
    try {
        $response = (Invoke-MgGraphRequest -Method Get -Uri $uri -ErrorAction SilentlyContinue -StatusCodeVariable "status1").value
        return $response.id
    }
    catch {
        $false, "MAYDAY, Error details: $($_.Exception.Message)"
    }
}
#Give each group a level + sort from low to high
function SortFromHighToLow {
    param (
        $allGroupIds
    )
    $listHigherToLower = @()
    foreach ($groupId in $allGroupIds) {
        
        $allHigher = GroupMemberFromHigherGroups -groupId $groupId
        $countHigher = $allHigher.Count

        $higherToLower = [PSCustomObject] @{
            groupId = $groupId
            listHigher = $allHigher
            count = $countHigher
        }
        $listHigherToLower += $higherToLower
    }
    $listHigherToLower = $listHigherToLower | Sort-Object count -Descending
    return $listHigherToLower.groupId
}
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
        "MAYDAY, Error details: $($_.Exception.Message)"
    }
}
#return the id from the first higher group
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
        "MAYDAY, Error details: $($_.Exception.Message)"
    }
}
#Get the id's from all the member Groups from the same level
function GetMembersSameLevel {
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
        "MAYDAY, Error details: $($_.Exception.Message)"
    }
    
}
#Get all the higher gorups
function GetAllHigherGroups {
    param (
        $currentGroup,
        $level,
        $count
    )
    $listAllHigherGroups = @()
    #loop for the next higher group 
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

#---------------------------------------MAIN-------------------------
Connect-MgGraph -Scopes Group.Read.All, GroupMember.Read.All
#Get all Group Id's
$allGroupIds = GetAllMainGroups
#Sort the groups i start with the lowest groups (or highest is the way you look at it)
$listHigherToLower = SortFromHighToLow -allGroupIds $allGroupIds
$listTotalGroups = @()
$listSkip = @()
#loop per sorted group
foreach ($highItem in $listHigherToLower) {
    #skip the duplicates 
    if ($highItem -in $listSkip){
        continue
    }
    $listAllHigherGroups = @()
    #get current group info + set/adding level
    $currentGroup = GroupInformation -groupInfo $highItem
    $allHigher = GroupMemberFromHigherGroups -groupId $currentGroup.groupId
    $countHigher = $allHigher.Count
    $level = $allHigher.Count
    $currentGroup | Add-Member -MemberType NoteProperty -Name 'level' -Value $level

    #same level groups from the current Group => but first get 1 level higher group
    $listGroupsSameLevel = @()
    $oneLevelHigher = TheFollowHigherGroup -groupId $currentGroup.groupId
    $membersCurrentLevel = GetMembersSameLevel -groupId $oneLevelHigher
    if ($membersCurrentLevel.count -gt 1){        
        foreach ($groupSameLevel in $membersCurrentLevel) {
            if ($groupSameLevel -eq $currentGroup.groupId){
                continue
            }
            #get group information + adding level
            $groupInfo = GroupInformation -groupInfo $groupSameLevel
            $groupInfo | Add-Member -MemberType NoteProperty -Name 'level' -Value $level
            $listGroupsSameLevel += $groupInfo
            #adding the group id's to the skiplist
            $listSkip += $groupSameLevel
        }
    }
    #all groups same level
    $listGroupsSameLevel += $currentGroup

    #all groups higher groups that have a relation with the currentgroup
    $highest = GetAllHigherGroups -currentGroup $currentGroup.groupId -level $level -count $countHigher
    $highest = @($highest)
    #adding the group id's to the skiplist
    foreach ($item in $highest) {
        if ($item.groupId -in $listSkip){
            continue
        }
        $listSkip += $item.groupId
    }
    #one complete tree from 1 MAIN group
    $highest += $listGroupsSameLevel
    #sort by level
    $highest = $highest | Sort-Object level


    $listAllHigherGroups += $highest

    $listTotalGroups += $listAllHigherGroups 

}
#write the tree structure, you can at thing that are in the function: GroupInformation  
foreach ($item in $listTotalGroups) {
    $start = "| "
    write-host $start ( " - " * $item.Level ) $item.groupName # " - " $item.groupType or ....
}
disConnect-MgGraph
