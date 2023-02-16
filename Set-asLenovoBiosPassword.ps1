# 2023.01 Dietmar Haimann

$TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment
$BIOSPassword = $TSEnv.Value('BIOSPassword')

Write-Output "#################################################"
Write-Output "### SET LENOVO BIOS SUPERVISOR PASSWORD START ###"
Write-Output "#################################################"

Write-Output "Checking to see if System Deployment Boot Mode is active..."
$CheckSDBM = (Get-WMIObject -Namespace root\WMI -Class Lenovo_SystemDeploymentBootMode).CurrentSetting
If ($CheckSDBM -ne "Enable") {
    Write-Output "System Deployment Boot Mode is not active. Stop Task Sequence with Exit 1"
    Exit 1
} Else { 
    Write-Output "System Deployment Boot Mode is avtive. Continue to set supervisor password."
}

Write-Output "Checking to see if a BIOS password is present..."

$PasswordState = (Get-WMIObject -Namespace root\WMI -Class Lenovo_BiosPasswordSettings).PasswordState
switch ($PasswordState) {
    0 { $returnMessage = "No passwords set" }
    2 { $returnMessage = "Supervisor password set" }
    3 { $returnMessage = "Power on and supervisor passwords set" }
    4 { $returnMessage = "Hard drive password(s) set" }
    5 { $returnMessage = "Power on and hard drive passwords set" }
    6 { $returnMessage = "Supervisor and hard drive passwords set" }
    7 { $returnMessage = "Supervisor, power on, and hard drive passwords set" }
}

Write-Output "Message from WMI: $returnMessage"

If ($PasswordState -eq 0) {
    Write-Output "No BIOS password is present. Set supervisor password..."
    
    Try {
        $SetSupervisorPassword = Get-WmiObject -Namespace root\WMI -Class Lenovo_setBiosPassword
        $Invocation = $SetSupervisorPassword.SetBiosPassword("pap,$BIOSPassword,$BIOSPassword,ascii,us").Return
    }
    Catch {
        Write-Output "Supervisor password not set. Error."
    }
    
    If ($Invocation -eq "Success") {
        Write-Output "Supervisor password set successfully."
        $TSEnv.Value('OSDBIOSPasswordStatus') = 2 # Supervisor password set
    }
    ElseIf ($Invocation -ne "Success") {
        Write-Output "Supervisor password is NOT configured. Output from WMI is: $Invocation"
        $TSEnv.Value('OSDBIOSPasswordStatus') = 0 # No passwords set
        Exit 1
    }
}

Write-Output "###############################################"
Write-Output "### SET LENOVO BIOS SUPERVISOR PASSWORD END ###"
Write-Output "###############################################"
