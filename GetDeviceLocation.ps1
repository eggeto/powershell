<#
	madeby: Eggeto
#>
function LocateDevice {
	param (	
		$deviceName
	)
	$deviceId = GetDeviceId -deviceInfo $deviceName #intune device Id!!!
	write-host "the device id is: $deviceId"
	$uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$deviceId" #dc4878b8-c9f4-423b-a68f-49218d6ead83"
	$response = Invoke-MgGraphRequest -Method GET -uri $uri
	$isLocationKnown = $response.deviceActionResults.deviceLocation
	#check if there is an location
	$toSync = $false
	If($null -eq $isLocationKnown){
		$toSync = $true
	}
	elseIf($null -ne $isLocationKnown){
		$latitude = $isLocationKnown.latitude
		$longitude = $isLocationKnown.longitude
		if ($latitude -eq 0 -and $longitude -eq 0){
			$toSync = $true
		}
	}
	if ($toSync){
		for ($i = 0; $i -lt 2; $i++) {  # change 1 in to a number how many tries you would like to perform
			DeviceSync -deviceId $deviceId
			if ($null -eq $isLocationKnown -or $null -eq $latitude){
				Write-Host "device location not found"
				write-host "let's try again"
			}
			else {
				write-host "location is found"
				#if there is an location
				write-host "Latitude: $latitude, Longitude: $longitude"
				#$uriGoogle = "https://www.google.com/maps?q=$Latitude,$Longitude"
				#$locationGoogle = Invoke-WebRequest -Uri $uriGoogle -Method Get
				#$locationGoogle
				Start-Process "https://www.google.com/maps?q=$Latitude,$Longitude"
				$toSync = $false
				break
			}
		}
		if ($toSync){
			write-host "Nope, Nothing"
		}	
	}
}


function GetDeviceId {
	param (
		$deviceInfo
	)
	#$filter = "?$filter=emailaddress eq '$deviceInfo'"
	$filter = "?`$filter=deviceName eq '$deviceInfo'"
	$uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices$filter"
	$response = (Invoke-MgGraphRequest -Method GET -uri $uri).value
	return $response.id
}

function DeviceSync {
	param (
		$deviceId
	)
	write-host "Device doesn't have an location yet"
	write-host "Let's start a sync"
	$uriSync = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$deviceId/microsoft.graph.syncDevice"
	Invoke-GraphRequest -Method POST -uri $uriSync
	write-host "waiting for sync, sleep 5 seconds"
	Start-Sleep -Seconds 5
}

#Connect-MgGraph -scope DeviceManagementManagedDevices.PrivilegedOperations.All
$deviceName = read-host "pretty please the device name: "
$locate = LocateDevice -deviceName $deviceName
$locate
#Disconnect-MgGraph

