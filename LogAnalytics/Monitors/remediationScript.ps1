

function GetMonitorInfo {
    param (
        
    )
    $allDisplays = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID

    $user = (Get-ItemProperty "HKCU:\\Software\\Microsoft\\Office\\Common\\UserInfo\\").UserName
    $ipAdres = (Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null}).IPv4Address.IPAddress #issue if there are multiple ip addresses
    $currentDate = Get-Date -Format "yyyy-MM-dd"

    $userMonitor = foreach ($display in $allDisplays) {
        $nameChars = $display.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }
        $serialChars = $display.SerialNumberID | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }

        $nameScreen = ($nameChars -join "").Trim()
        $serialNumber = ($serialChars -join "").Trim()

        [pscustomobject]@{
            "TimeGenerated" = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            "user"          = $user
            "currentDate"  = $currentDate
            "screenName"   = $nameScreen
            "serialNumber" = $serialNumber
            "computerName" = $env:COMPUTERNAME
            "ipAdres"       = $ipAdres
        }
    }
    return $userMonitor
}

function CreateToken {
    param (
        $tenantId,
        $appId,
        $appSecret
    )
    $scope = [System.Web.HttpUtility]::UrlEncode("https://monitor.azure.com//.default")   
    $body = "client_id=$appId&scope=$scope&client_secret=$appSecret&grant_type=client_credentials";
    $headers = @{"Content-Type" = "application/x-www-form-urlencoded" };
    $uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    try {
        $bearerToken = (Invoke-RestMethod -Uri $uri -Method "Post" -Body $body -Headers $headers).access_token
        write-host "token is ok"
        return $bearerToken
    }
    catch {
        write-host "error token"
        return $false
    }
}

function PostToLogAnalytics {
    param (
        $bearerToken,
        $dceURI,
        $dcrImmutableId,
        $table,
        $body
    )
    $headers = @{"Authorization" = "Bearer $bearerToken"; "Content-Type" = "application/json" };
    $uri = "$dceURI/dataCollectionRules/$dcrImmutableId/streams/Custom-$table"+"?api-version=2023-01-01";
    try {
        $uploadResponse = Invoke-RestMethod -Uri $uri -Method "Post" -body $body -Headers $headers;
        write-host "info is pushed to log analytics"
    }
    catch {
        write-host "error"
        $statusCode = $_.Exception.Response.StatusCode.value__
        $statusDesc = $_.Exception.Response.StatusDescription

        #Response stream manueel uitlezen
        $responseStream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($responseStream)
        $errorBody = $reader.ReadToEnd()
        $reader.Close()

        Write-Host "Status code  : $statusCode"
        Write-Host "Omschrijving : $statusDesc"
        Write-Host "Azure melding: $errorBody"
    }
}

$variables = @{
    tenantId        = ""   # Entra ID Tenant ID
    appId           = ""   # App Registration Client ID
    appSecret       = ""   # App Registration Client Secret
    dcrImmutableId  = ""   # DCR Immutable ID (dcr-xxx)
    dceURI          = ""   # DCE URI (https://xxx.ingest.monitor.azure.com)
    table           = "MonitorLogAnalitics_CL" #"custom-" and "_CL" is added automaticly by azure or in the post function!!!! nevermind the typo :-)
}

Add-Type -AssemblyName System.Web
$userMonitor = GetMonitorInfo
$body = $userMonitor | ConvertTo-Json #-AsArray #=> if you use powershell 7
$body | out-file c:\temp\MonitorInventory.json # you need this for making the table in azure Log Analytics

$bearerToken = CreateToken -appId $variables.appId -tenantId $variables.tenantId -appSecret $variables.appSecret
if ($bearerToken){
    PostToLogAnalytics -bearerToken $bearerToken -dceURI $variables.dceURI -dcrImmutableId $variables.dcrImmutableId -table $variables.table -body $body
}
                                    
                                  
