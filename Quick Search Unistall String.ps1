<#
  .SYNOPSIS
  Finding an (quiet) uninstall string from a program

  .INPUTS
  Name from the program you want to uninstall

  .OUTPUTS
  Displayname, Uninstallstring, QuietuninstallString (if the app is found)

  made by eggeto

  .logs
  made 08/06/2022
  update 08/06/2025
#>

param( 
  [parameter(ValueFromPipeline=$true, Mandatory=$true, HelpMessage="name for the app to get uninstall string")]
  [string]$appname
)

#Registry paths
$RegPath32 = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
$RegPath64 = Get-ChildItem -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

$appList = @()
#search for uninstall string
foreach($app in $RegPath32){
  $app | 
  Get-ItemProperty |
  Where-Object {$_.DisplayName -like "*$appname*" } |
  Select-Object -Property DisplayName, UninstallString, QuietUninstallString 
  
}
$applist += $app

foreach ($app in $RegPath64) {
  $app |  
  Get-ItemProperty |
  Where-Object {$_.DisplayName -like "*$appname*" } |
  Select-Object -Property DisplayName, UninstallString, QuietUninstallString 
  
}
$applist += $app
#print All Uninstall Strings    
$applist
