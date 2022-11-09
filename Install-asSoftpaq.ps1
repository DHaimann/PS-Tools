[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('http://proxy.domain.com:port', $true)
[system.net.webrequest]::defaultwebproxy.credentials = New-Object System.Net.NetworkCredential("user@domain.at", "p@ssword!")
[system.net.webrequest]::defaultwebproxy.BypassProxyOnLocal = $true

# Create Softpaq folder
$Softpaq = "C:\Softpaq"
If (Test-Path -Path $Softpaq) { Remove-Item -Path $Softpaq -Recurse -Force }
New-Item -Path "C:\" -Name "Softpaq" -ItemType Directory -Force
Set-Location -Path $Softpaq

Write-Output "Set path to $Softpaq"
Set-Location -Path $Softpaq

$OsVer = Get-HPDeviceDetails -Platform ((Get-WmiObject win32_baseboard).Product) -OSList |
Sort-Object -Descending OperatingSystemRelease | Select-Object -First 1
Write-Output "Last supported Windows 10 verion is $OsVer"

Write-Output "Download and install softpaqs..."
Get-SoftpaqList -Platform ((Get-WmiObject win32_baseboard).Product) -Os win10 -Bitness 64 -OsVer $OsVer.OperatingSystemRelease | 
Where-Object -FilterScript { $_.Category -like "Driver*" } |
ForEach-Object { Get-Softpaq -Number $_.id -Action silentinstall -Quiet -Overwrite skip -KeepInvalidSigned -DestinationPath C:\Softpaq }

Write-Output "...done"
Write-Output "Don't forget to reboot the machine!"