<#
.SYNOPSIS
TreeSize view for Entra Groups, ONLY GROUPS!!

.DESCRIPTION
Tree size view entra id groups 
entra-id groups should be flat ... :-) 

The more groups the longer it takes! just saying

.EXAMPLE
=> .output

.INPUTS
nothing

.OUTPUTS
write the json file to the C:\temp\nestedGroups.json"
[
  {
    "doesGroupExist": true,
    "groupId": "e2cbf896-9b0b-4ff8-b6ba-8de1a7963e6d",
    "groupName": "testgroep1",
    "groupType": "StaticMembership",
    "level": 0,
    "groupNumber": 1,
    "nestedGroup": [
      {
        "doesGroupExist": true,
        "groupId": "13a22ce5-4e6a-481e-9072-7accd68cf9b1",
        "groupName": "testgroep2",
        "groupType": "StaticMembership",
        "level": 1,
        "groupNumber": 1,
        "nestedGroup": [
          {
            ... you get the idea

.NOTES
    Version:        4.1 => added json as output
    Author:         eggeto
    Creation Date:  10/04/2026
    Requirements:   
    - PowerShell: 
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
              doesGroupExist = $true
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
#paginated Graph API call (not writen by me)
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
#Get the Id from all the Main Level Groups with pagination
function GetAllGroupsId {
  param (   
  )
  $filter = "?`$select=id"
  $uri = "https://graph.microsoft.com/v1.0/groups$filter"
  $response = Get-GraphPagedResults -Uri $uri
  return $response.id
  <#
  try {
      $response = (Invoke-MgGraphRequest -Method Get -Uri $newUri -ErrorAction SilentlyContinue -StatusCodeVariable "status1").value
      return $response.id
  }
  catch {
      $false, "MAYDAY, Error details: $($_.Exception.Message)"
  }
  #>
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
function AllGroupMemberFromLowerGroups { 
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
function OneLevelGroups {
  param (
      $groupId,
      $level,
      $groupNumber
  )
#Get group info + add level, groupNumber, array nestedGroup and array childId
  $groupInfo = GroupInformation -groupInfo $groupId
  $groupInfo | Add-Member -MemberType NoteProperty -Name 'level' -Value $level
  $groupInfo | Add-Member -MemberType NoteProperty -Name 'groupNumber' -Value $groupNumber
  $groupInfo | Add-Member -MemberType NoteProperty -Name 'nestedGroup' -Value @()
  $groupInfo | Add-Member -MemberType NoteProperty -Name 'childId' -Value @()


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
#if there are subgroups
  elseif ($allLowerGroups.count -gt 0) {
    
    $level += 1
    $nextLevelGroups = NextLowerGroups -groupId $groupId
    MultiLevelGroup -nextGroupIds $nextLevelGroups -level $level -groupNumber $groupNumber  #controleren!!!!!!!!!!!!!!!!
    
  }
}
#basicly recalling the function OneLevelGroups
function MultiLevelGroup {
  param (
      $nextGroupIds,
      $level,
      $groupNumber
  )
  $nextGroupIds = @($nextGroupIds)
  foreach ($currentGroupId in $nextGroupIds) {
      OneLevelGroups -groupId $currentGroupId -level $level -groupNumber $groupNumber
#add child group to the current group
      $groupInfo.childId += $currentGroupId
  } 
}
#### Making nested json structure  ####
#preparations for nesting
function PrepareNesting {
    param (
        $bigBeautyFullList
    )
    $allGroups = @()
#sort the groups, that belong to the same tree !!!!!!!-Unique is needed otherwise you have a lot of dubbels!!!!!!!!!!
    $numbers = $bigBeautyFullList | Select-Object -ExpandProperty groupNumber -Unique
    foreach ($num in $numbers) {
        $groupTree = $bigBeautyFullList  | Where-Object { $_.groupNumber -eq $num } | Sort-Object level
        #$groupTree
#only one group, no further threatment       
        if ($groupTree.count -eq 1) {
            write-host "no nested groups"
            $allGroups += $groupTree
        }
#and now the nesting begins
        else {
            $nestedGroupTree = StartNesting -groupTree $groupTree
            $allGroups += $nestedGroupTree
        }  
    }
    $nestedGroupsJson = $allGroups | ConvertTo-Json -Depth $numbers.count
    return $nestedGroupsJson
}
#part 1 of nesting, begin with the beginning
function StartNesting {
    param (
        $groupTree
    )
# Start from level 0 (basixGroup) => normally it is already sorted so $groupTree[0] would work, you never know ...
    $basixGroup = $groupTree | Where-Object { $_.level -eq 0 }
#see part 2 of nesting
    $oneNestedGroup = BuildNestedGroup -group $basixGroup -allGroups $groupTree

# all the nesting happend in the main group, thats why we start at the beginning :-) + making an array of it
    $nestedGroups = @($oneNestedGroup| Where-Object { $_.level -eq 0 })
    return $nestedGroups
}
#part 2 of nesting, loop the child items again and again + adding it to the main group.nestedGroup
function BuildNestedGroup {
    param (
        $group,
        $allGroups
    )
# Loop the childId's from current Group
    foreach ($childId in $group.childId) {
# search the info from the child group
        $childGroup = $allGroups | Where-Object { $_.groupId -eq $childId }
#continue? yey or nay
        if ($childGroup) {
#the recursive part, did a better job then with bigbeautifulfullist 
            BuildNestedGroup -group $childGroup -allGroups $allGroups

# add child info to value nestedgroup
            $group.nestedGroup += $childGroup
        }
    }
    return $group
}

#---------------------------------------MAIN-------------------------
<# when already installed is possible the rest will not work! when not shure run this separately!!!!!!!!!!
#Install MS Graph if not available
if (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication) {
  Write-Host "Microsoft Graph Already Installed"
} 
else {
  try {
      Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery -Force 
  }
  catch [Exception] {
      $_.message 
  }
}
import-module microsoft.graph.authentication
#>
connect-mggraph -Scopes Group.Read.All, GroupMember.Read.All -noWelcome
#get all the main groups (level 0)
$allGroupIds =  GetAllGroupsId   
#Sort the group Id, 
$allSortedGroups = SortFromMainToSub -allGroupIds $allGroupIds

$bigBeautyFullList = @() #pleace, don't think of me less now
$Global:listToSkip = @() # skip list

#number is for identification if the nested groups belong together
$groupNumber = 1 
#start the Main loop
foreach ($currentId in $allSortedGroups) {
#skiplist, if group id in skip list, the group is already processed, so skip it
  if ($currentId -in $listToSkip) {
      continue
  }
#start level
  $level = 0 # gives each group a number represen the nesting level

#for every Main id an empty list
  $Global:listCurrentGroup = @()
  $currentGroup = OneLevelGroups -groupId $currentId -level $level -groupNumber $groupNumber #$currentGroup is to catch the output from the function
#look how big a nested group is + take the last part
  $bigBeautyFullList += $listCurrentGroup 
  $groupNumber += 1
}
#convert beautiful list to json
$json = PrepareNesting -bigBeautyFullList $bigBeautyFullList
$json | Out-File -FilePath "C:\temp\nestedGroups.json"

<#
write-host $json

#write the tree structure, you can add thing that are in the function: GroupInformation  
foreach ($item in $bigBeautyFullList) {
  $start = "| "
  write-host $start ( " - " * $item.Level ) $item.groupName # " - " $item.groupType or ....
}
#>
#disConnect-MgGraph
