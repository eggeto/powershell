<#
.SYNOPSIS
Get all the Not Compliant devices with info sorted per device

.INPUTS
Optional blacklist => $blacklist

.OUTPUTS
devicename with the follow:
  Username => system account or User Principal Name,
  Device Name
  Main non compliant policy name,
  Sub non complaint policy name

.Auther
Eggeto
  
logs:
25/11/2024 => made scipt 
23/06/2025 => Modify functions for readability, added blacklist option

To do
better naming
blacklist => add a group with devices instead of a list
...
on going
#>
#Get all the non compliance devices
function GetAllNonComplianceDevices {
  param (
  )
  $filter = "?`$filter=complianceState eq 'nonCompliant' and managedDeviceOwnerType eq 'company'"
  $filter2 = "&`$select=id,userPrincipalName,deviceName, userDisplayName"
  $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices$filter$filter2"
  try {
    $response = (Invoke-MgGraphRequest -Method GET -Uri $uri).value
  }
  catch {
    return "MAYDAY, Error details: $($_.Exception.Message)"  
  }
  $listNonComplianceDevices = @()
  foreach ($device in $response){
    $noCompliance = [PSCustomObject]@{
      intuneId = $device.ID
      userDisplayName = $device.userDisplayName
      deviceName = $device.deviceName
      userPrincipalName = $device.userPrincipalName
    }
    $listNonComplianceDevices += $noCompliance
  }
  return $listNonComplianceDevices
}
#blacklist via deviceName
$blackList = @(
  #"device1"
  #"device2",
  #...
)
#first loop checking the compliance state per MAIN policy
function FilterComplianceMain {
  param (
    $intuneId,
    $deviceName,
    $userDisplayName
  )
  $filter = "?`$select=id,state,displayName"
  $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$intuneId/deviceCompliancePolicyStates$filter"
  try {
    $responseMain = (Invoke-MgGraphRequest -Method GET -Uri $uri).value
  }
  catch {
    return "MAYDAY, Error details: $($_.Exception.Message)"  
  }
  foreach ($mainPolicy in $responseMain) {
    $complianceState = $mainPolicy.state
    if ($complianceState -ne "compliant") { 
      $policyId = $mainPolicy.id
      $policyName = $mainPolicy.displayName
      $listSecondloop = FilterComplianceSecond -intuneId $intuneId -policyId $policyId -deviceName $deviceName -policyName -$policyName
    }
  }
  return $listSecondloop
}
#second loop checking the compliance state per Sub policy
function FilterComplianceSecond {
  param (
  $intuneId,  
  $policyId,
  $deviceName,
  $policyName
  )
  #$filter = ""
  $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$intuneId/deviceCompliancePolicyStates/$policyid/settingStates"
  try {
    $responseSecond = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
  }
  catch {
    return "MAYDAY, Error details: $($_.Exception.Message)"
  }
  $listSecond = @()
  foreach ($subPolicy in $responseSecond){
    $complianceStateSubPolicy = $subPolicy.state
    if ($compliancestatesubpolicy -ne "compliant"){
      $PolicyNameSecond = $subPolicy.setting.Split(".")
      $collectNonComplianceSecond = [PSCustomObject]@{
        deviceName = $deviceName
        userName = $subPolicy.userPrincipalName
        policyName = $PolicyName
        subPolicyName = $PolicyNamesecond[-1]
      }
      $listSecond += $collectNonComplianceSecond
    }
  }
  return  $listSecond
}
#Get compliance information
function GetCompliancesDetailsPerDevice {
  param (
    $allNonComplianceDevices,
    $blacklist
  )
  $allNonComplianceDevices = GetAllNonComplianceDevices
  #loop all non compliance devices for non compliance policy
  $listNonCompliancePerDevice = @()
  foreach ($device in $allNonComplianceDevices) {
    $intuneId = $device.intuneId
    $userDisplayName = $device.userDisplayName
    $deviceName = $device.deviceName

    #Blacklist for devices
    if ($deviceName -like $blackList){
      break
    }
    #Get all the Not Complaint information per device
    $firstLoop = FilterComplianceMain -intuneId $intuneId -deviceName $deviceName -userDisplayName $userDisplayName

    $listNonCompliancePerDevice += $firstloop
    Start-Sleep -Seconds 1 #is needed else Graph is overloaded when there are more then 10 devices
  }
  return $listNonCompliancePerDevice
}  

Connect-MgGraph

$showNonCompliance = GetCompliancesDetailsPerDevice -blacklist $blackList
$showNonCompliance
DisConnect-MgGraph
