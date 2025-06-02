<# 
    .SYNOPSIS
    Get the Company devices from users with more then 1 device

    .DESCRIPTION
    For this script, you need to install the powershell mgraph module.
    It is made for detecting users with more then 1 Company Device(s)!
    You can modify the script, for example more then 3 company devices or Personal devices or ...

    .INPUTS
    user principal name or email

    .OUTPUTS
    The output is an psobject contain the user and the device names in a list
    you can modify this also to an array or ...

    Made by Eggeto
#>

Connect-MgGraph -Scopes User.Read.All
function IsCompanyDevice {
    param (
        $response    
    )
    $listCompanyOwnedDevices = @()
    $listPersonalOwnedDevices = @()
    foreach ($device in $response) {
        if($device.managedDeviceOwnerType -contains "company"){
            $listCompanyOwnedDevices += $device
        }
        else {
            $listPersonalOwnedDevices += $device
        }
    }  
    return $listCompanyOwnedDevices  
}

function CountCompanyDevices { #i want every one with mor then 1 device
    param (
        $upn
    )
    $uri = "https://graph.microsoft.com/v1.0/users/$upn/managedDevices"
    try {
        $response = (Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction SilentlyContinue -StatusCodeVariable "status1").value
    }
    catch {
        Write-Host "MAYDAY for $upn"
        return "Error details: $($_.Exception.Message)"  
    }
    $response = @($response)
    #$arrayCompanyOwnedDevices = @{}
    $companyOwnedDevices = IsCompanyDevice -response $response
    $count = $companyOwnedDevices.count

    if($count -gt 1){ #change this to whatever you want
        $resultCompanyOwnedDevices = [PSCustomObject]@{
            Name = $upn
            Devices = $companyOwnedDevices.deviceName
        }
        return $resultCompanyOwnedDevices
        #return $upn, $companyOwnedDevices.deviceName 
        #or
        #$arrayCompanyOwnedDevices[$upn] = $companyOwnedDevices.deviceName
        #return $arrayCompanyOwnedDevices
    }
    else {
        write-host "$upn has 1 or null device"
        return $null
    } 
}

CountCompanyDevices -upn #<the email or UPN from 1 user or if you can add a loop>

DisConnect-MgGraph
