It started with the follow script:
https://github.com/eggeto/powershell/blob/main/GetMonitorsUsers.ps1
To get Monitor/screen information that are connected to the (work)devices.
The script was based on writing info to azure blob storage, but it had pro & cons.

This script writes to Log Analytics, 
Because the Log Analytics HTTP Data Collector API is end of life
is this the updated version that use Logs Ingestion API.
It also has pro & cons :-)

enjoy
