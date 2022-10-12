[CmdletBinding()]

Param (
    [ValidateScript({Test-Path -Path $_ -PathType 'Leaf'})]
    [Parameter(Mandatory=$true)]
    $EvtxImportFile,

    [ValidateScript({Test-Path -Path $_ -PathType 'Leaf'})]
    [Parameter(Mandatory=$true)]
    $TrustedSignersFile
)

Function Set-XMLElement {
    $Element = @"
            
@{
  label = "File: $PublisherPublisherBinaryName";
  PublisherName = "$PublisherPublisherName";
  RuleCollection = "Exe";
}
"@

    Add-Content -Path $TrustedSignersFile -Value $Element -Force
} # Function

# Gather AppLocker file information
$Publishers = Get-AppLockerFileInformation -EventLog -LogPath $EvtxImportFile | Where-Object -FilterScript { $_.Publisher -ne $null }

foreach ($Publisher in $Publishers) {
    
    # Set Variables from Publisher
    $PublisherPublisherName = $Publisher.Publisher.PublisherName
    $PublisherPublisherBinaryName = $Publisher.Publisher.BinaryName
    
    [string]$PublisherPath = $Publisher.Path
    
    # Check if rule already exists in TrustedPublishers by publisher name
    $ExistingRule = Select-String -Path $TrustedSignersFile -Pattern $PublisherPublisherName -SimpleMatch -Quiet

    If ($ExistingRule) {
        Continue
    } Else {
        Set-XMLElement
    }
}
