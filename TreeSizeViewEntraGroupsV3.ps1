<#
.SYNOPSIS
TreeSize view for Entra Groups, ONLY GROUPS!

.DESCRIPTION
Tree size view entra id groups 
entra-id groups should be flat ... :-) 

The more groups the longer it takes! just saying

.EXAMPLE
=> .output

.INPUTS
nothing

.OUTPUTS
the output is like follow:
|   testgroep1              -> Main Group
|   -  testgroep2
|   -  -  test group
|   -  -  -  testgroup6
|   -  -  testgroep3
|   -  -  -  testgroup7
|   -  -  -  -  testgroup7a
|   -  -  -  -  testgroup7b

.NOTES
    Version:        3 => back from main group to the next lower sub groups
    Author:         eggeto
    Creation Date:  2025-07-08
    Requirements:   
    - PowerShell
    - Microsoft Graph PowerShell SDK modules

.TODO
Groups with multi nested group levels can show duplicates,

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
#Get the Id from all the Main Level Groups
function GetAllGroupsId {
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
#Give each group a level + sort from group with the most nested groups to no nested group => helps with avoiding duplicates 
function SortFromMainToSub {
    param (
        $allGroupIds
    )
    $listHigherToLower = @()
    foreach ($groupId in $allGroupIds) {
        
        $allHigher = AllGroupMemberFromLowerGroups -groupId $groupId
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
#return all the group id's from 1 Main  group 
function AllGroupMemberFromLowerGroups { # kijken om enkel groepen of apps weer te even
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
        "MAYDAY, Error details: $($_.Exception.Message)" 
    }
}
#return the lower groups
function NextLowerGroups { 
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
#check if a group have nested groups, get group info and add group to an array 
function OneLevelGroups { #skipto list nog toevoegen
    param (
        $groupId,
        $level
    )
#Get group info + add level  
    $groupInfo = GroupInformation -groupInfo $groupId
    $groupInfo | Add-Member -MemberType NoteProperty -Name 'level' -Value $level
    if (-not ($groupId -in $listCurrentGroup)) {
        $Global:listCurrentGroup += $groupInfo
        $Global:listToSkip += $groupId
    }
#are there lower groups
    $allLowerGroups = AllGroupMemberFromLowerGroups -groupId $groupId
#if there are no lower groups = no nesting
    if ($allLowerGroups.count -eq 0){
        return $Global:listCurrentGroup
    }
#subgroups
    elseif ($allLowerGroups.count -gt 0) {
        $level += 1
        $nextLevelGroups = NextLowerGroups -groupId $groupId
        MultiLevelGroup -nextGroupIds $nextLevelGroups -level $level
    }
}
#basicly recalling the function OneLevelGroups
function MultiLevelGroup {
    param (
        $nextGroupIds,
        $level
    )
    $nextGroupIds = @($nextGroupIds)
    foreach ($currentGroupId in $nextGroupIds) {
        OneLevelGroups -groupId $currentGroupId -level $level
    } 
}
#---------------------------------------MAIN-------------------------
connect-mggraph -Scopes Group.Read.All, GroupMember.Read.All
#get all the main groups (level 0)
$allGroupIds =  GetAllGroupsId   
#Sort the group Id, 
$allSortedGroups = SortFromMainToSub -allGroupIds $allGroupIds

$bigBeautyFullList = @() #pleace, don't think of me less now
$listToSkip = @() # skip list

#start the Main loop
foreach ($currentId in $allSortedGroups) {
#skiplist, if group id in skip list, the group is already processed, so skip it
    if ($currentId -in $listToSkip) {
        continue
    }
#start level
    $level = 0
#for every Main id an empty list
    $listCurrentGroup = @()
    $currentgroup = OneLevelGroups -groupId $currentId -level $level 
    $bigBeautyFullList += $currentgroup
#add the id's to the listToSkip  
}
$bigBeautyFullList = $bigBeautyFullList 

#write the tree structure, you can at thing that are in the function: GroupInformation  
foreach ($item in $bigBeautyFullList) {
    $start = "| "
    write-host $start ( " - " * $item.Level ) $item.groupName # " - " $item.groupType or ....
}
#disConnect-MgGraph