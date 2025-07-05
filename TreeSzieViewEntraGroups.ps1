<#
.DESCRIPTION
Tree size view entra groups till 3 levels,
entra-id should be flat ... :-)
it's not pretty, but it works :-)
if i  find some extra time, i will improve it

think the opposite way (from lower to higher)will be easier

.OUTPUTS
the output is like follow:
|  aaa - testgroep1
|   -  testgroep2
|   -  -  test group
|   -  -  testgroep3

.NOTES
    Version:        1
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


Connect-MgGraph
#---------------------------------------MAIN-------------------------
#loop per group and check if the group has an member group

$allMainGroupIds = GetAllMainGroups

#------------------level 0-----------------------------
$listAllMainGroups = @()
foreach ($groupId in $allMainGroupIds) {

    $level = 0
    $groupMain = GroupInformation -groupInfo $groupId
    $groupMain | Add-Member -MemberType NoteProperty -Name 'level' -Value $level
    $checkHigher = GroupMemberFromHigherGroups -groupId $groupId
    $checkLower = TheFollowLowerGroup -groupId $groupId
    if ($checkHigher.count -gt 0){
        #if true == subfolder
        continue  
    }
    elseif ($checkLower.count -gt 0) { #has lower groups
#------------------level 1 -----------------------------
        $level = 1
        $listAllSubGroups = @()
        foreach ($groupSubId in $checkLower) {
            $checkLowerSub = TheFollowLowerGroup -groupId $groupSubId
            $groupSub = GroupInformation -groupInfo $groupSubId
            $groupSub | Add-Member -MemberType NoteProperty -Name 'level' -Value $level
            $listAllSubGroups += $groupSub
            $listAllSubSecondGroup = @()
            if ($checkLowerSub.count -gt 0){
#------------------level 2 -----------------------------
                $level = 2
               
                foreach ($groupSubSecondId in $checkLowerSub) {

                    $groupSubSecond = GroupInformation -groupInfo $groupSubSecondId
                    $groupSubSecond | Add-Member -MemberType NoteProperty -Name 'level' -Value $level
                    $listAllSubSecondGroup += $groupSubSecond
                    
                }
            }
            $listAllSubGroups | Add-Member -MemberType NoteProperty -Name 'SubSecondGroup' -Value $listAllSubSecondGroup
        }
        $groupMain | Add-Member -MemberType NoteProperty -Name 'SubGroup' -Value $listAllSubGroups
    }


    $listAllMainGroups += $groupMain
}
disConnect-MgGraph

$listTotalGroups = @()
$listTotalGroups += $listAllMainGroups | Sort-Object level
foreach ($item in $listTotalGroups) {
    $start = "| "
    write-host $start ( " - " * $item.Level ) $item.groupName 
    
    if ($item.SubGroup) {
        foreach ($subItem in $item.SubGroup) {
            write-host $start ( " - " * $subItem.level ) $subitem.groupName 

            if ($subItem.SubSecondGroup){
                foreach ($subSecondItem in $subItem.SubSecondGroup) {
                    write-host $start ( " - " * $subSecondItem.level ) $subSecondItem.groupName   
                }
            }
        }  
    }
}
disConnect-MgGrap
