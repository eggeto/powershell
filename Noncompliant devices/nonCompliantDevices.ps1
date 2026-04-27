<#
.SYNOPSIS
Get all the Not Compliant devices with info sorted per device

.INPUTS
Optional blacklist => $blacklist
you can add par example all AVD devices or ...

.OUTPUTS
=> in terminal
deviceName      userName                      policyName                        subPolicyName
----------      --------                      ----------                        -------------
  ...              ...                           ...                                 ...   

=> in the browser
simular output, but you can sort the columns and there is a search bar
the HTML is also written away to/as: C:\Temp\Non-Compliance-Devices.html

.LOG
added HTML output: 23/04/2026

.EXAMPLE
GetCompliancesDetailsPerDevice -blacklist $blackList

.NOTES
  Version:        1.1
  Author:         Eggeto
  Creation Date:  25/11/2024
  Update script:  23/04/2026
  Requirements:   
  - PowerShell: 
  - Microsoft Graph PowerShell SDK modules
#>
#paginated Graph API call for intune devices
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
#Get all the non compliance devices
function GetAllNonComplianceDevices {
  param (
  )
  $filter = "?`$filter=complianceState eq 'nonCompliant' and managedDeviceOwnerType eq 'company'"
  $filter2 = "&`$select=id,userPrincipalName,deviceName,userDisplayName"
  $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices$filter$filter2"
  try {
    $response = Get-GraphPagedResults -Uri $uri
  }
  catch {
    return "MAYDAY, Error details: $($_.Exception.Message)"  
  }
  $listNonComplianceDevices = [System.Collections.Generic.List[object]]::new()
  foreach ($device in $response){
    $noCompliance = [PSCustomObject]@{
      intuneId = $device.ID
      userDisplayName = $device.userDisplayName
      deviceName = $device.deviceName
      userPrincipalName = $device.userPrincipalName
    }
    $listNonComplianceDevices.add($noCompliance) 
  }
  return $listNonComplianceDevices
}
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
    return "MAYDAY, first loop Error details: $($_.Exception.Message)"  
  }
  $listMainLoop = @()
  foreach ($mainPolicy in $responseMain) {
    $complianceState = $mainPolicy.state
    if ($complianceState -ne "compliant") { 
      $policyId = $mainPolicy.id
      $policyName = $mainPolicy.displayName
      $listSecondLoop = FilterComplianceSecond -intuneId $intuneId -policyId $policyId -deviceName $deviceName -policyName $policyName
      $listMainLoop += $listSecondLoop #return listsecondloop is also good
    }
  }
  return $listMainLoop
}
#second loop checking the compliance state per Sub policy
function FilterComplianceSecond {
  param (
  $intuneId,  
  $policyId,
  $deviceName,
  $policyName
  )
  #$filter = "?`$select=id,state,setting"
  $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$intuneId/deviceCompliancePolicyStates/$policyId/settingStates"
  try {
    $responseSecond = (Invoke-MgGraphRequest -Method Get -Uri $uri).value
  }
  catch {
    return "MAYDAY, second loop Error details: $($_.Exception.Message)"
  }
  $listSecondLoop = @()
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
      $listSecondLoop += $collectNonComplianceSecond
    }
  }
  return $listSecondLoop
}
#Get compliance information
function GetCompliancesDetailsPerDevice {
  param (
    $allNonComplianceDevices,
    $blacklist
  )
#Get all the devices that are not compliant
  $allNonComplianceDevices = GetAllNonComplianceDevices
#loop all non compliance devices for non compliance policy
  $listNonCompliancePerDevice = @()
  foreach ($device in $allNonComplianceDevices) {
    $intuneId = $device.intuneId
    $userDisplayName = $device.userDisplayName
    $deviceName = $device.deviceName

#Blacklist for devices
    if ($deviceName -like $Global:blackList){
      continue
    }
#Get all the Not Complaint information per device
    $firstLoop = FilterComplianceMain -intuneId $intuneId -deviceName $deviceName -userDisplayName $userDisplayName
      $listNonCompliancePerDevice += $firstloop
      #Start-Sleep -Seconds 1 #was needed else Graph is overloaded
  }
  return $listNonCompliancePerDevice
}  

#blacklist via deviceName
$Global:blackList = @(
  "*avd*" #azure virtual desktop as example
  #"deviceName",
  #...
)
Connect-MgGraph -Scopes Device.Read.All, DeviceManagementConfiguration.Read.All
$getAllCompliance = GetCompliancesDetailsPerDevice | Select-Object * -Unique |Sort-Object deviceName,policyName

#write in terminal
$getAllCompliance

###############  HTML part  ###############
$header = @'
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/jquery.dataTables.min.css">
<script src="https://code.jquery.com/jquery-3.7.0.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>

<style>
body {
    font-family: Segoe UI;
    background:#f8f9fa;
    padding:40px;
}
.container{
    background:white;
    padding:25px;
    border-radius:10px;
    box-shadow:0 4px 15px rgba(0,0,0,.08);
}
h2{
    color:#0078d4;
}
table.dataTable {
    width:100% !important;
}
</style>

<script>
$(document).ready(function () {
    $('#complianceTable').DataTable({
        pageLength: 30,
        autoWidth: false,
        searching: true,
        columnDefs: [
            { targets: [0,1,2,3], searchable: true }
        ],
        language: {
            search: "search:",
            lengthMenu: "_MENU_ rows per page",
            info: "Show _START_ to _END_ from _TOTAL_ devices",
            paginate: {
                next: "next",
                previous: "previous"
            }
        }
    });
});
</script>
'@

#Generate HTML tables
$tableHtml = $getAllCompliance | ConvertTo-Html -Fragment

#The structure of the html tables
$tableHtml = $tableHtml `
-replace '<table>', '<table id="complianceTable" class="display">' `
-replace '<tr><th>', '<thead><tr><th>' `
-replace '</th></tr>', '</th></tr></thead><tbody>' `
-replace '</table>', '</tbody></table>'

#The HTML Page
$FullHtml = @"
<!DOCTYPE html>
<html lang='nl'>
<head>
<meta charset='UTF-8'>
$header
</head>
<body>
<div class='container'>
<h2>Non-Compliance Devices</h2>
$tableHtml
</div>
</body>
</html>
"@

$Path = "C:\Temp\Non-Compliance-Devices.html"
$FullHtml | Out-File $Path -Encoding utf8
Invoke-Item $Path

#DisConnect-MgGraph
