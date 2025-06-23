<#
.SYNOPSIS
Get all the Not Compliant devices with info

.INPUTS
optional blacklist => 

.OUTPUTS
devicename with non compliant policy

.Auther
Made by Eggeto
  
logs:
25/11/2024 => made scipt 
23/06/2025 => Modify functions for readability, added blacklist option

To do
different between system account and user account!!!!
better naming
blacklist =< add a group with devices
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
  #device1,
  #device2,
  #...
)
#first loop checking the compliance state per MAIN policy
function FilterComplianceMain {
  param (
    $intuneId
  )
  $filter = "?`$select=id,state,displayName"
  $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$intuneId/deviceCompliancePolicyStates$filter"
  try {
    $responseMain = (Invoke-MgGraphRequest -Method GET -Uri $uri).value
  }
  catch {
    return "MAYDAY, Error details: $($_.Exception.Message)"  
  }
  $list = @()
  foreach ($mainCompliance in $responseMain) {
    $complianceState = $mainCompliance.state
    $policyId = $mainCompliance.id
    if ($complianceState -ne "compliant") { 
      $secondloop = FilterComplianceSecond -intuneId $intuneId -policyId $policyId
      $list += $secondloop
    }
  }
  return $list
}
#second loop checking the compliance state per Sub policy
function FilterComplianceSecond {
  param (
  $intuneId,  
  $policyId
  )
  $uriMP = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$intuneId/deviceCompliancePolicyStates/$policyid/settingStates"
  try {
    $responseSecond = (Invoke-MgGraphRequest -Uri $uriMP -Method Get -OutputType PSObject).value
    $responseSecond = @($responseSecond)
  }
  catch {
    return "MAYDAY, Error details: $($_.Exception.Message)"
  }
  $noComplianceState = @()
  foreach ($subPolicy in $responseSecond){
    $complianceStateSubPolicy = $subPolicy.state
    if ($compliancestatesubpolicy -ne "compliant"){
      $PolicyName = $subPolicy.setting.Split(".")
      $collectNonCompliance = [PSCustomObject]@{
        userName1 = $subPolicy.userPrincipalName
        #UsernameDevice = $userDisplayName
        policyName = $PolicyName[0]
        policySubName = $PolicyName[-1]
        #intuneID = $intuneId
      }
      $noComplianceState += $collectNonCompliance
    }
  }
  return $noComplianceState
}
#Get compliance information
function GetCompliancesDetailsPerDevice {
  param (
    $allNonComplianceDevices,
    $blacklist
  )
  $allNonComplianceDevices = GetAllNonComplianceDevices
  #loop all non compliance devices for non compliance policy
  $listNonComplianceState = @()
  foreach ($device in $allNonComplianceDevices) {
    $intuneId = $device.intuneId
    #$userDisplayName = $device.userDisplayName
    $deviceName = $device.deviceName

    #Blacklist for devices
    if ($deviceName -contains $blackList){
      write-host "Device is in the blacklist"
      break
    }
    #Get all the Not Complaint information per device
    $firstLoop = FilterComplianceMain -intuneId $intuneId
    $listNonComplianceState += $deviceName, $firstLoop

  }
  return $listNonComplianceState
}  
#Connect-MgGraph
#

$test = GetCompliancesDetailsPerDevice
$test
#DisConnect-MgGraph