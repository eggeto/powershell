<#
.SYNOPSIS
    enable secure boot on Dell devices 
    Lenovo devices is for the next update
 
.DESCRIPTION
    - Download & Install DellBiosProvider
    - Set Secure Boot on "Enabled" via DellSmbios: PSDrive.

.NOTES
    - Run as system in win32 apps (intune) or admin (local)
    - Reboot is required
    - not take BIOS passwords into account!

install command:
%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '.\enableSecureBootV2.ps1'"
#>

# --- Logging setup ---
$logPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\enableSecureBootV2-transcript.log"
Start-Transcript -Path $logPath -Append -Force

try {
    Write-host "Try Enable SecureBoot"
 
    #Check if the device is Dell or Lenovo
    $manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    if ($manufacturer -notmatch "Dell") {
        Write-host "It is not a Dell or Lenovo Device: (Manufacturer: $manufacturer)."
        Stop-Transcript
        exit 1
    }

    #Check if the ps module is installed
    if (-not (Get-Module -ListAvailable -Name DellBIOSProvider)) {
        Write-Host "DellBIOSProvider not found."

        #Enable TLS 1.2 
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "TLS 1.2 enabled"

        #Install NuGet provider 
        try {
            if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -Scope AllUsers -ErrorAction Stop | Out-Null
                Write-Host "NuGet provider installed."
            }
        }
        catch {
            Write-Error "Failed to install nuget provider: $_"
            Stop-Transcript
            exit 1
        }

        #trust PSGallery
        try {
            $repository = Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue
            if ($repository -and $repository.InstallationPolicy -ne "Trusted") {
                Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
            }
        } catch {
            Write-Warning "Failed to set PSGallery as trusted repository: $_"
            Stop-Transcript
            exit 1
        }

        #install DellBiosProvider module
        try {
            Install-Module -Name DellBIOSProvider -Force -Confirm:$false -Scope AllUsers -ErrorAction Stop
            Write-Host "DellBIOSProvider installed."
        }
        catch {
           Write-Error "Error installing DellBiosProviuder PS module: $_"
           Stop-Transcript
           exit 1
        }
    }
    else {
        Write-Host "DellBIOSProvider already installed."
    }

    #import the module
    Import-Module DellBIOSProvider -Force
    Write-host "Module imported."
 
    #check the current state
    $current = Get-Item -Path 'DellSmbios:\SecureBoot\SecureBoot'
 
    if ($current.CurrentValue -eq 'Enabled') {
        Write-host "Secure Boot is already enabled"
        Stop-Transcript
        exit 0
    }

    #Enable secure boot
    Set-Item -Path 'DellSmbios:\SecureBoot\SecureBoot' -Value 'Enabled'
    
    Start-Sleep -Seconds 2
    $newcurrent = Get-Item -Path 'DellSmbios:\SecureBoot\SecureBoot'

    if ($newcurrent.CurrentValue -eq 'Enabled') {
        Write-host "Secure Boot is enabled"
        Stop-Transcript
        exit 0
    }
    else {
        Write-host "Secure Boot is not enabled"
        Stop-Transcript
        exit 1
    }
}
catch {
    Write-host "Error: $($_.Exception.Message)"
    Write-host "Error at line: $($_.InvocationInfo.ScriptLineNumber)"
    Stop-Transcript
    exit 1
}
