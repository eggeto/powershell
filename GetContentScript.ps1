#Get all scripts + content from intune scripts (not remediations!!!)
#https://www.linkedin.com/pulse/cant-see-content-your-intune-platform-script-problem-isnt-t%C3%BCrkoglu-khbzf/

#optie om alle scripts up te louden naar een siem server voor als er veranderingen gebeuren aan het script, helaas kunnen we niet zien door welke persoon! (momenteel)

function GetInfoScript {
    param (
        $info
    )
    $scriptId = $info.id
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$scriptId"
    
    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
    }
    catch {
        return "Can't find the script: $($_.Exception.Message)" 
    }

#decode base64 content
    $decode = $response.scriptContent
    $bytes  = [System.Convert]::FromBase64String($decode)
    $text   = [System.Text.Encoding]::UTF8.GetString($bytes)

    return $text
}

function main {
    param (
    )
#Get all scripts info
    $filter = "?`$select=id,displayName,description,fileName"    
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts$filter"

    try {
        $response = (Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject).value
    }
    catch {
        return "No scripts found $($_.Exception.Message)" 
    }
    
    write-host "All available scripts names" -ForegroundColor Green
    write-host ($response.displayName -join ' - ') -ForegroundColor Cyan
    write-host ""

    $input = Read-Host "Type the script name, you want to see the content from:"
    write-host ""
    
    foreach ($item in $response) {
        if ($item.displayName -eq $input) {
            $scriptName = $item.displayName
            $scriptDescription = $item.description
#get content from script
            $getInfo = GetInfoScript -info $item
# write script to file
            $getInfo | Out-File -FilePath "C:\Powershell\$scriptName.ps1"
#write out
            Write-Host "the name is: $scriptName" 
            Write-Host "with description: $scriptDescription"
            Write-Host "the content script is: $getInfo"
        }
    }    
}

Connect-MgGraph -Scopes DeviceManagementScripts.Read.All

main

#disConnect-MgGraph
