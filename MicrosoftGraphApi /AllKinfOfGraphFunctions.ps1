<#


log:
made on 30/03/2024

to do
pagination
filter free license out
#>


#Get all non active users - input = read host or standard =  100 days - output return a list with powershell objects containing userprincipalename/mail +  userid // to do pagination
function GetNonActiveUsers {
    param (
        
    )
    $nonActiveUsers = @()
    <#
    signInActivity  contains follow information:
                    "lastSignInDateTime":
                    "lastSignInRequestId":
                    "lastNonInteractiveSignInDateTime": 
                    "lastNonInteractiveSignInRequestId": 
                    "lastSuccessfulSignInDateTime":             
                    "lastSuccessfulSignInRequestId":
    #>
    $filterUsers = "?`$select=signInActivity,mail,id,userPrincipalName&"#`$top=999"
    $allUsersUri = "https://graph.microsoft.com/v1.0/users$filterUsers"
    $AllUsersResponse = (Invoke-MgGraphRequest -Method GET -Uri $allUsersUri).value
    #if there is one item make it an array > so the loop will work
    if ($AllUsersResponse -isnot [system.array]) {
        $AllUsersResponse = @($AllUsersResponse)
    }
    #if you don't give up X days, the standard will be 100 days
    $days = Read-Host "How many days for last login"
    if ($days -eq "") {
        $days = 100
    }
    foreach ($user in $AllUsersResponse) {
        $userId = $user.id
        $userMail = $user.userPrincipalName                     #check the result, you can choose between mail or userPrincipalName
        $lastSignInDateTime = $user.signInActivity.lastSignInDateTime
        <#
        if ($null -eq $lastSignInDateTime){
            write-host "there is no sign in information available for $userMail"
        }
        #$lastsignindate
        #>
        $signInDate = $lastSignInDateTime -as [datetime]
        if (-not $signInDate -or ([datetime]::UtcNow - $signInDate).TotalDays -gt $days) {
        #if ([string]::IsNullOrEmpty($lastsignin) -or ([datetime]::UtcNow - [datetime]$lastsignin).TotalDays -gt $days) {
            $userInfo = [pscustomobject]@{
                mail = $userMail
                userId = $userId
            }
            $nonActiveUsers += $userInfo
            #write-host "$userMail has not been seen for: $days days or more / the user never logged in" #
        }
    }
    return $nonActiveUsers
}

#Get all disabled Users - no input requiret - output return a list with powershell objects containing userprincipalename/mail +  userid // to do pagination
function GetDisabledUsers{
    param (

    )
    $disabledUsers = @()
    $filter = "?`$select=accountEnabled,userPrincipalName,Id&`$filter=accountEnabled eq false"
    $uriDisabledUsers = "https://graph.microsoft.com/v1.0/users$filter"

    $responseDisabledUsers = (Invoke-MgGraphRequest -Method GET -Uri $uriDisabledUsers).value
    #if there is one item make it an array > so the loop will work
    if ($responseDisabledUsers -isnot [system.array]) {
        $responseDisabledUsers = @($responseDisabledUsers)
    }

    foreach ($user in $responseDisabledUsers) {
        #$accountEnabled = $user.accountEnabled
        #if (-not ($accountEnabled)){ # can scip this by using a filter
            $userId = $user.id
            $userMail = $user.userPrincipalName                     #check the result, you can choose between mail or userPrincipalName
            $userInfo = [pscustomobject]@{
                    mail = $userMail
                    userId = $userId
            }
            $disabledUsers += $userInfo
       # }
    }
    return $disabledUsers
}

# check if  users  have a license / input directory/hash with userid and usermail / output list with powershell object(userid, mail, licenseId) for licened users or list with powershell object(userid, mail) for non licend users
function GetUserLisenceID {
    param (
        $allInputUsers
    )
    $listLicenseUsers = @()
    $listNonLicendUsers = @()
    foreach ($user in $allInputUsers) {
        $listLicensesId = @()
        #$userId = $user.userId
        $userMail = $user.mail
        $licenseUricheck = "https://graph.microsoft.com/v1.0/users/$userId/licenseDetails"
        $userLicense = (Invoke-MgGraphRequest -Method GET -Uri $licenseuricheck).value
        #if there is one item make it an array > so the loop will work
        if ($userLicense -isnot [system.array]) {
            $userLicense = @($userLicense)
        }
        if ($userLicense.Count -gt 0) {
            #write-host "$userMail has a license assigned" -ForegroundColor Green
            foreach ($license in $userlicense) {
                $guid = $license.skuId
                $listLicensesId += $guid
            }
            $userInfoLicense = [pscustomobject]@{
                #userId = $userId
                mail = $userMail
                license = $listLicensesId
            }
            $listLicenseUsers += $userInfoLicense
        }
        else {
            $userInfoNonLicense = [pscustomobject]@{
                #userId = $userId
                mail = $userMail
            }
            $listNonLicendUsers += $userInfoNonLicense
            #Write-Host "$userMail has no license assigned"
        }
    }
    #write-host " users with a license" -ForegroundColor Green
    return $listLicenseUsers
    #write-host "users without a license" -ForegroundColor Cyan
    #return $listNonLicendUsers
}

#Get the displayname and the skuid from all the license in your tenant  output list with  hash tables key = skuid value = Pretty Name License
function GetNameLicense {
    param (
    )
    #get all the microsoft license information !!!!microsft can change this link!!!!!!!!
    $microsoftLicenseUri = "https://download.microsoft.com/download/e/3/e/e3e9faf2-f28b-490a-9ada-c6089a1fc5b0/Product%20names%20and%20service%20plan%20identifiers%20for%20licensing.csv" 
    $microsoftLicenseOverview = Invoke-RestMethod -Method Get -Uri $microsoftLicenseUri| ConvertFrom-Csv
    #$microsoftLicenseOverview

    #Sort the info from all microsft licenses in a hash table key = guid, value = product display name
    $skuinformation = @{}
    foreach ($item in $microsoftLicenseOverview) {
        $skuinformation[$item.GUID] = $item.'Product_Display_Name'
    }

    #Get  license information from my tenant (id)
    $uriLicense = "https://graph.microsoft.com/v1.0/subscribedSkus"
    $licensesResponse = (Invoke-MgGraphRequest -Method GET -Uri $uriLicense).value
    #$licensesResponse

    #Get the dispalyname from the license id
    $listTenantLicenses = @()
    foreach ($license in $licensesResponse) {
        $tenantLinceses = @{}
        #$skuNamePretty = ($microsoftLicenseOverview | Where-Object {$_.GUID -eq $license.skuId} | Sort-Object Product_Display_Name -Unique)."ï»¿Product_Display_Name"
        #$skuNamePretty = $skuinformation[$license.skuId]
        if ($skuinformation.ContainsKey($license.skuId)){
            <#
            if (-not $skuNamePretty -or $skuNamePretty -match "free|trial") {
                continue # Skip free/trial licenses early
            }
            $licenseId = $license.skuId
            $displayname = $skuinformation[$license.skuId]
            $tenantLinceses[$licenseId] = $displayname
            #>
            
            $tenantLinceses = [pscustomobject]@{
                displayname = $skuinformation[$license.skuId]
                skuId = $license.skuId
            }
        }
        $listTenantLicenses += $tenantLinceses
    }
    return $listTenantLicenses
}

#convert license Id to a licenseName only if the license is in your tenant!! 
#input list of users and - output 
function ConvertLicenseIDToName {
    param (
        $nonActiveWithLicense,
        $listCompanyLicense
    )
    $listNonActiveUserWithLicenseName = @()
    foreach ($userItem in $nonActiveWithLicense) {
        $userMail = $userItem.mail
        $listSkuId = $userItem.license
        $listLicenseName = @()
        foreach ($userLicense in $listSkuId) {
            foreach ($companyLicense in $listCompanyLicense){
                if ($userLicense -eq $companyLicense.skuId){
                    $licenseName = $companyLicense.displayname
                    $listLicenseName += $licenseName
                }
            }
        }
        $test = [pscustomobject]@{ # inspiratie is op voor variable namen
            allNamedLicenseUser = $listLicenseName
            userEmail = $userMail
        }
        $listNonActiveUserWithLicenseName += $test
    }
    return $listNonActiveUserWithLicenseName
}


<#
add Device to group
#>

function FunctionAddDeviceToGroup {
  param (
    $groupId,
    $deviceId #uitzoeken azure of intune
    )
  $uriDevice = "https://graph.microsoft.com/v1.0/groups/$groupId/members/`$ref"

  $jsonGroup = @{  
    "@odata.id" = "https://graph.microsoft.com/v1.0/devices/$deviceId"  
  } | ConvertTo-Json
      
  Invoke-MgGraphRequest -Method POST -Uri $uriDevice -Body $jsonGroup -ContentType "application/json"
}


<#
adding user to teams channel as member
https://learn.microsoft.com/en-us/graph/api/team-post-members?view=graph-rest-1.0&tabs=http

choose member/owner in json
#>

Connect-MgGraph

function AddUserTeams {
    param (
        $userIdInformation,
        $teamId,
        $channelId
    )
    $uriTeams = "https://graph.microsoft.com/v1.0/teams/$teamId/members" #/channels/{$channelId}/members"
    
    $jsonTeam = @{
        "@odata.type" = "#microsoft.graph.aadUserConversationMember"
        "roles" = @("member")
        "user@odata.bind" = "https://graph.microsoft.com/v1.0/users('$userIdInformation')"
    } | ConvertTo-Json
    
    Invoke-MgGraphRequest -Method POST -Uri $uriTeams -Body $jsonTeam -ContentType "application/json"
}


<#
Get Device(s) id(s) from user
#>

connect-mggraph
function GetUserDeviceInformation {
    param (
        $userInformation #userId!!!!!
    )
    $uriDevice = "https://graph.microsoft.com/v1.0/users/$userInformation/managedDevices"

    $responseDevice = (Invoke-MgGraphRequest -Method Get -uri $uriDevice).value

    [PSCustomObject][ordered]@{
        intuneDeviceId      = $responseDevice.Id
        azureAdDeviceId     = $responseDevice.azureAdDeviceId
        deviceName          = $responseDevice.deviceName   
    }
}

$userInformation = "UserId"

$test = GetUserDeviceInformation -userInformation $userInformation
$test.intuneDeviceId
$test.azureAdDeviceID
$test.deviceName



function GetUserId {
    param (
        $userInformation
    )
    $uriUser = "https://graph.microsoft.com/v1.0/users/$userInformation"
    $responseUser = Invoke-MgGraphRequest -Method Get -uri $uriUser

    [PSCustomObject][ordered]@{
        userId      = $responseUser.Id
        userEmail   = $responseUser.mail
    }
    #return $responseUser
}

$userIdTest
$test = GetUserId -userInformation $userIdTest
$test.userEmail



<#
add Device to group
#>

function FunctionAddDeviceToGroup {
  param (
    $groupId,
    $deviceId #uitzoeken azure of intune
    )
  $uriDevice = "https://graph.microsoft.com/v1.0/groups/$groupId/members/`$ref"

  $jsonGroup = @{  
    "@odata.id" = "https://graph.microsoft.com/v1.0/devices/$deviceId"  
  } | ConvertTo-Json
      
  Invoke-MgGraphRequest -Method POST -Uri $uriDevice -Body $jsonGroup -ContentType "application/json"
}




<#
Made by: Eggeto

Add a user to a group function

logs:
Jul 17, 2024
creating basic function

Aug 26, 2024
Adding troubleshooting + fine tuning + function give some feedback
#>

#Aug 26, 2024 version
function AddUserToGroup {
    param (
        [string]$groupId,
        [string]$userID
    )
    #Finding group info
    $uriGroup = "https://graph.microsoft.com/v1.0/groups/$groupId"
    $groupName = Invoke-MgGraphRequest -Method GET -Uri $uriGroup -ErrorAction SilentlyContinue
    $groupName = $groupName.displayName

    #Checking if user is already member of the group
    $uriUser = "$uriGroup/members" 
    $checkUser = (Invoke-MgGraphRequest -Method GET -Uri $uriUser -ErrorAction SilentlyContinue).value

    if ($userId -like $checkUser.id){
        return "user: $($checkUser.mail) is already member of group: $groupName"
    }

    #adding user to group
    $uriGroup =  "$uriUser/`$ref" 

    $jsonGroup = 
    @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$userId"
    } | convertTo-Json
    # "@odata.id": "https://graph.microsoft.com/v1.0/users/{$userIdTest}" works also!

    Invoke-MgGraphRequest -Method POST -Uri $uriGroup -Body $jsonGroup -ContentType "application/json" -StatusCodeVariable "status"
    if ($status -eq "204"){
        return "Added user: $($checkUser.mail) to group: $groupName"
    }
    else{
        return "something went wrong HTTP status code: $status"
    }
}

#or the basic function (Jul 17, 2024)

function AddUserToGroup {
    param (
        $groupId,
        $userID
    )
    #https://learn.microsoft.com/en-us/graph/api/group-post-members?view=graph-rest-1.0&tabs=http
    #`$ref escaping ` $ref!!!!
    $uriGroup =  "https://graph.microsoft.com/v1.0/groups/{$groupId}/members/`$ref" 

        $jsonGroup = 
    @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$userId"
    } | convertTo-Json

#    "@odata.id": "https://graph.microsoft.com/v1.0/users/{$userIdTest}" works also!

    Invoke-MgGraphRequest -Method POST -Uri $uriGroup -Body $jsonGroup -ContentType "application/json" -ErrorAction SilentlyContinue
}


$groupIdTest = ""
$userIdTest = ""
$test = AddUserToGroup -groupId $groupIdTest -userID $userIdTest
$test




<#
adding license 

Need License SkuId !!

[ordered] added to json other wise the order was not correct!
 #is not converting correctly ==> "" instead of []
 werken met [pscustomobject] en depth
 $test = $jsonLicense | ConvertTo-Json -Depth 5

$lisenceSkuE3 = "05e9a617-0261-4cee-bb44-138d3ef5d965"
$lisenceSkuTeams = "e43b5b99-8dfb-405f-9987-dc307f34bcbd"

https://jeffbrown.tech/going-deep-converting-powershell-objects-to-json/
#>

Connect-MgGraph -scope User.ReadWrite.All, Directory.ReadWrite.All


function AddLicenseToUser {
    param (
        $LicenseId,
        $userId
    )
    $jsonLicense = [PSCustomObject][ordered]@{
        "addLicenses" = @(
            @{
                "disabledPlans" = @()
                "skuId" = $licenseId
            }
        )
        "removeLicenses" = @()
        } | ConvertTo-Json -Depth 5


    $uriLicense = "https://graph.microsoft.com/v1.0/users/{$userId}/microsoft.graph.assignLicense" #!!!!!!!!!!!!!!!!!!moet Object ID worden ipv userprincipalname!!!!!!!!!!!!!!!!!!!!!!

    Invoke-MgGraphRequest -Method POST -Uri $uriLicense -Body $jsonLicense -ContentType "application/json"
}

$lisenceId = ""
$userId = ""
$test = AddLicenseToUser -LicenseId $lisenceId -userId $userId
$test


<#
Bloody H*ll fieu datetime format :-)
if you get an 400 error check the $uri!!!
should be simular as below
#$uri1 = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=enrolledDateTime ge 2023-12-11T21:17Z and enrolledDateTime le 2024-08-17T20:17Z" #this works
do not add [datetime] to the param!!!! it will mess up the time values

logs
16/08/2024
creating function
17/08/2024
fine tuning
#>

function GetAllNewDevices {
    param(
        $startDate,
        $endDate
    )
    
    $startDate = $startDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mmZ')
    $endDate = $endDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mmZ')

    $filter = "`$filter=enrolledDateTime ge $startDate" # and enrolledDateTime le $endDate" => if you want devices between a certain date uncommand $enddate
    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$filter"
    write-host $uri

    $devices = (Invoke-MgGraphRequest -Method GET -uri $uri).value

    return $devices
}

connect-MgGraph

$startDate = (Get-Date).AddDays(-250) #days before the start date
#$endDate = Get-Date

$newDevices = GetAllNewDevices -startDate $startDate -endDate $endDate

foreach ($device in $newDevices){
    write-host $device.deviceName
}

<#
functionGetUserIdMail
#>

function GetUserId {
    param (
        $userInformation
    )
    $uriUser = "https://graph.microsoft.com/v1.0/users/$userInformation"
    $responseUser = Invoke-MgGraphRequest -Method Get -uri $uriUser

    [PSCustomObject][ordered]@{
        userId      = $responseUser.Id
        userEmail   = $responseUser.mail
    }
    #return $responseUser
}

$userIdTest
$test = GetUserId -userInformation $userIdTest
$test.userEmail


<#
add Device to group
#>

function FunctionAddDeviceToGroup {
  param (
    $groupId,
    $deviceId #uitzoeken azure of intune
    )
  $uriDevice = "https://graph.microsoft.com/v1.0/groups/$groupId/members/`$ref"

  $jsonGroup = @{  
    "@odata.id" = "https://graph.microsoft.com/v1.0/devices/$deviceId"  
  } | ConvertTo-Json
      
  Invoke-MgGraphRequest -Method POST -Uri $uriDevice -Body $jsonGroup -ContentType "application/json"
}


<#
Made by: Eggeto

Add a user to a group function

logs:
Jul 17, 2024
creating basic function

Aug 26, 2024
Adding troubleshooting + fine tuning + function give some feedback
#>

#Aug 26, 2024 version
function AddUserToGroup {
    param (
        [string]$groupId,
        [string]$userID
    )
    #Finding group info
    $uriGroup = "https://graph.microsoft.com/v1.0/groups/$groupId"
    $groupName = Invoke-MgGraphRequest -Method GET -Uri $uriGroup -ErrorAction SilentlyContinue
    $groupName = $groupName.displayName

    #Checking if user is already member of the group
    $uriUser = "$uriGroup/members" 
    $checkUser = (Invoke-MgGraphRequest -Method GET -Uri $uriUser -ErrorAction SilentlyContinue).value

    if ($userId -like $checkUser.id){
        return "user: $($checkUser.mail) is already member of group: $groupName"
    }

    #adding user to group
    $uriGroup =  "$uriUser/`$ref" 

    $jsonGroup = 
    @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$userId"
    } | convertTo-Json
    # "@odata.id": "https://graph.microsoft.com/v1.0/users/{$userIdTest}" works also!

    Invoke-MgGraphRequest -Method POST -Uri $uriGroup -Body $jsonGroup -ContentType "application/json" -StatusCodeVariable "status"
    if ($status -eq "204"){
        return "Added user: $($checkUser.mail) to group: $groupName"
    }
    else{
        return "something went wrong HTTP status code: $status"
    }
}

#or the basic function (Jul 17, 2024)

function AddUserToGroup {
    param (
        $groupId,
        $userID
    )
    #https://learn.microsoft.com/en-us/graph/api/group-post-members?view=graph-rest-1.0&tabs=http
    #`$ref escaping ` $ref!!!!
    $uriGroup =  "https://graph.microsoft.com/v1.0/groups/{$groupId}/members/`$ref" 

        $jsonGroup = 
    @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$userId"
    } | convertTo-Json

#    "@odata.id": "https://graph.microsoft.com/v1.0/users/{$userIdTest}" works also!

    Invoke-MgGraphRequest -Method POST -Uri $uriGroup -Body $jsonGroup -ContentType "application/json" -ErrorAction SilentlyContinue
}


$groupIdTest = ""
$userIdTest = ""
$test = AddUserToGroup -groupId $groupIdTest -userID $userIdTest
$test


<#
adding license 

Need License SkuId !!

[ordered] added to json other wise the order was not correct!
 #is not converting correctly ==> "" instead of []
 werken met [pscustomobject] en depth
 $test = $jsonLicense | ConvertTo-Json -Depth 5

$lisenceSkuE3 = "05e9a617-0261-4cee-bb44-138d3ef5d965"
$lisenceSkuTeams = "e43b5b99-8dfb-405f-9987-dc307f34bcbd"

https://jeffbrown.tech/going-deep-converting-powershell-objects-to-json/
#>

Connect-MgGraph -scope User.ReadWrite.All, Directory.ReadWrite.All


function AddLicenseToUser {
    param (
        $LicenseId,
        $userId
    )
    $jsonLicense = [PSCustomObject][ordered]@{
        "addLicenses" = @(
            @{
                "disabledPlans" = @()
                "skuId" = $licenseId
            }
        )
        "removeLicenses" = @()
        } | ConvertTo-Json -Depth 5


    $uriLicense = "https://graph.microsoft.com/v1.0/users/{$userId}/microsoft.graph.assignLicense" #!!!!!!!!!!!!!!!!!!moet Object ID worden ipv userprincipalname!!!!!!!!!!!!!!!!!!!!!!

    Invoke-MgGraphRequest -Method POST -Uri $uriLicense -Body $jsonLicense -ContentType "application/json"
}

$lisenceId = ""
$userId = ""
$test = AddLicenseToUser -LicenseId $lisenceId -userId $userId
$test

<#
Get Device(s) id(s) from user
#>

connect-mggraph
function GetUserDeviceInformation {
    param (
        $userInformation #userId!!!!!
    )
    $uriDevice = "https://graph.microsoft.com/v1.0/users/$userInformation/managedDevices"

    $responseDevice = (Invoke-MgGraphRequest -Method Get -uri $uriDevice).value

    [PSCustomObject][ordered]@{
        intuneDeviceId      = $responseDevice.Id
        azureAdDeviceId     = $responseDevice.azureAdDeviceId
        deviceName          = $responseDevice.deviceName   
    }
}

$userInformation = "UserId"

$test = GetUserDeviceInformation -userInformation $userInformation
$test.intuneDeviceId
$test.azureAdDeviceID
$test.deviceName

Disconnect-MgGraph
