<# Run-HPIA Run Script
Gary Blok - GARYTOWN.COM
When you create the Run Script, add a List for the variables and populate them with the validateset you see below.
Please note, you will get A LOT of data returned in the Run Script Dialog.  Feel free to remove some of the Write-Hosts.  This was orginally written for other deployment methods.

This script is entirely based on Run-HPIA by Gary Blok. I was just trying to customize the script for Dell Command Update. Credit goes to Gary Blok and his great work!
How to use this script see https://garytown.com/run-scripts-run-hpia
#>


[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [ValidateSet("scan", "applyUpdates")]
        $Action = "scan",
        [Parameter(Mandatory=$false)]
        [ValidateSet("all", "bios", "driver", "firmware")]
        $Type = "driver",
        [Parameter(Mandatory=$false)]
        [ValidateSet("all", "audio", "video", "network", "storage", "input", "chipset", "others")]
        $Category = "all",        
        [Parameter(Mandatory=$false)]
        [ValidateSet("all", "security", "critical", "recommended", "optional")]
        $Severity = "all",
        [Parameter(Mandatory=$false)]
        [ValidateSet("FALSE", "TRUE")]
        [string]$Restart = "FALSE"
    )

Function Run-DCU {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [ValidateSet("scan", "applyUpdates")]
        $Action = "scan",
        [Parameter(Mandatory=$false)]
        [ValidateSet("all", "bios", "driver", "firmware")]
        $Type = "driver",
        [Parameter(Mandatory=$false)]
        [ValidateSet("all", "audio", "video", "network", "storage", "input", "chipset", "others")]
        $Category = "all",        
        [Parameter(Mandatory=$false)]
        [ValidateSet("all", "security", "critical", "recommended", "optional")]
        $Severity = "all",
        [Parameter(Mandatory=$false)]
        $LogFolder = "$env:systemdrive\ProgramData\Dell\Logs",
        [Parameter(Mandatory=$false)]
        $ReportsFolder = "$env:systemdrive\ProgramData\Dell\DCU",
        [Parameter(Mandatory=$false)]
        [ValidateSet("FALSE", "TRUE")]
        $Restart = "FALSE"
    )

        # Parameter
        $DellCommandWebUrl = "https://www.dell.com/support/home/de-at/drivers/DriversDetails?driverId=T97XP"
        $ProgressPreference = 'SilentlyContinue' # to speed up web requests

        # Create Directory Structure
        $DateTime = Get-Date –Format "yyyyMMdd-HHmmss"
        $ReportsFolder = "$ReportsFolder\$DateTime"
        $DCULogFile = "$LogFolder\Run-DCU.log"
        $script:TempWorkFolder = "$env:TEMP\DCU"
        
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
		        $LogFile = $DCULogFile
	        )

	        $Time = Get-Date -Format "HH:mm:ss.ffffff"
	        $Date = Get-Date -Format "MM-dd-yyyy"
	        If ($ErrorMessage -ne $null) {$Type = 3}
	        If ($Component -eq $null) {$Component = " "}
	        If ($Type -eq $null) {$Type = 1}
	        $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
	        $LogMessage.Replace("`0","") | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        } #Function CMTrace

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

        CMTraceLog –Message "###################" –Component "Preparation"
        CMTraceLog –Message "## Invoke-asDCU ##" –Component "Preparation"
        CMTraceLog –Message "###################" –Component "Preparation"        
        Write-Host "Starting Dell Command Update to Update Dell Drivers" -ForegroundColor Magenta
 
        # Check Dell Device
        Try {
            $Manufacturer = (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer
            If (!($Manufacturer -like "Dell*")) {
               CMTraceLog –Message "Manufacturer not Dell. Exit Script." –Component "Preparation" -Type 3
               Write-Host "Manufacturer not Dell. Exit script." -ForegroundColor Red
               throw
            } Else {
               CMTraceLog –Message "Manufacturer Dell detected. Continue." –Component "Preparation" -Type 1
               Write-Host "Manufacturer Dell detected. Continue." -ForegroundColor Green
            }
        }
        Catch {
            CMTraceLog –Message "Failed to to get Manufacturer. Exit script." –Component "Preparation" -Type 3
            Write-Host "Failed to to get Manufacturer. Exit script." -ForegroundColor Red
            throw
        }

        #############
        ## Check if DCU is already installed
        #############
        ## Check version is on my to-do list
        #############

        If (!(Test-Path -LiteralPath 'C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe')) {               
 
            # Disable IE First Run Wizard
            CMTraceLog –Message "Disabling IE first run wizard" –Component "Preparation"
            $null = New-Item –Path "HKLM:\SOFTWARE\Policies\Microsoft" –Name "Internet Explorer" –Force
            $null = New-Item –Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer" –Name "Main" –Force
            $null = New-ItemProperty –Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" –Name "DisableFirstRunCustomize" –PropertyType DWORD –Value 1 –Force
        
            # Set proxy settings
            $Proxy = "http://proxy.domain.com:8080"
            $Username = "user@domain.com"
            $Password = ConvertTo-SecureString 'password' -AsPlainText -Force
            $Credentials = New-Object System.Management.Automation.PSCredential ("$Username", $Password)

            CMTraceLog –Message "Finding info for latest version of Dell Command Update (DCU)" –Component "Download"
        
            Try {
                $HTML = Invoke-WebRequest –Uri $DellCommandWebUrl -Proxy $Proxy -ProxyCredential $Credentials -UseBasicParsing -ErrorAction Stop
            }
            Catch {
                CMTraceLog –Message "Failed to download the DCU web page. $($_.Exception.Message)" –Component "Download" -Type 3
                throw
            }

            $DellCommandDownloadURL = ($HTML.Links | Where-Object {$_.href -match "Dell-Command-Update-"}).href
            $DellCommandFileName = $DellCommandDownloadURL.Split('/')[-1]
            CMTraceLog –Message "Download URL is $DellCommandDownloadURL" –Component "Download"
            Write-Host "Download URL is $DellCommandDownloadURL" -ForegroundColor Green
        
            # Download Dell Command Update
            CMTraceLog –Message "Downloading Dell Command Update" –Component "DownloadDCU"
            Write-Host "Downloading Dell Command Update" -ForegroundColor Green

            $Source = $DellCommandDownloadURL
            $Destination = "$TempWorkFolder\$DellCommandFileName"
            $WebClient = New-Object System.Net.WebClient
            $WebProxy = New-Object System.Net.WebProxy("http://proxy.domain.com:8080", $true)
            $Credentials = New-Object Net.NetworkCredential("user", "password", "domain")
            $Credentials = $Credentials.GetCredential("http://proxy.domain.com", "8080", "KERBEROS");
            $WebProxy.Credentials = $Credentials
            $WebClient.Proxy = $WebProxy
            $WebClient.DownloadFile($Source, $Destination)

            # Extract Dell Command Update
            CMTraceLog –Message "Extracting Dell Command Update" –Component "Preparation"
            Write-Host "Extracting Dell Command Update" -ForegroundColor Green
            
            Try {
                $Arguments = @(
                    "/s",
                    "/e=""$TempWorkFolder\dcu""",
                    "/l=""$LogFolder\Install-DCU.log"""
                )

                $Process = Start-Process –FilePath $TempWorkFolder\$DellCommandFileName –WorkingDirectory $TempWorkFolder –ArgumentList $Arguments –NoNewWindow –PassThru –Wait –ErrorAction Stop
                Start-Sleep -Seconds 5
                # Get name of Dell Command Update installer
                $DCUInstaller = (Get-ChildItem -Path "$TempWorkFolder\dcu" -Filter *.exe).Name
                CMTraceLog –Message "Extracted installer $DCUInstaller" –Component "Preparation"
                Write-Host "Extracted installer $DCUInstaller" -ForegroundColor Green
            }
            Catch {
                CMTraceLog –Message "Failed to extract the DCU: $($_.Exception.Message)" –Component "Preparation" –Type 3
                Write-Host "Failed to extract the DCU: $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
     
            # Install Dell Command Update
            CMTraceLog –Message "Installing Dell Command Update" –Component "InstallDCU"
            Write-Host "Installing Dell Command Update" -ForegroundColor Green
            
            Try {
                $Arguments = @(
                    "/s",
                    "/v""/qn"""
                )
                
                $Process = Start-Process –FilePath "$TempWorkFolder\dcu\$DCUInstaller" –WorkingDirectory "$TempWorkFolder\dcu" –ArgumentList $Arguments –NoNewWindow –PassThru –Wait –ErrorAction Stop
                Start-Sleep –Seconds 5
                # Test installation
                If (Test-Path 'C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe') {
                    CMTraceLog –Message "Installation complete" –Component "InstallDCU"
                } Else {
                    CMTraceLog –Message "Dell Command Update not found. Exit Script." –Component "InstallDCU" –Type 3
                    Write-Host "Dell Command Update not found. Exit Script." -ForegroundColor Red
                    throw
                } #If
            } #Try
            Catch {
                CMTraceLog –Message "Failed to install the DCU: $($_.Exception.Message)" –Component "Preparation" –Type 3
                Write-Host "Failed to install the DCU: $($_.Exception.Message)" -ForegroundColor Red
                throw
            } #Catch
        } #If

        ############
        ## Installation of Dell Command Update done
        ############
        ## Configure Dell Command Update
        ############

        CMTraceLog –Message "Configure Dell Command Update" –Component "ConfigurationDCU"
        Write-Host "Configure Dell Command Update" -ForegroundColor Green
        
        Try {
            $DCUCLIPath = 'C:\Program Files (x86)\Dell\CommandUpdate'
            $DCUCLI = 'dcu-cli.exe'
            
            $Arguments = @(
                "/configure",
                "-customProxy=enable",
                "-proxyAuthentication=enable",
                "-proxyHost=proxy.domain.com",
                "-proxyPort=8080",
                "-proxyUserName=""user@domain.com""",
                "-proxyPassword=""password""",
                "-autoSuspendBitLocker=enable",
                "-userConsent=disable",
                "-updatesNotification=disable",
                "-silent"        
            )

            $Process = Start-Process –FilePath $DCUCLIPath\$DCUCLI –WorkingDirectory $DCUCLIPath –ArgumentList $Arguments –NoNewWindow –PassThru –Wait –ErrorAction Stop
            Start-Sleep –Seconds 5
            
            CMTraceLog –Message "Successfully configured Dell Command Update" –Component "ConfigurationDCU"
            Write-Host "Successfully configured Dell Command Update" -ForegroundColor Green
        } #Try
        Catch {
            CMTraceLog –Message "Failed to configure the DCU: $($_.Exception.Message)" –Component "ConfigurationDCU" –Type 3
            Write-Host "Failed to configure the DCU: $($_.Exception.Message)" -ForegroundColor Red
            throw
        } #Catch   
        
        #########
        ## Suspend BitLocker if type BIOS is selected
        ## DCU should do this but I have to test...
        #########

        If (($Type -eq "bios") -and ($Action -eq "applyUpdates")) {
            CMTraceLog -Message "Type $Type and Action $Action selected. Try to suspend BitLocker." -Component "BitLocker" -Type 2
            Write-Host "Type $Type and Action $Action selected. Try to suspend BitLocker." -ForegroundColor Yellow            
            Try {
                $BitLocker = Get-BitLockerVolume -MountPoint c:
                CMTraceLog -Message "BitLocker ProtectionStatus is $($BitLocker.ProtectionStatus)" -Component "BitLocker" -Type 1
                Write-Host "BitLocker ProtectionStatus is $BitLocker" -ForegroundColor Green

                Try {
                    $BitLocker | Suspend-BitLocker -RebootCount 1 | Out-Null
                    CMTraceLog -Message "Suspended BitLocker RebootCount 1" -Component "BitLocker" -Type 1
                    Write-Host "Suspended BitLocker RebootCount 1" -ForegroundColor Green
                } #Try
                Catch {
                    CMTraceLog -Message "Failed to suspend BitLocker. Exit script." -Component "BitLocker" -Type 3
                    Write-Host "Suspended BitLocker RebootCount 1" -ForegroundColor Red
                    throw
                } #Catch
            } #Try
            Catch {
                CMTraceLog -Message "Failed to get BitLocker ProtectionStatus. Exit script." -Component "BitLocker" -Type 3
                Write-Host "Failed to get BitLocker ProtectionStatus. Exit script." -ForegroundColor Red
            } #Catch
        } #If

        #########
        ## Scan and / or install Updates with Dell Command Update
        #########
        
        Try {
            ##########
            ## Always run a scan to get the list of recommended drivers
            ##########

            $Arguments = @(
                "/scan",
                "-silent",
                "-outputLog=$ReportsFolder\scan.log",
                "-report=$ReportsFolder"                   
            )

            If (!($Type -eq 'all')) { $Arguments += "-updateType=$Type" } Else { $Arguments += "-updateType=bios,driver,firmware" }
            If (!($Severity -eq 'all')) { $Arguments += "-updateSeverity=$Severity" }
            If (!($Category -eq 'all')) { $Arguments += "-updateDeviceCategory=$Category" }
            
            CMTraceLog –Message "Running DCU With Args for: /scan" –Component "Scan"
            Write-Host "Running DCU With Args for: /scan" -ForegroundColor Green

            $Process = Start-Process –FilePath $DCUCLIPath\$DCUCLI –WorkingDirectory $DCUCLIPath –ArgumentList $Arguments –NoNewWindow –PassThru –Wait –ErrorAction Stop
            Start-Sleep -Seconds 5
        } #Try
        Catch {
            CMTraceLog –Message "Exit $($Process.ExitCode)" –Component "Update" –Type 2
            Write-Host "Exit $($Process.ExitCode)" -ForegroundColor Green
            Exit 0
        } #Catch

        #############
        ## Generate report
        #############
       
        CMTraceLog –Message "Reading xml report" –Component "Report"    
        Try {
            $XMLFile = Get-ChildItem –Path $ReportsFolder –Recurse –Include *.xml –ErrorAction Stop
            If ($XMLFile) {
                CMTraceLog –Message "Report located at $($XMLFile.FullName)" –Component "Report"
                Try {
                    [xml]$XML = Get-Content –Path $XMLFile.FullName –ErrorAction Stop
                    $AllUpdates = $xml.updates.update
                
                    ########## BIOS
                    If ($Type -eq "bios" -or $Type -eq "all") {
                        CMTraceLog –Message "Checking BIOS Recommendations" –Component "Report"
                        Write-Host "Checking BIOS Recommendations" -ForegroundColor Green 
                        $null = $Recommendation
                        $Recommendation = $AllUpdates | Where-Object { $_.type -eq "BIOS" } 
                    
                        If ($Recommendation) {
                            $ItemName = $Recommendation.name
                            $CurrentBIOSVersion = (Get-WmiObject -Class Win32_BIOS).SMBIOSBIOSVersion
                            $ReferenceBIOSVersion = $Recommendation.version
                            $DownloadURL = "https://dl.dell.com/" + $Recommendation.file
                            $FileName = $DownloadURL.Split('/')[-1]
                            CMTraceLog –Message "Component: $ItemName" –Component "Report"
                            Write-Host " Component: $ItemName" -ForegroundColor Gray                           
                            CMTraceLog –Message " Current version is $CurrentBIOSVersion" –Component "Report"
                            Write-Host " Current version is $CurrentBIOSVersion" -ForegroundColor Gray
                            CMTraceLog –Message " Recommended version is $ReferenceBIOSVersion" –Component "Report"
                            Write-Host " Recommended version is $ReferenceBIOSVersion" -ForegroundColor Gray
                            CMTraceLog –Message " Download URL is $DownloadURL" –Component "Report"
                            #Write-Host "Download URL is $DownloadURL" -ForegroundColor Gray
                        } Else {
                            CMTraceLog –Message "No BIOS recommendation in the XML report" –Component "Report" –Type 2
                            Write-Host " No BIOS recommendation in XML" -ForegroundColor Gray
                        } #If
                    } #If
                    ########## BIOS

                    ########## DRIVER
                    If ($Type -eq "driver" -or $Type -eq "all") {
                        CMTraceLog –Message "Checking Driver Recommendations" –Component "Report"
                        Write-Host "Checking Driver Recommendations" -ForegroundColor Green                
                        $null = $Recommendation
                        $Recommendation = $AllUpdates | Where-Object { $_.type -eq "Driver" } 

                        If ($Recommendation) {
                            foreach ($item in $Recommendation) {
                                $ItemName = $item.name
                                #$CurrentBIOSVersion = $item.TargetVersion
                                $ReferenceBIOSVersion = $item.version
                                $DownloadURL = "https://dl.dell.com/" + $item.file
                                $FileName = $DownloadURL.Split('/')[-1]
                                CMTraceLog –Message "Component: $ItemName" –Component "Report"
                                Write-Host " Component: $ItemName" -ForegroundColor Gray                           
                                #CMTraceLog –Message " Current version is $CurrentBIOSVersion" –Component "Report"
                                #Write-Host "Current version is $CurrentBIOSVersion" -ForegroundColor Gray
                                CMTraceLog –Message " Recommended version is $ReferenceBIOSVersion" –Component "Report"
                                Write-Host " Recommended version is $ReferenceBIOSVersion" -ForegroundColor Gray
                                CMTraceLog –Message " Download URL is $DownloadURL" –Component "Report"
                                #Write-Host "Download URL is $DownloadURL" -ForegroundColor Gray
                            }
                        } Else {
                            CMTraceLog –Message "No Driver recommendation in the XML report" –Component "Report" –Type 2
                            Write-Host " No Driver recommendation in XML" -ForegroundColor Gray
                        } #If
                    } #If
                    ########## DRIVER
                    
                    ########## FIRMWARE
                    If ($Type -eq "firmware" -or $Type -eq "all") {
                        CMTraceLog –Message "Checking Firmware Recommendations" –Component "Report"
                        Write-Host "Checking Firmware Recommendations" -ForegroundColor Green                
                        $null = $Recommendation
                        $Recommendation = $AllUpdates | Where-Object { $_.type -eq "Firmware" } 
                        
                        If ($Recommendation) {
                            foreach ($item in $Recommendation) {
                                $ItemName = $item.name
                                #$CurrentBIOSVersion = $item.TargetVersion
                                $ReferenceBIOSVersion = $item.version
                                $DownloadURL = "https://dl.dell.com/" + $item.file
                                $FileName = $DownloadURL.Split('/')[-1]
                                CMTraceLog –Message "Component: $ItemName" –Component "Report"
                                Write-Host " Component: $ItemName" -ForegroundColor Gray                           
                                #CMTraceLog –Message " Current version is $CurrentBIOSVersion" –Component "Report"
                                #Write-Host "Current version is $CurrentBIOSVersion" -ForegroundColor Gray
                                CMTraceLog –Message " Recommended version is $ReferenceBIOSVersion" –Component "Report"
                                Write-Host " Recommended version is $ReferenceBIOSVersion" -ForegroundColor Gray
                                CMTraceLog –Message " Download URL is $DownloadURL" –Component "Report"
                                #Write-Host "Download URL is $DownloadURL" -ForegroundColor Gray
                            }
                        } Else {
                            CMTraceLog –Message "No Firmware recommendation in the XML report" –Component "Report" –Type 2
                            Write-Host " No Firmware recommendation in XML" -ForegroundColor Gray
                        } #If
                    } #If            
                    ########## FIRMWARE

                } #Try
                Catch {
                    CMTraceLog –Message "Failed to parse the XML file: $($_.Exception.Message)" –Component "Report" –Type 3
                } #Catch
            } Else {
                CMTraceLog –Message "Failed to find an XML report." –Component "Report" –Type 3
                Write-Host "Failed to find an XML report." -ForegroundColor Yellow
            } #If
        } #Try
        Catch {
            CMTraceLog –Message "Failed to find an XML report: $($_.Exception.Message)" –Component "Report" –Type 3
            Write-Host "Failed to find an XML report: $($_.Exception.Message)" -ForegroundColor Yellow
        } #Catch

        ###########
        ## Run Action applyUpdates after report if selected
        ###########

        If ($Action -eq 'applyUpdates') {
            Try {
                $Arguments = @(
                    "/applyUpdates",
                    "-silent",
                    "-outputLog=$ReportsFolder\update.log",
                    "-reboot=disable",
                    "-encryptedPassword=AZEUCALUIsdfasdfvqfqaretzbwerujbvwK3SiOVUFy5ndIX3mzEya0vzi/nzvRjWDH/eCY0S2w==",
                    "-encryptionKey=fqWWE22!vrever"                                       
                )

                If (!($Type -eq 'all')) { $Arguments += "-updateType=$Type" } Else { $Arguments += "-updateType=bios,driver,firmware" }
                If (!($Severity -eq 'all')) { $Arguments += "-updateSeverity=$Severity" }
                If (!($Category -eq 'all')) { $Arguments += "-updateDeviceCategory=$Category" }
                
                CMTraceLog –Message "Running DCU With Args for: /applyUpdates" –Component "applyUpdates"
                Write-Host "Running DCU With Args for: /applyUpdates" -ForegroundColor Green

                $Process = Start-Process –FilePath $DCUCLIPath\$DCUCLI –WorkingDirectory $DCUCLIPath –ArgumentList $Arguments –NoNewWindow –PassThru –Wait –ErrorAction Stop
                Start-Sleep -Seconds 5
                CMTraceLog –Message "Successfully installed updates." –Component "applyUpdates" –Type 2
                Write-Host "Successfully installed updates." -ForegroundColor Green
            } #Try
            Catch {
                CMTraceLog –Message "Exit $($Process.ExitCode)" –Component "applyUpdates" –Type 2
                Write-Host "Exit $($Process.ExitCode)" -ForegroundColor Green
                Exit 0
            } #Catch
        } #If

        ##########
        ## Trigger restart
        ##########

        If ($Restart -eq "TRUE") {
            Write-Host "Triggering CM Restart"
            Restart-asCMComputer
        } #If

} #Function

Run-DCU -Action $Action -Type $Type -Category $Category -Severity $Severity -Restart $Restart
