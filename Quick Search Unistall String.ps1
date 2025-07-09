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

.NOTES
    Version:        3 => back from main group to the next lower sub groups
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
function NextLowerGroups { #below
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
#
function OneLevelGroups { #skipto list nog toevoegen
    param (
        $groupId,
        $level
        #[parameter(mandatory=$true)]
        #[AllowEmptyCollection()]
        #[array]$Global:list
    )

#Get group info + add level  
    $groupInfo = GroupInformation -groupInfo $groupId
    $groupInfo | Add-Member -MemberType NoteProperty -Name 'level' -Value $level
    if (-not ($groupId -in $listToSkip)) {
        $Global:list += $groupInfo
        $Global:listToSkip += $groupId
    }
    
#are there lower groups
    $allLowerGroups = AllGroupMemberFromLowerGroups -groupId $groupId
#if there are no lower groups = no nesting
    if ($allLowerGroups.count -eq 0){
        return $Global:list
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

#connect-mggraph
#get all the main groups (level 0)
$allGroupIds = "e2cbf896-9b0b-4ff8-b6ba-8de1a7963e6d" #GetAllGroupsId
$allGroupIds = @($allGroupIds)
$bigBeautyFullList = @() #
$listToSkip = @()


#start the Main loop
foreach ($currentId in $allGroupIds) {
#skiplist, if group id in skip list, the group is already processed, so skip it
    if ($currentId -in $listToSkip) {
        continue
    }
#start level
    $level = 0
#for every Main id an empty list
    #$listCurrentGroup = @()
    $list = @()
    $currentgroup = OneLevelGroups -groupId $currentId -level $level #-list $list
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

