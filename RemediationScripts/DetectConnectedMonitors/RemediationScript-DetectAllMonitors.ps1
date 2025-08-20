function Main {
    param (
    )
    #Detection Type Screen + Serial Number
    $allDisplays = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID

    $user = (Get-ItemProperty "HKCU:\\Software\\Microsoft\\Office\\Common\\UserInfo\\").UserName
    $ipAdres = $env:HostIP
    $currentDate = Get-Date -Format "yyyy-MM-dd"

    $listLocalMonitors = @()
    foreach ($display in $allDisplays) {

    $nameChars = $display.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }
    $serialChars = $display.SerialNumberID | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }

    $nameScreen = ($nameChars -join "").Trim()
    $serialScreen = ($serialChars -join "").Trim()
    
    if ($nameScreen -eq "" -or $serialScreen -eq "") {
        continue 
    }
    $screens = [pscustomobject]@{
        nameScreen = $nameScreen
        serialScreen = $serialScreen 
        date = $currentDate
    }
    $listLocalMonitors += $screens
    }

    $localInformation = [pscustomobject]@{
        ipAdres = $ipAdres
        screens = $listLocalMonitors
    }

    $localInformationUser = [pscustomobject]@{
        name = $user
        details = $localInformation
    }

    $blobUrl = "YOUR BLOB URL"
    #verloopt op 14/08/2026
    $sasToken = "YOUR SAS KEY"
    #update json
    UpdateJson -sasToken $sasToken -blobUrl $blobUrl -updateLocalMonitors $localInformationUser
}

function UpdateJson {
    param (
        $sasToken,
        $blobUrl,
        $updateLocalMonitors
    )
    $uri = $blobUrl + "?" + $sasToken
    try {
      $response = Invoke-WebRequest -Uri $uri -Method Get
    }
    catch {
      return $false, $($_.Exception.Message)
    } 
    $allCloudInformation = @($response.Content | ConvertFrom-Json) 
    write-host $allCloudInformation

# add new user
    if ($updateLocalMonitors.name -notin $allCloudInformation.name){
        $allCloudInformation += $updateLocalMonitors
    }
# update excisting user
    elseif ($updateLocalMonitors.name -in $allCloudInformation.name) {
        #$newScreen = @{nameScreen = "NEW SCREEN"; serialScreen = "XYZ123"}
        foreach ($cloudInfo in $allCloudInformation) {
            if ($cloudInfo.name -eq $updateLocalMonitors.name) {
                foreach ($localScreen in $updateLocalMonitors.details.screens){
                    #$newScreen = @{}
                    if ($localScreen -notin $cloudInfo.details.screens) {
                        $cloudInfo.details.screens += $localScreen
                    }
                }
                #$cloudInfo.details.screens += $newScreen                   
            }
        }
    }

    #convert back to json
    $updatedJson = $allCloudInformation | ConvertTo-Json -Depth 5
    # Convert to byte array
    $newJson = [System.Text.Encoding]::UTF8.GetBytes($updatedJson)

    #Upload updated JSON back to Azure Blob (overwrite)
    try {
    Invoke-RestMethod -Uri $uri -Method Put -Body $newJson -Headers @{
        "x-ms-blob-type" = "BlockBlob"
        "Content-Type"   = "application/json"
    }
    return $true
    }
    catch {
    return $false, $($_.Exception.Message)
    }
}
main