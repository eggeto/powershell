<#
.SYNOPSIS
Get laps password from a device

.DESCRIPTION
Get laps password from a device
add the user email or device name in line 84-85

.INPUTS
the mail adres from a user
the intune device name from a device

.OUTPUTS
the LAPS password is: $password for user: $user
also functio: GetLapsPasswordUser returns the password

.Example

.MODULE
Microsoft.Graph.Authentication

.MADE
Eggeto

log:
12/11/2025
made script

TO DO:
auto input detection (user or device)
#>
#Get Azure AD Device ID from user
function GetAzureAdDeviceId {
    param (
        $upn
    )
    $filter = "?`$select=azureADDeviceId,emailAddress&`$filter=emailAddress eq '$upn'"
    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices$filter"
    try {
        $responseId = (invoke-mggraphrequest -Method GET -Uri $uri).value
        write-host "Azure AD Device ID retrieved"
        return $responseId.azureADDeviceId
    }
    catch {
        return "MAYDAY, failed retrive azure device id: $($_.Exception.Message)"
    }
}
#Get Azure AD Device id from device
function GetAzureIdFromDevice {
    param (
        $deviceName
    )
    $filter = "?`$select=azureADDeviceId,deviceName&`$filter=deviceName eq '$deviceName'"
    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices$filter"
    try {
        $responseId = (invoke-mggraphrequest -Method GET -Uri $uri).value
        write-host "Azure AD Device ID retrieved"
        return $responseId.azureADDeviceId
    }
    catch {
        return "MAYDAY, failed retrive azure device id: $($_.Exception.Message)"
    }
}
#Get LAPS password from user
function GetLapsPasswordUser {
    param (
        $azureId
    )
    $filter = "?`$select=credentials"
    $uri = "https://graph.microsoft.com/beta/directory/deviceLocalCredentials/$azureId$filter"
    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        write-host "password retrieved"
    }
    catch {
        return "MAYDAY, failed retrive password: $($_.Exception.Message)" 
    }
#convert base64 to clear text
    $password = [system.text.encoding]::UTF8.GetString([System.Convert]::FromBase64String($response.credentials[0].passwordBase64))
    write-host "the LAPS password is: $password for user: $user"
    Return $password
}

Connect-Mggraph -Scope DeviceLocalCredential.Read.All, Device.Read.All, User.Read.All

$user = "USER EMAIL ADRES"
#$device = "DEVICE NAME DISPLAYNAME INTUNE"

$azureId = GetAzureAdDeviceId -upn $user
#or $azureId = GetAzureIdFromDevice -deviceName $device
GetLapsPasswordUser -azureId $azureId

#disConnect-Mggraph
