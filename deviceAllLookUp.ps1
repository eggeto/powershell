<#
Version 1.1
look up device information by devicename or device ID or AAD device ID or email adres (UPN) from user

need to fix the follow:
if a user have more devices it will only take the first 
add option if you know what kind of filter you want to use 
error when input is aad device id > give warning

"?`$filter=userPrincipalName eq '$userPrincipalName"

log:
added de option "addToFilterSelect" for faster searching via graph api,
remember to modify the pscustomobject if you use it!!!!
#>

Connect-MgGraph

function DeviceAllLookUp {
    param (
        $information,
        $chooseFilter,
        $addToFilterSelect
    )
    $addFilter = ""
    $addToFilterSelect = ""
    #id,deviceName,serialNumber,model ...

    $addSelect = "&`$select=$addToFilterSelect"
    $filterUpn = "?`$filter=userPrincipalName eq '$information'"
    $filterDeviceName = "?`$filter=deviceName eq '$information'"
    $pattern = "^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$"

    if ($information.Contains("@")){
        $addFilter = $filterUpn
    }
    elseif ($information -match $pattern) {
        $addFilter = $information 
    }
    else {
        $addFilter = $filterDeviceName
    }

    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
    $uriFilter = "$uri/$addFilter$addSelect"

    $responseDevice = (Invoke-MgGraphRequest -Method GET -uri $uriFilter).value 

    [PSCustomObject][ordered]@{
        intuneDeviceId      = $responseDevice.Id
        azureAdDeviceId     = $responseDevice.azureAdDeviceId
        deviceName          = $responseDevice.deviceName 
        userEmail           = $responseDevice.UserPrincipalName 
        #add what you need certainly if you use the option $addSelect
    }
}

$information = read-host "Enter DeviceName, DeviceId or UserPrincipalName"
$test = DeviceAllLookUp -information $information
$test.deviceName
$test.userEmail
$test.intuneDeviceId
$test.azureAdDeviceId

disconnect-mggraph
