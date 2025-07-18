#detection show hidden folders and files

$path= 'registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
#$name = 'Hidden'
$value = 1


Try {
    $Registry = Get-ItemProperty -Path $Path -ErrorAction Stop

    If ($Registry.Hidden -eq $value){
        Write-Output "hidden files are enabled"
        Exit 0
    }
    else{
        Write-Warning "hidden files are disabled"
        Exit 1
    }
}

Catch {
    Write-Warning "Not Compliant"
    Exit 1
}


#remediation show hidden folders and files
$path= 'registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$name = 'Hidden'
$value = 1

try {
    write-host "Change Reg Key"
    Set-ItemProperty -Path $path -Name $name -Value $value -Force | Out-Null
    Write-Host "value is changed to $value"
    Exit 0
}
catch {
    Write-Host "Error"
    Write-Error $_
    exit 1
}

