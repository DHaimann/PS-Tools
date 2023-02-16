Function Set-asLenovoBiosSetting {
    [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$BiosSetting,
            [Parameter(Mandatory = $true)]
            [string]$Value
        )

    BEGIN {}

    PROCESS {
        $CheckSetting = Get-WmiObject -Namespace root\WMI -Class Lenovo_BiosSetting | Where-Object { $_.CurrentSetting -match "$BiosSetting" } | Select-Object CurrentSetting
        $CheckSettingName = $CheckSetting.CurrentSetting -split(',')
        $CheckSettingResult = $CheckSettingName[1] 
        Write-Output "Lenovo BIOS setting $($BiosSetting) has the value $($CheckSettingResult)"

        If ($($CheckSetting.CurrentSetting) -eq "$BiosSetting,$Value") {
            Write-Output "$($BiosSetting) already set to $($Value)"
            Write-Output "Doing nothing"
        } Else {
            Try {
                Write-Output "Set Lenovo BIOS Setting $($BiosSetting) to $($Value)"
                $WMIResult = (Get-WmiObject -Namespace root\WMI -Class Lenovo_SetBiosSetting).SetBiosSetting("$BiosSetting,$Value,$BIOSPassword,ascii,us").return
            }
            Catch {
                Write-Output "Error set Lenovo BIOS Setting $($BiosSetting) to $($Value)"
                Write-Output "Set result $($WMIResult)"
                Write-Output "Save result $($saveBios)"
            }
        }
        If ($WMIResult -eq "Success") {
            Write-Output "Successfully set Lenovo BIOS Setting $($BiosSetting) to $($Value)"
            Write-Output "Set result $($WMIResult)"
        }
    }

    END {
        Remove-Variable CheckSetting -Force -ErrorAction SilentlyContinue
        Remove-Variable CheckSettingName -Force -ErrorAction SilentlyContinue
        Remove-Variable CheckSettingResult -Force -ErrorAction SilentlyContinue 
        Remove-Variable WMIResult -Force -ErrorAction SilentlyContinue
    }
}

Function Save-asLenovoBiosSettings {
    BEGIN {}

    PROCESS {
        Write-Output "Save any outstanding BIOS configuration changes"

        Try {
                $saveBios = (Get-WmiObject -Namespace root\WMI -Class Lenovo_SaveBiosSettings).SaveBiosSettings("$BIOSPassword,ascii,us").return
            }
            Catch {
                Write-Output "Error saving Lenovo BIOS Settings"
                Write-Output "Save result $($saveBios)"
            }
        If ($saveBios -eq "Success") {
            Write-Output "Successfully save Lenovo BIOS settings"
            Write-Output "Save result $($saveBios)"
        }
    }

    END {
        Remove-Variable saveBios -Force -ErrorAction SilentlyContinue
    }
}

$TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment
$Global:BIOSPassword = $TSEnv.Value('BIOSPassword')

Write-Output "############################################"
Write-Output "### START Set Lenovo BIOS Settings"
Write-Output "############################################"

Set-asLenovoBiosSetting -BiosSetting LenovoCloudServices -Value Disable
Set-asLenovoBiosSetting -BiosSetting MACAddressPassThrough -Value Second
Set-asLenovoBiosSetting -BiosSetting TotalGraphicsMemory -Value 512MB
Set-asLenovoBiosSetting -BiosSetting VTdFeature -Value Enable
Set-asLenovoBiosSetting -BiosSetting SecureBoot -Value Enable
Set-asLenovoBiosSetting -BiosSetting UefiPxeBootPriority -Value IPv4First
Save-asLenovoBiosSettings

Write-Output "############################################"
Write-Output "### STOP Set Lenovo BIOS Settings"
Write-Output "############################################"