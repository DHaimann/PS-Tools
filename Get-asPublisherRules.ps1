[CmdletBinding()]

Param (
    [ValidateScript({Test-Path -Path $_ -PathType 'Leaf'})]
    [Parameter(Mandatory=$true)]
    $EvtxImportFile,

    [ValidateScript({Test-Path -Path $_ -PathType 'Leaf'})]
    [Parameter(Mandatory=$false)]
    $UnTrustedPublishersFile
)

Function Set-XMLElement {
    # Create new File Publisher Rule
    $NewFilePublisherRule = $RuleCollection.AppLockerPolicy.RuleCollection.AppendChild($RuleCollection.CreateElement('FilePublisherRule'))
    $NewFilePublisherRule.SetAttribute('Id', $FilePublisherRule.Id)
    $NewFilePublisherRule.SetAttribute('Name', "Publisher: $PublisherPublisherName - File: $PublisherPublisherBinaryName")
    $NewFilePublisherRule.SetAttribute('Description', "Product: $PublisherPublisherProductName - Found in: $PublisherPath")
    $NewFilePublisherRule.SetAttribute('UserOrGroupSid', 'S-1-1-0')
    $NewFilePublisherRule.SetAttribute('Action', 'Allow')
    
    # Create new Conditions
    $NewConditions = $NewFilePublisherRule.AppendChild($RuleCollection.CreateElement('Conditions'))
       
    # Create new Publisher Condition
    $NewFilePublisherCondition = $NewConditions.AppendChild($RuleCollection.CreateElement('FilePublisherCondition'))
    $NewFilePublisherCondition.SetAttribute('PublisherName', $PublisherPublisherName)
    $NewFilePublisherCondition.SetAttribute('ProductName', '*')
    $NewFilePublisherCondition.SetAttribute('BinaryName', '*')
    
    # Create new BinaryVersionRange
    $NewBinaryVersionRange = $NewFilePublisherCondition.AppendChild($RuleCollection.CreateElement('BinaryVersionRange'))
    $NewBinaryVersionRange.SetAttribute('LowSection', '*')
    $NewBinaryVersionRange.SetAttribute('HighSection', '*')
} # Function

# Import UnTrusted Signers File
$UnTrustedPublishers = (Import-Csv -Path $UnTrustedSignersFile -Delimiter ';').UnTrustedPublisher

# Create PublisherRules.xml
$XMLPath = "C:\Util\AppLocker\PublisherRules.xml"

If (!(Test-Path -Path $XMLPath)) {
    New-Item -Path $XMLPath -ItemType File -Force

    $StandardXMLFile = [xml]@"
        <AppLockerPolicy Version="1">
            <RuleCollection Type="Exe" EnforcementMode="NotConfigured">
            </RuleCollection>
        </AppLockerPolicy>
"@

    $StandardXMLFile.Save($XMLPath)
}

# Read content of PublisherRules.xml
[xml]$RuleCollection = Get-Content -Path $XMLPath

# Gather AppLocker file information
$Publishers = Get-AppLockerFileInformation -EventLog -LogPath $EvtxImportFile | Where-Object -FilterScript { $_.Publisher -ne $null }

foreach ($Publisher in $Publishers) {
    
    # Set Variables from Publisher
    $PublisherPublisherName = $Publisher.Publisher.PublisherName
    $PublisherPublisherProductName = $Publisher.Publisher.ProductName
    $PublisherPublisherBinaryName = $Publisher.Publisher.BinaryName
    $PublisherPublisherBinaryVersion = $Publisher.Publisher.BinaryVersion
    
    [string]$PublisherPath = $Publisher.Path
    
    # Workaround for missing product name and binary for lazy developers
    If ($PublisherPublisherProductName -eq $null -or $PublisherPublisherProductName -eq '') {
        If (!($PublisherPath -eq $null -or $PublisherPath -eq '')) { 
            $Publisher.Publisher.ProductName = $(($PublisherPath.Split('\\')[-1]).Split('.')[0])
            $PublisherPublisherProductName = $Publisher.Publisher.ProductName
        } Else {
            $PublisherPublisherProductName = "Missing in Cert"
        }
    }

    If ($PublisherPublisherBinaryName -eq $null -or $PublisherPublisherBinaryName -eq '') {
        If (!($PublisherPath -eq $null -or $PublisherPath -eq '')) {
            $Publisher.Publisher.BinaryName = $($PublisherPath.Split('\\')[-1])
            $PublisherPublisherBinaryName = $Publisher.Publisher.BinaryVersion
        } Else {
            $PublisherPublisherBinaryName = "Missing in Cert"
        }
    }

    # Generate AppLocker policy
    Try {
        [xml]$Policy = New-AppLockerPolicy -FileInformation $Publisher -RuleType Publisher -RuleNamePrefix Publisher -User Jeder -Xml -Optimize -ErrorAction Stop
    }
    Catch {
        Write-Host "Could not create AppLocker Policy for $PublisherPublisherName!" -ForegroundColor Red
        Continue
    }    

    # Set variables
    $RuleNamePrefix = "Publisher: "
    $FilePublisherRule = $Policy.AppLockerPolicy.RuleCollection.FilePublisherRule
    $FilePublisherCondition = $FilePublisherRule.Conditions.FilePublisherCondition
    $RuleCollectionPublisherNames = $RuleCollection.AppLockerPolicy.RuleCollection.FilePublisherRule.Conditions.FilePublisherCondition.PublisherName
    
    # Check if PublisherRules.xml is empty
    If (!($RuleCollectionPublisherNames -eq $null)) {
        # Check if rule already exists
        If ($RuleCollectionPublisherNames.Contains($PublisherPublisherName)) {
            Write-Host "Already exists: $PublisherPublisherName" -ForegroundColor Yellow
            Continue
        } ElseIf ($UnTrustedPublishers.Contains($PublisherPublisherName)) {
            Write-Host "Untrusted publisher: $PublisherPublisherName" -ForegroundColor Red
            Continue
        } Else {
            Set-XMLElement
        }
    } Else {
        Set-XMLElement
    }
}

# Save PublisherRules.xml
$RuleCollection.Save($XMLPath)
