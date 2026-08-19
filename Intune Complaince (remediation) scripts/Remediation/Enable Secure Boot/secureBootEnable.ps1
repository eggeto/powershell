<#
I have tried various ways of installing a PowerShell module via App/Script in Intune.

The method involving downloading the module via the PowerShell script failed every time.
I have abandoned that option as I have already spent too much time on it, without success.

The simpler option, where you download the module and package it as a Win32 app, worked straight away.
The PowerShell script below was created for this purpose.
You can also find the IntuneWin file in this folder.

(un)install commannd: 


A REBOOT IS REQUIRED!!!! to enable secure boot
#>

#Logging script
$logPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\enableSecureBootVX-transcript.log"
Start-Transcript -Path $logPath -Append -Force

try {
    Write-Host "try to install and import the module"

#location for the module
    $DellModuleFolderLocation = "C:\Program Files\WindowsPowerShell\Modules\DellBIOSProvider\2.10.2"

#name folder powershellmodule pre win32 packiging
    $sourceFolder = ".\dellbiosprovider"

#copy files to the location
    if (-not (Test-Path "$DellModuleFolderLocation\DellBIOSProvider.psd1")) {
        New-Item -Path $DellModuleFolderLocation -ItemType Directory -Force | Out-Null
        Copy-Item -Path $sourceFolder -Destination $DellModuleFolderLocation -Recurse -Container:$false -Force -ErrorAction Stop
        Write-Host "DellBIOSProvider module is copy to $DellModuleFolderLocation"
    }
#Import the module in powershell
    Import-Module "$DellModuleFolderLocation\DellBIOSProvider.psd1" -Force -ErrorAction Stop
    Write-Host "Module is imported."

#Check if secure boot is enabled
    $current = Get-Item -Path 'DellSmbios:\SecureBoot\SecureBoot'

    if ($current.CurrentValue -eq 'Enabled') {
        Write-Host "Secure Boot is already enabled"
        Stop-Transcript
        exit 0
    }

#enable secure boot
    Set-Item -Path 'DellSmbios:\SecureBoot\SecureBoot' -Value 'Enabled' -ErrorAction Stop
    Start-Sleep -Seconds 2
    
    $newcurrent = Get-Item -Path 'DellSmbios:\SecureBoot\SecureBoot'
    if ($newcurrent.CurrentValue -eq 'Enabled') {
        Write-Host "Secure Boot is successfully enabled"
        Stop-Transcript
        exit 0
    } else {
        Write-Host "Secure Boot is not enabled"
        Stop-Transcript
        exit 1
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)"
    Stop-Transcript
    exit 1
}
