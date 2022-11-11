[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [ValidateSet("FALSE", "TRUE")]
        [string]$Restart = "FALSE"
    )

[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('http://proxy.domain.com:8080', $true)
[system.net.webrequest]::defaultwebproxy.credentials = New-Object System.Net.NetworkCredential("user@domain.com", "P@ssw0rd1")
[system.net.webrequest]::defaultwebproxy.BypassProxyOnLocal = $true

Function Install-Softpaqs {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [ValidateSet("FALSE", "TRUE")]
        $Restart = "FALSE"
    )

    $TempWorkFolder = "$env:TEMP\HPCMSL"
    $HPCMSLVer = $null
        
    Try {
        [void][System.IO.Directory]::CreateDirectory($TempWorkFolder)
    }
    Catch {
        throw
    }

    Function Restart-asCMComputer {
        If (Test-Path -Path "C:\Windows\CCM\CcmRestart.exe") {
            $Time = [DateTimeOffset]::Now.ToUnixTimeSeconds()
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootBy' -Value $Time -PropertyType QWord -Force -ErrorAction SilentlyContinue
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootValueInUTC' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'NotifyUI' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'HardReboot' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindowTime' -Value 0 -PropertyType QWord -Force -ErrorAction SilentlyContinue
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindow' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'PreferredRebootWindowTypes' -Value @("4") -PropertyType MultiString -Force -ErrorAction SilentlyContinue
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'GraceSeconds' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue
            
            $CCMRestart = start-process -FilePath C:\windows\ccm\CcmRestart.exe -NoNewWindow -PassThru
        } Else {
            Write-Host "No ConfigMgr Client found" -ForegroundColor Yellow
        }
    } #Function Restart-asCMComputer

    # Disable IE First Run Wizard
    $null = New-Item –Path "HKLM:\SOFTWARE\Policies\Microsoft" –Name "Internet Explorer" –Force
    $null = New-Item –Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer" –Name "Main" –Force
    $null = New-ItemProperty –Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" –Name "DisableFirstRunCustomize" –PropertyType DWORD –Value 1 –Force
        
    # Get HPIA download URL
    $HPCMSLWebUrl = "https://www.hp.com/us-en/solutions/client-management-solutions/download.html"
    $HTML = Invoke-WebRequest –Uri $HPCMSLWebUrl -UseBasicParsing -ErrorAction Stop
    $HPCMSLDownloadURL = ($HTML.Links | Where-Object {$_.href -match "hp-cmsl-"}).href
    $HPCMSLFileName = $HPCMSLDownloadURL.Split('/')[-1]
    $HPCMSLFileVersion = $HPCMSLFileName.Split('-')[2]
    $HPCMSLFileVersion = $HPCMSLFileVersion.Substring(0,$HPCMSLFileVersion.Length-4)

    Write-Host "Online version of HPCMSL $HPCMSLFileVersion" -ForegroundColor Gray
    Write-Host "Download URL is $HPCMSLDownloadURL" -ForegroundColor Gray

    $HPCMSLVer = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall -ErrorAction 0 |
    Get-ItemProperty | Where-Object { $_.DisplayName -like "HP Client Management Script Library*" } |
    Select-Object -Property DisplayName, DisplayVersion
   
    If (!($HPCMSLVer.DisplayVersion -eq $HPCMSLFileVersion)) {               
        Write-Host "Local version of HPCMSL not found or older than online version" -ForegroundColor Yellow
        # Download HPCMSL
        Invoke-WebRequest -Uri $HPCMSLDownloadURL -OutFile "$TempWorkFolder\$HPCMSLFileName" -UseBasicParsing -ErrorAction Stop    
        
        # Install HPCMSL
        Try {
            $InstallParameter = @(
                "/SP-",
                "/VERYSILENT",
                "/NORESTART"
            )
    
            $Process = Start-Process –FilePath "$TempWorkFolder\$HPCMSLFileName" –WorkingDirectory "$TempWorkFolder" –ArgumentList $InstallParameter –NoNewWindow –PassThru –Wait –ErrorAction Stop
            Start-Sleep –Seconds 10

            # Test installation
            If (Test-Path -LiteralPath 'C:\Program Files\WindowsPowerShell\Modules\HP.Softpaq\HP.Softpaq.psm1') {
                Write-Host "Installation complete" -ForegroundColor Green
            } Else {
                Write-Host "HP Client Management Script Library not found. Exit Script." -ForegroundColor Red
                throw
            } #If
        } #Try
        Catch {
            Write-Host "Failed to install HPCMSL: $($_.Exception.Message)" -ForegroundColor Red
            throw
        } #Catch
    } Else {
        Write-Host "Local version of HPCMSL current" -ForegroundColor Green
    }

    # Create Softpaq folder
    $Softpaq = "C:\Softpaq"
    If (Test-Path -Path $Softpaq) { Remove-Item -Path $Softpaq -Recurse -Force }
    New-Item -Path "C:\" -Name "Softpaq" -ItemType Directory -Force
    Set-Location -Path $Softpaq

    Write-Host "Set path to $Softpaq"
    Set-Location -Path $Softpaq

    $OsVer = Get-HPDeviceDetails -Platform ((Get-WmiObject win32_baseboard).Product) -OSList |
    Sort-Object -Descending OperatingSystemRelease | Select-Object -First 1
    Write-Host "Last supported Windows 10 version is $OsVer.OperatingSystemRelease"

    Write-Host "Download and install softpaqs..."
    Get-SoftpaqList -Platform ((Get-WmiObject win32_baseboard).Product) -Os win10 -Bitness 64 -OsVer $OsVer.OperatingSystemRelease | 
    Where-Object -FilterScript { $_.Category -like "Driver*" } |
    ForEach-Object { Get-Softpaq -Number $_.id -Action silentinstall -Quiet -Overwrite skip -KeepInvalidSigned -DestinationPath $Softpaq }

    Write-Host "...done"
    If ($Restart -eq "TRUE") { Restart-asCMComputer }
}

Install-Softpaqs -Restart $Restart
