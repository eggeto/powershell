<#
.SYNOPSIS
Automatically remove old devices/servers from Sophos Central based on Intune device inventory (for devices) and last seen date (for servers).

.DESCRIPTION
Automatically remove old devices/servers from Sophos Central.
For the devices,
the script compares the device inventory in Sophos Central with the device inventory in Intune. 
If a device is not found in Intune, it is removed from Sophos Central.

For the servers,
the script checks the last seen date of the servers in Sophos Central.
If a server has not been seen for 6 or more months (can be modified), it is removed from Sophos Central.

!!CHECK THE OUTPUT CAREFULLY BEFORE REMOVING THE COMMAND FROM THE FUNCTION DeleteDevicesSophos, ONCE IT RUNS IT CAN'T BE UNDONE !!

.EXAMPLE
=> .output

.INPUTS
nothing

.OUTPUTS
Got Intune devices
Got Token
Got tenant info
ARE YOU SURE YOU WANT TO REMOVE FOLLOWING DEVICES FROM SOPHOS CENTRAL: 
Devices not in Intune: 

hostname         lastSeenAt          type     os.name
--------         ----------          ----     -------
...                 ...               ...       ...

Servers not online for + 6 months:
hostname         lastSeenAt          type     os.name
--------         ----------          ----     -------
...                 ...               ...       ...

.NOTES
    Version:        1.0 
    Author:         eggeto
    Creation Date:  16/04/2026
    Requirements:   
    - PowerShell: 
    - Microsoft Graph PowerShell SDK modules
    - Sophos Central API credentials (client ID and client secret)
#>
