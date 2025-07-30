<#
.SYNOPSIS
show all Windows devices in Intune with their SKU information

.DESCRIPTION
show all Windows devices in Intune with their SKU information

.INPUTS
none

.OUTPUTS
sorted array of PSObjects with the following properties:
- intuneId
- deviceName
- emailAddress
- skuFamily
- skuNumber

skuNumber legend:
4	Windows Pro	=> Win 10 & 11
48	Windows Enterprise	=>  Win 10 & 11
98	Windows Education
100	Windows Home => Win  10 & 11
101	Windows Home N	=> N = no media features
121	Windows Pro Education
119	Windows Pro for Workstations
125	Windows 10 IoT Enterprise 2019 LTSC	IoT edition
191	Windows 10 IoT Enterprise 2021 LTSC	IoT edition
205	Windows 11 IoT Enterprise 2021 LTSC	Newer IoT edition
206	Windows 11 IoT Enterprise GAC	Government/China variant
133	Windows SE	=> Lightweight Windows 11 for education / Surface Laptop

.NOTES
    Version:        Beta
    Author:         eggeto
    Creation Date:  2025-07-30
    Requirements:   
    - PowerShell: 
    - Microsoft Graph PowerShell SDK modules
#>


#Connect-MgGraph
$allWindowsDeviceInfo = @()
$filter = "?`$select=id,deviceName,emailAddress"
$uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices$filter"

try {
    $response = (Invoke-MgGraphRequest -uri $uri -Method Get -OutputType PSObject).value
}
catch {
    
}
foreach ($device in $response) {
    $intuneId = $device.id
    $filterSku = "?`$select=skuFamily,skuNumber"
    $uriSku = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$intuneId$filterSku"
    try {
        $responseSku = (Invoke-MgGraphRequest -uri $uriSku -Method Get -OutputType PSObject)
        $deviceInfo = [pscustomobject]@{
            intuneId = $intuneId
            deviceName = $device.deviceName
            emailAddress = $device.emailAddress
            skuFamily = $responseSku.skuFamily
            skuNumber = $responseSku.skuNumber
        }
        $allWindowsDeviceInfo += $deviceInfo
    }
    catch {
        continue
    }
}
$allWindowsDeviceInfo = $allWindowsDeviceInfo | sort-object -Property skuFamily, skuNumber, deviceName

$allWindowsDeviceInfo



#disConnect-MgGraph