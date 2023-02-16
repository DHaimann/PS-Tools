[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [ValidateSet("DOWNLOAD", "LIST", "INSTALL", "SCAN")]
        $Action = "LIST",
        [Parameter(Mandatory=$false)]
        [ValidateSet("All", "Application", "Driver", "Bios", "Firmware")]
        $PackageType = "Drivers",
        [Parameter(Mandatory=$false)]        
        [ValidateSet("All", "Critical", "Recommended")]
        $Selection = "All",
        [Parameter(Mandatory=$false)]
        [ValidateSet("FALSE", "TRUE")]
        [string]$Restart = "FALSE"
    )

Function Run-ThinInstaller {
    [CmdletBinding()]
        Param (
            [Parameter(Mandatory=$false)]
            [ValidateSet("DOWNLOAD", "LIST", "INSTALL", "SCAN")]
            $Action = "LIST",
            [Parameter(Mandatory=$false)]
            [ValidateSet("All", "Application", "Driver", "Bios", "Firmware", "1", "2", "3", "4")]
            $PackageType = "Drivers",
            [Parameter(Mandatory=$false)]        
            [ValidateSet("All", "Critical", "Recommended", "A", "C", "R")]
            $Selection = "All",
            [Parameter(Mandatory=$false)]
            $LogFolder = "$env:systemdrive\ProgramData\Lenovo\Logs",
            [Parameter(Mandatory=$false)]
            [ValidateSet("FALSE", "TRUE")]
            $Restart = "FALSE"

        )

        # Params
        $script:FolderPath = "Lenovo_Updates" # the subfolder to put logs into in the storage container
        $ProgressPreference = 'SilentlyContinue' # to speed up web requests

        # Create Directory Structure
        $DateTime = Get-Date –Format "yyyyMMdd-HHmmss"
        $ReportsFolder = "$ReportsFolder\$DateTime"
        $TILogFile = "$LogFolder\Run-ThinInstaller.log"
        $script:TempWorkFolder = "$env:TEMP\Lenovo"
        
        Try {
            [void][System.IO.Directory]::CreateDirectory($LogFolder)
            [void][System.IO.Directory]::CreateDirectory($TempWorkFolder)
            [void][System.IO.Directory]::CreateDirectory($ReportsFolder)
        }
        Catch {
            throw
        }

        # Function write to a log file in ccmtrace format
        Function CMTraceLog {
        
            [CmdletBinding()]
            Param (
		        [Parameter(Mandatory=$false)]
		        $Message,
		        [Parameter(Mandatory=$false)]
		        $ErrorMessage,
		        [Parameter(Mandatory=$false)]
		        $Component = "Script",
		        [Parameter(Mandatory=$false)]
		        [int]$Type,
		        [Parameter(Mandatory=$false)]
		        $LogFile = $TILogFile
	        )

	        $Time = Get-Date -Format "HH:mm:ss.ffffff"
	        $Date = Get-Date -Format "MM-dd-yyyy"
	        If ($ErrorMessage -ne $null) {$Type = 3}
	        If ($Component -eq $null) {$Component = " "}
	        If ($Type -eq $null) {$Type = 1}
	        $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
	        $LogMessage.Replace("`0","") | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        } # Function CMTraceLog

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
        
        CMTraceLog –Message "##########################" –Component "Preparation"
        CMTraceLog –Message "## Invoke-asLenvoUpdate ##" –Component "Preparation"
        CMTraceLog –Message "##########################" –Component "Preparation"        
        Write-Host "Starting Lenovo System Update to Update Lenovo Drivers" -ForegroundColor Magenta
 
        # Check Lenovo Device
        Try {
            $Manufacturer = (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer
            If (!($Manufacturer -like "Lenovo*")) {
               CMTraceLog –Message "Manufacturer not Lenovo. Exit Script." –Component "Preparation" -Type 3
               Write-Host "Manufacturer not Lenovo. Exit script." -ForegroundColor Red
               throw
            } Else {
               CMTraceLog –Message "Manufacturer Lenovo detected. Continue." –Component "Preparation" -Type 1
               Write-Host "Manufacturer Lenovo detected. Continue." -ForegroundColor Green
            }
        }
        Catch {
            CMTraceLog –Message "Failed to to get Manufacturer. Exit script." –Component "Preparation" -Type 3
            Write-Host "Failed to to get Manufacturer. Exit script." -ForegroundColor Red
            throw
        }
        
        # Check for ThinInstaller
        # Disable IE First Run Wizard
        CMTraceLog –Message "Disabling IE first run wizard" –Component "Preparation"
        $null = New-Item –Path "HKLM:\SOFTWARE\Policies\Microsoft" –Name "Internet Explorer" –Force
        $null = New-Item –Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer" –Name "Main" –Force
        $null = New-ItemProperty –Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" –Name "DisableFirstRunCustomize" –PropertyType DWORD –Value 1 –Force
        
        # Get latest ThinInstaller  
        $TIDownloadURL = "https://download.lenovo.com/pccbbs/thinkvantage_en/lenovo_thininstaller_1.04.01.0004.exe"
        $TIFileName = $TIDownloadURL.Split('/')[-1]
        CMTraceLog –Message "Download URL is $TIDownloadURL" –Component "Download"
        Write-Host "Download URL is $TIDownloadURL" -ForegroundColor Green
        
        # Download ThinInstaller
        CMTraceLog –Message "Downloading Lenovo ThinInstaller" –Component "Download"
        Write-Host "Downloading Lenovo ThinInstaller" -ForegroundColor Green

        $Source = $TIDownloadURL
        $Destination = "$TempWorkFolder\$TIFileName"
        $WebClient = New-Object System.Net.WebClient
        $WebProxy = New-Object System.Net.WebProxy("http://proxy.domain.com:8080", $true)
        $Credentials = New-Object Net.NetworkCredential("user", "P@ssw0rd1", "domain.com")
        $Credentials = $Credentials.GetCredential("http://proxy.domain.com", "8080", "KERBEROS");
        $WebProxy.Credentials = $Credentials
        $WebClient.Proxy = $WebProxy
        $WebClient.DownloadFile($Source, $Destination)

        # Extract ThinInstaller
        CMTraceLog –Message "Installing Lenovo ThinInstaller" –Component "Install"
        Write-Host "Installing Lenovo ThinInstaller" -ForegroundColor Green
        Try {
            $Arguments = @(
                "/SP-",
                "/VERYSILENT",
                "/NORESTART"
            )
            $Process = Start-Process –FilePath $TempWorkFolder\$TIFileName –WorkingDirectory $TempWorkFolder –ArgumentList $Arguments –NoNewWindow –PassThru –Wait –ErrorAction Stop
            Start-Sleep –Seconds 5
            If (Test-Path -Path "C:\Program Files (x86)\Lenovo\ThinInstaller\ThinInstaller.exe") {
                CMTraceLog –Message "Installation complete" –Component "Install"
                Write-Host "Installation complete"
            } Else {
                CMTraceLog –Message "ThinInstaller not found!" –Component "Install" –Type 3
                Write-Host "ThinInstaller not found!" -ForegroundColor Red
                throw
            }
        }
        Catch {
            CMTraceLog –Message "Failed to install ThinInstaller: $($_.Exception.Message)" –Component "Install" –Type 3
            Write-Host "Failed to install ThinInstaller: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }

        ## Suspend BitLocker if Category BIOS is selected
        If ((($Category -eq "All") -or ($Category -eq "BIOS")) -and ($Action -eq "Install")) {
            CMTraceLog -Message "Category $Category and Action $Action selected. Try to suspend BitLocker." -Component "Preparation" -Type 2
            Write-Host "Category $Category and Action $Action selected. Try to suspend BitLocker." -ForegroundColor Yellow            
            Try {
                $BitLocker = Get-BitLockerVolume -MountPoint c:
                CMTraceLog -Message "BitLocker ProtectionStatus is $($BitLocker.ProtectionStatus)" -Component "Preparation" -Type 1
                Write-Host "BitLocker ProtectionStatus is $BitLocker" -ForegroundColor Green

                Try {
                    $BitLocker | Suspend-BitLocker -RebootCount 1 | Out-Null
                    CMTraceLog -Message "Suspended BitLocker RebootCount 1" -Component "Preparation" -Type 1
                    Write-Host "Suspended BitLocker RebootCount 1" -ForegroundColor Green
                } #Try
                Catch {
                    CMTraceLog -Message "Failed to suspend BitLocker. Exit script." -Component "Preparation" -Type 3
                    Write-Host "Suspended BitLocker RebootCount 1" -ForegroundColor Red
                    throw
                } #Catch
            } #Try
            Catch {
                CMTraceLog -Message "Failed to get BitLocker ProtectionStatus. Exit script." -Component "Preparation" -Type 3
                Write-Host "Failed to get BitLocker ProtectionStatus. Exit script." -ForegroundColor Red
            } #Catch
        } #If

        ## Install Updates with Lenovo ThinInstaller
        If ($Selection -eq "All") {$Selection = "A"}
        ElseIf ($Selection -eq "Critical") {$Selection = "C"}
        ElseIf ($Selection -eq "Recommended") {$Selection = "R"}

        Try {
            $Arguments = @(
                "/CM",
                "-search $Selection",
                "-action $Action",
                "-noicon",
                "-exporttowmi",
                "-includerebootpackages 1,3,4,5",
                "-noreboot",
                "-repository \\server\LenovoDriverRepository",
                "-log $LogFolder",
		"-debug"
            )
            
            If ($Packagetype -eq 'Application') { $PackageType = 1 }
            ElseIf ($Packagetype -eq 'Driver') { $PackageType = 2 }
            ElseIf ($Packagetype -eq 'Bios') { $PackageType = 3 }
            ElseIf ($Packagetype -eq 'Firmware') { $PackageType = 4 }
            If (!($Packagetype -eq 'All')) { $Arguments += "-packagetypes $Type" }

            CMTraceLog –Message "Running Thin Installer With Args: $Arguments" –Component "Update"
            Write-Host "Running Thin Installer With Args: $Arguments" -ForegroundColor Green

            $Process = Start-Process -FilePath "C:\Program Files (x86)\Lenovo\ThinInstaller\ThinInstaller.exe" –WorkingDirectory "C:\Program Files (x86)\Lenovo\ThinInstaller" –ArgumentList $Arguments –NoNewWindow –PassThru –Wait –ErrorAction Stop
        
            If ($Process.ExitCode -eq 0) {
                CMTraceLog –Message "Analysis complete" –Component "Update"
                Write-Host "Analysis complete" -ForegroundColor Green
            } ElseIf ($Process.ExitCode -eq 1) {
                CMTraceLog –Message "Exit $($Process.ExitCode) - Restart required." –Component "Update" –Type 2
                Write-Host "Exit $($Process.ExitCode) - Restart required." -ForegroundColor Green
                Exit 0
            } ElseIf ($Process.ExitCode -eq 10000) {
                CMTraceLog –Message "Exit $($Process.ExitCode) - No applicable updates found." –Component "Update" –Type 2
                Write-Host "Exit $($Process.ExitCode) - No applicable updates found." -ForegroundColor Green
                Exit 0
            } ElseIf ($Process.ExitCode -eq 10001) {
                CMTraceLog –Message "Exit $($Process.ExitCode) - Applicable updates found." –Component "Update" –Type 2
                Write-Host "Exit $($Process.ExitCode) - Applicable updates found." -ForegroundColor Green
                Exit 0
            } ElseIf ($Process.ExitCode -eq 20000) {
                CMTraceLog –Message "Exit $($Process.ExitCode) - All applicable packages were downloaded." –Component "Update" –Type 2
                Write-Host "Exit $($Process.ExitCode) - All applicable packages were downloaded." -ForegroundColor Green
                Exit 0
            } ElseIf ($Process.ExitCode -eq 20001) {
                CMTraceLog –Message "Exit $($Process.ExitCode) - Some applicable packages failed to download while others succeeded." –Component "Update" –Type 2
                Write-Host "Exit $($Process.ExitCode) - Some applicable packages failed to download while others succeeded." -ForegroundColor Green
                Exit 0
            } ElseIf ($Process.ExitCode -eq 20002) {
                CMTraceLog –Message "Exit $($Process.ExitCode) - Applicable packages were found but none were downloaded successfully." –Component "Update" –Type 2
                Write-Host "Exit $($Process.ExitCode) - Applicable packages were found but none were downloaded successfully." -ForegroundColor Green
                Exit 0
            } ElseIf ($Process.ExitCode -eq 20003) {
                CMTraceLog –Message "Exit $($Process.ExitCode) - No applicable updates were found to download." –Component "Update" –Type 2
                Write-Host "Exit $($Process.ExitCode) - No applicable updates were found to download." -ForegroundColor Green
                Exit 0
            } ElseIf ($Process.ExitCode -eq 3010) {
                CMTraceLog –Message "Exit $($Process.ExitCode) - ThinInstaller complete, requires Restart" –Component "Update" –Type 2
                Write-Host "Exit $($Process.ExitCode) - Thin Installer complete, requires Restart" -ForegroundColor Yellow
            } Else {
                CMTraceLog –Message "Process exited with code $($Process.ExitCode). Expecting 0." –Component "Update" –Type 3
                Write-Host "Process exited with code $($Process.ExitCode). Expecting 0." -ForegroundColor Yellow
                throw
            } #If
        } #Try
        Catch {
            CMTraceLog –Message "Failed to start the ThinInstaller.exe: $($_.Exception.Message)" –Component "Update" –Type 3
            Write-Host "Failed to start the ThinInstaller.exe: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }#Catch

        If ($Restart -eq "TRUE") {
            Write-Host "Triggering CM Restart"
            Restart-asCMComputer
        } #If
} #Function

Run-ThinInstaller -Action $Action -PackageType $PackageType -Selection $Selection -Restart $Restart
