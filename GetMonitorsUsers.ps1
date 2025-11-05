<#
.SYNOPSIS
!!CONTACT YOUR CHIEF INFORMATION OFFICER BEFORE USING THIS SCRIPT FOR GPDR or ...!!
It is one way to collect information about monitors.
GET monitor information from devices connected to Intune
and store it in Azure Blob Storage as JSON file.
This script is not made for a huge number of devices => use small groups +/- 20 devices!
@line 236 & 238 fill in the following: $blobUrl and $sasToken

.DESCRIPTION
!!CONTACT YOUR CHIEF INFORMATION OFFICER BEFORE USING THIS SCRIPT FOR GPDR or ...!!
At the moment there is no option in intune to collect monitor information from devices.
This script retrieves monitor information, current time, ip address and the name from the loggin user.
You can deploy the script via an intune remediation script for multiple runs or via script for a single run or ...
you also need to config an azure blob storage as json to store the information.

This script is not made for a huge number of devices => use small groups +/- 20 devices,
also don't run it for a long time.
Keep in mind the limits of blob storage!!
also the bigger it gets the slower it will be.

My preference go to log analytics,
but this depends on your subscription, choose what suits you best!
You can use follow tutorial => https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-portal
for this you need the first functio (function GetLocalData) and convert it to json format,
for the rest you can follow the tutorial.

the script only collect data
and store it in the cloud,
for analysing ... you can add code or download the data as a .csv file or ... 

Feedback is always welcome!

.EXAMPLE
=> .FORMAT

.INPUTS
nothing

.FORMAT
[
  {
    "name": "name1",
    "details": {
      "ipAdres": ???,
      "date": "2025-10-21",
      "screens": [
        {
          "screen name": "DELL P2422HE",
          "serial number": "serial1"
        },
        {
          "screen name": "DELL U2722DE",
          "serial number": "serial2"
        }
      ]
    }
  },
  {
    "name": "name2",   #=====> the script run 2 times for this user + the user device was connected to 2 different monitors
    "details": [
      {
        "ipAdres": ???,
        "date": "2025-10-22",
        "screens": [
          {
            "screen name": "DELL P2422HE",
            "serial number": "serial3"
          },
          {
            "screen name": "PHL 241B7Q",
            "serial number": "serial4"
          }
        ]
      },
      {
        "ipAdres": ???,
        "date": "2025-10-23",
        "screens": [
          {
            "screen name": "DELL P2422HE",
            "serial number": "serial5"
          },
          {
            "screen name": "DELL U2722DE",
            "serial number": "serial6"
          }
        ]
      }
    ]
  }
]

.NOTES
    Version:        1.0
    Author:         eggeto
    Creation Date:  2025-10-08
    Requirements:   
    - PowerShell: 
    - Microsoft Graph PowerShell SDK modules
#>

#Get the current monitor information from local device
function GetLocalData {
    param (
        
    )
    $allDisplays = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID

    $user = (Get-ItemProperty "HKCU:\\Software\\Microsoft\\Office\\Common\\UserInfo\\").UserName
    $ipAdres = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '169.*' -and $_.IPAddress -ne '127.0.0.1' }).IPAddress
    $currentDate = Get-Date -Format "yyyy-MM-dd"
    $listLocalMonitors = @()

    foreach ($display in $allDisplays) {
        $nameChars = $display.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }
        $serialChars = $display.SerialNumberID | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }

        $nameScreen = ($nameChars -join "").Trim()
        $serialNumber = ($serialChars -join "").Trim()
        
        if ($nameScreen -eq "" -or $serialScreen -eq "") {
            continue 
        }

        $screen = [pscustomobject]@{
            'screen name'       = $nameScreen
            'serial number'     = $serialNumber
        }
        $listLocalMonitors += $screen
    }

    $localInformation = [pscustomobject]@{
        ipAdres = $ipAdres
        date = $currentDate
        screens = $listLocalMonitors
    }
    #details must be a list
    $localInformationUser = [pscustomobject]@{
        name = $user
        details = @($localInformation)
    }
    Write-Host "local data is ok"
    return $localInformationUser
}
#get all the cloud data
Function GetCloudData {
    param (
        $sasToken,
        $blobUrl,
        $uri
    )
    try {
      $response = Invoke-WebRequest -Uri $uri -Method Get
      write-host "cloud data is downloaded"
    }
    catch {
      return $false, $($_.Exception.Message)
    } 
    $allCloudInformation = @($response.Content | ConvertFrom-Json)
    return $allCloudInformation
}
#add, comare and or update clouddata
Function CompareData {
    param (
        $localData,
        $cloudData
    )
#$cloudData must be an list otherwise you can't add new data
    if (-not ($cloudData -is [System.Collections.IList])) {
        $cloudData = @($cloudData)
    }
#if the user is new, add it
    if ($localData.name -notin $cloudData.name){
        $cloudData += $localData
        return $cloudData
    }
#else check if the monitor is new and update the $cloudData
    #get the right user
    foreach ($cloudUser in $cloudData) {
        if ($cloudUser.name -eq $localData.name) {
            $addOk = $false
            #primaire loop details
            foreach ($detail in $cloudUser.details) {
                #secondaire loop screens
                foreach ($screen in $localData.details.screens) {
                    if ($screen -notin $detail.screens) {
                        $addOk = $true
                        break
                    }
                }
                if ($addOk) { break }
            }
            if ($addOk) {
                #update the details if the are new screens
                $cloudUser.details += $localData.details
            }
        }
    }
    write-host "cloudData is updated"
    return $cloudData
}
#updating the data in the cloud
function postUpdatedCloudData {
    param (
        $updatedCloudData,
        $sasToken,
        $blobUrl,
        $uri
    )
    #convert back to json
    $updatedJson = $updatedCloudData | ConvertTo-Json -Depth 5
    # Convert to byte array
    $newJson = [System.Text.Encoding]::UTF8.GetBytes($updatedJson)
    
    #sleeptime is needed otherwise it start nesting with other updates, i think this is because uodates are updated the same time!!!
    $sleepTime = Get-Random -Minimum 1 -Maximum 100
    start-sleep -seconds $sleepTime

    #Upload updated JSON back to Azure Blob (overwrite)
    try {
    Invoke-RestMethod -Uri $uri -Method Put -Body $newJson -Headers @{
        "x-ms-blob-type" = "BlockBlob"
        "Content-Type"   = "application/json"
    }
        return "blob storage is updated"
    }
    catch {
        return $($_.Exception.Message)
    }
}
#Main function
function Main {
    param (
    )
    $blobUrl = "YOUR BLOB LINK HERE"
    #verloopt op 14/08/2026
    $sasToken = "YOUR SAS TOKEN FROM THE BLOB STORAFE HERE"
    $uri = $blobUrl + "?" + $sasToken
    #Get local info
    $userInformation = GetLocalData

    if ($userinformation.details.screens.count -eq 0) {
        write-host "No monitors detected, exiting script."
        return
    }
    #get all the cloud info
    $allcloudInformation = GetCloudData -sasToken $sasToken -blobUrl $blobUrl -uri $uri 
    #add or compare and update the local info with the cloud info
    $updatedCloudData = CompareData -localData $userInformation -cloudData $allCloudInformation
    #update the blob storage
    postUpdatedCloudData -updatedCloudData $updatedCloudData -sasToken $sasToken -blobUrl $blobUrl -uri $uri
}
main
