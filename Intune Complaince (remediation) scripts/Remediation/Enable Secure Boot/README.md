You can use the intunewin file and the detection script.

If you want to create the intunewin file yourself, 
you can download the file from: https://www.powershellgallery.com/packages/DellBIOSProvider/2.9.0 => manuel dowload
and use the script: secureBootEnable.ps1.
Combine both files to create an intunewin file.

The (un)install command is:
install behaviour: system

The device must be restarted before Secure Boot becomes active!! 

For detection,
you can use the detection script: detectionEnableSecureBoot.ps1

enjoy!
