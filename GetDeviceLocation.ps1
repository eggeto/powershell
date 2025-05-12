<#
	madeby: Eggeto
#>

function LocateDevice {
	param (	
		$deviceName
	)
	$deviceId = GetDeviceId -deviceInfo $deviceName
	write-host "the device id is: $deviceId"
	$uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$deviceId" 
	$response = Invoke-MgGraphRequest -Method GET -uri $uri
	$isLocationKnown = $response.deviceActionResults.deviceLocation
	If($isLocationKnown -ne $null){
		$Latitude = $response.deviceActionResults.deviceLocation.latitude
		$Longitude = $response.deviceActionResults.deviceLocation.longitude
		write-host "Latitude: $Latitude, Longitude: $Longitude"
		#$uriGoogle = "https://www.google.com/maps?q=$Latitude,$Longitude"
		#$locationGoogle = Invoke-WebRequest -Uri $uriGoogle -Method Get
		#$locationGoogle
		Start-Process "https://www.google.com/maps?q=$Latitude,$Longitude"
	}
     	else {
        	write-host "Device doesn't have an location"
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

Connect-MgGraph
$deviceName = read-host "pretty please the device name: "
$locate = LocateDevice -deviceName $deviceName
$locate
Disconnect-MgGraph

