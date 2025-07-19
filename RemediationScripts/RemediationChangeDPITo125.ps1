#https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/dpi-related-apis-and-registry-settings?view=windows-11

#Detection
$path= "registry::HKEY_CURRENT_USER\Control Panel\Desktop"
$name = "LogPixels"
$value = 96
#96 => DPI 100%
#120 => DPI 125%

Try {
    $Registry = Get-ItemProperty -Path $Path -ErrorAction Stop
    write-host $Registry.$name

    If ($Registry.$name -eq $value){
        Write-Output "DPI is ok"
        Exit 0
    }
    else{
        Write-Warning "DPI need to change"
        Exit 1
    }
}
Catch {
    Write-Warning "Can't find the keys"
    Exit 1
}

#Remediation
# Set DPI scaling to 125%
try {
    # Apply changes
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "LogPixels" -Value 120
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Win8DpiScaling" -Value 1


    Write-Host "DPI scaling set to 125%. Did you try to logoff and logon again"
}
catch{
    Write-Warning "Can't fix the DPI"
}

