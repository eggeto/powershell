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
- windowsVersion
(- skuFamily)
(- skuNumber)

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

when a device is intune joined, the license will become an enterprise license. Even when it is an pro license!

.NOTES
    Version:        1
    Author:         eggeto
    Creation Date:  2025-07-30
    Requirements:   
    - PowerShell: 
    - Microsoft Graph PowerShell SDK modules
#>

#paginated Graph API call => not my function
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
#Get all devices in Intune
function AllDevices {
    param (
    )
    $filter = "?`$select=id,deviceName,emailAddress"
    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices$filter"
    $response = Get-GraphPagedResults -Uri $uri
    return $response
    <#
    try {
         #(Invoke-MgGraphRequest -uri $nextlink -Method Get -OutputType PSObject).value
        return $response
    }
    catch {
        return $($_.Exception.Message)
    }
    #>
}
#add windows verion info to pstable
function GetWindowsInfo {
    param (
    )
    $allDevices = AllDevices
    $allWindowsDeviceInfo = @()
    foreach ($device in $allDevices) {
        $intuneId = $device.id
        $filterSku = "?`$select=skuFamily,skuNumber"
        $uriSku = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$intuneId$filterSku"
        try {
            $responseSku = (Invoke-MgGraphRequest -uri $uriSku -Method Get -OutputType PSObject)

        $skuNumber = $responseSku.skuNumber
        $windows = switch ($skuNumber) {
                4 { "Windows Pro 10/11" }
                27 { "Windows 10/11 Enterprise N" }
                48 { "Windows Enterprise" }
                98 { "Windows Education" }
                100 { "Windows Home" }
                101 { "Windows Home N" }
                121 { "Windows Pro Education" }
                119 { "Windows Pro for Workstations" }
                125 { "Windows 10 IoT Enterprise 2019 LTSC" }
                175 { "Windows 10/11 Enterprise Multi-session"} #mostly AVD
                191 { "Windows 10 IoT Enterprise 2021 LTSC" }
                205 { "Windows 11 IoT Enterprise 2021 LTSC" }
                206 { "Windows 11 IoT Enterprise GAC" }
                133 { "Windows SE" }
                default { "Unknown SKU: $skuNumber" }
            }
            $deviceInfo = [pscustomobject]@{
                intuneId = $intuneId
                deviceName = $device.deviceName
                emailAddress = $device.emailAddress
                windowsVersion = $windows
            }
            $allWindowsDeviceInfo += $deviceInfo
        }
        catch {
            continue
        }
    }
    $allWindowsDeviceInfo = $allWindowsDeviceInfo | sort-object -Property windowsVersion 
    return $allWindowsDeviceInfo
}
Connect-MgGraph

GetWindowsInfo

disConnect-MgGraph
