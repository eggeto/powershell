<#
Detection script for enable secure boot win32 app via intune.
Check if the module is installed and if secure boot is enabled.
#>

try {
    $DellModulePath = "C:\Program Files\WindowsPowerShell\Modules\DellBIOSProvider\2.10.2\DellBIOSProvider.psd1"

#is module installed
    if (-not (Test-Path $DellModulePath)) {
        exit 1
    }
#import module
    Import-Module $DellModulePath -Force -ErrorAction Stop

    $currentState = Get-Item -Path 'DellSmbios:\SecureBoot\SecureBoot' -ErrorAction Stop

    if ($currentState.CurrentValue -eq 'Enabled') {
        Write-Output "SecureBoot enabled"
        exit 0
    }
    else {
        exit 1
    }
}
catch {
#if there is an error => exit 1
    exit 1
}
