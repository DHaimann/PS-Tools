[CmdletBinding()]

Param (
    [ValidateScript({Test-Path -Path $_ -PathType 'Leaf'})]
    [Parameter(Mandatory=$true)]
    $EvtxImportFile,

    [ValidateScript({Test-Path -Path $_ -PathType 'Leaf'})]
    [Parameter(Mandatory=$true)]
    $HashRuleDataFile,

    [ValidateScript({Test-Path -Path $_ -PathType 'Leaf'})]
    [Parameter(Mandatory=$false)]
    $UnTrustedHashesFile
)

Function Set-XMLElement {
    $Element = @"
            
@{
  RuleCollection = "Script";
  RuleName = "Hash: $HashSourceFileName";
  RuleDesc = "$HashPath";
  HashVal = "$HashDataString";
  FileName = "$HashSourceFileName"
}
"@

    Add-Content -Path $HashRuleDataFile -Value $Element -Force
} # Function

If ($UnTrustedHashesFile -ne $null -and $UnTrustedHashesFile -ne '') {
    # Import UnTrusted Signers File
    $UnTrustedHashes = (Import-Csv -Path $UnTrustedHashesFile -Delimiter ';').UnTrustedHashes
} Else {
    $UnTrustedHashes = ''
}

# Gather AppLocker file information
$Hashes = Get-AppLockerFileInformation -EventLog -LogPath $EvtxImportFile | Where-Object -FilterScript { ($_.Publisher -eq $null) -and ($_.Path -like "*.BAT" -or $_.Path -like "*.VBS") }

foreach ($Hash in $Hashes) {
    
    # Set Variables from Publisher
    $HashPath = $Hash.Path
    $HashDataString = $Hash.Hash.HashDataString
    $HashSourceFileName = $Hash.Hash.SourceFileName
            
    # Check if rule already exists in TrustedPublishers by publisher name
    $ExistingRule = Select-String -Path $HashRuleDataFile -Pattern $HashDataString -SimpleMatch -Quiet

    If ($ExistingRule) {
        Continue
    } ElseIf ($UnTrustedHashes.Contains($HashDataString)) {
        Continue
    } Else {
        Set-XMLElement
    }        
}