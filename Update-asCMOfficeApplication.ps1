Start-Transcript -Path "C:\Office Deployment Toolkit\Get-asOffice2019.log" -Force

# Set variables
$ODTPath = "C:\Office Deployment Toolkit"
$ODTSetup = "setup.exe"
$ODTSetupConfigXML = "configuration_Office2019-x64-Download.xml"
$ODTSetupArgs = @(
    "/download $ODTSetupConfigXML"
)
$SourceFolder = "Microsoft Office Professional Plus 2019 64-bit"

# Add variables to log file
Write-Output "Office Deployment Toolkit: $ODTPath"
Write-Output "Office Setup Executeable: $ODTSetup"
Write-Output "Configuration file: $ODTSetupConfigXML"
Write-Output "Setup Arguments: $ODTSetupArgs"
Write-Output "Source files folder: $SourceFolder"

# Download ODT
$ODTWebSource = 'https://www.microsoft.com/en-us/download/confirmation.aspx?id=49117'
$ODTWebDestination = 'C:\Temp\officedeploymenttool.exe'

Try {
    $Response = Invoke-WebRequest -UseBasicParsing -Uri $ODTWebSource -ErrorAction Stop
    $ODTUri = $Response.links | Where-Object {$_.outerHTML -like "*click here to download manually*"}
    $ODTURL = $ODTUri.href
    Write-Output $ODTURL
    Invoke-WebRequest -UseBasicParsing -Uri $ODTURL -OutFile $ODTWebDestination -Verbose
    Start-Process -FilePath $ODTWebDestination -ArgumentList "/quiet /extract:""$ODTPath""" -Wait
    Remove-Item -Path $ODTWebDestination -Force -Verbose
}

Catch {
    Write-Output "Couldn't download ODT"
    Wrire-Output "Use existing version"
}

# Delete old files
If (Test-Path -Path "$ODTPath\Office") {
    Write-Output "Cleanup old Office Files"
    Remove-Item -Path "$ODTPath\Office" -Recurse -Force -Verbose
}

# Download Office
Write-Output "Start Office download: $ODTSetup $ODTSetupArgs"
Set-Location -Path $ODTPath -Verbose

Try {
    $Download = Start-Process -FilePath $ODTSetup -ArgumentList $ODTSetupArgs -PassThru -Wait -ErrorAction Stop -Verbose
    $Download.WaitForExit()
}
Catch {
    Write-Output "Couldn't download Office... Exit"
    Stop-Transcript
    Exit 1
}

# Get Office version
$NewVersion = (Get-ChildItem -Path "$ODTPath\Office\Data" -Exclude "*.cab").Name
Write-Output "New Office Version: $NewVersion"

# Get Application version
Set-Location -Path "PS1:" -Verbose
$OfficeApp = Get-CMApplication -Name "Office Professional Plus 2019 64-bit" -Verbose

# App-Version
$OfficeAppVersion = $OfficeApp.SoftwareVersion

If ([Version]$NewVersion -gt [Version]$OfficeAppVersion) {
    $FullServerPath = "filesystem::\\fileserver\FileShare$\$SourceFolder"
    Write-Output $FullServerPath

    # Copy source files
    If (Test-Path -Path "$FullServerPath\Office") {
        Remove-Item -Path "$FullServerPath\Office" -Recurse -Force -Verbose
    }

    Copy-Item -Path "$ODTPath\Office" -Destination $FullServerPath -Container -Recurse -Force -Verbose
    Copy-Item -Path "$ODTPath\setup.exe" -Destination $FullServerPath -Force -Verbose

    # Save DeploymentType-XML in variable
    [XML]$SDMPackageXML = $OfficeApp.SDMPackageXML

    # Save DeploymentTypes in variable
    $DeploymentTypeName = $SDMPackageXML.AppMgmtDigest.DeploymentType.Title.'#text'

    # Save DeploymentType Arguments-Array in variable
    $Arguments = $SDMPackageXML.AppMgmtDigest.DeploymentType.Installer.DetectAction.Args.Arg

    # Get logical name of detection-method-clause in array MethodBody
    foreach ($Argument in $Arguments) {
        If ($Argument.Name -eq 'MethodBody') {
             [XML]$DetectAction = $Argument.'#text'
             $DetectionRuleLogicalName = $DetectAction.EnhancedDetectionMethod.Settings.SimpleSetting.LogicalName
             Write-Output $DetectionRuleLogicalName
        }
    }

    # Create new detection rule
    # Create new clause for detection rule
    $Clause = @{
        Hive = "LocalMachine"
        KeyName = "SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
        Is64Bit = $true
        PropertyType = "Version"
        ValueName = "ClientVersionToReport"
        Value = $true
        ExpectedValue = $NewVersion
        ExpressionOperator = "GreaterEquals"
    }

    Write-Output $Clause 
    $NewClause = New-CMDetectionClauseRegistryKeyValue @Clause -Verbose

    # Create new DeploymentType parameter
    $DeploymentType = @{
        Application = $OfficeApp
        DeploymentTypeName = "Office 365 Default Deployment Type"
        AddDetectionClause = $NewClause
        RemoveDetectionClause = $DetectionRuleLogicalName
    }

    Write-Output $DeploymentType

    # Refresh application
    Set-CMApplication -InputObject $OfficeApp -SoftwareVersion $NewVersion -ReleaseDate $(Get-Date)
    Set-CMScriptDeploymentType @DeploymentType -Verbose

    # refresh distribution point
    Update-CMDistributionPoint -ApplicationName "Office Professional Plus 2019 64-bit" -DeploymentTypeName $DeploymentTypeName -Confirm:$false
} Else {
    Write-Output "Application up-to-date."
}

Stop-Transcript
