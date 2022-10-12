[CmdletBinding()]

Param (
    [ValidateScript({Test-Path -Path $_ -PathType 'Leaf'})]
    [Parameter(Mandatory=$true)]
    $EvtxImportFile,

    [ValidateScript({Test-Path -Path $_ -PathType 'Leaf'})]
    [Parameter(Mandatory=$true)]
    $TrustedSignersFile,

    [ValidateScript({Test-Path -Path $_ -PathType 'Leaf'})]
    [Parameter(Mandatory=$false)]
    $UnTrustedPublishersFile
)

Function Set-XMLElement {
    $Element = @"
            
@{
  label = "Publisher $PublisherPublisherProductName $PublisherPublisherBinaryName";
  PublisherName = "$PublisherPublisherName";
  RuleCollection = "Exe";
}
"@

    Add-Content -Path $TrustedSignersFile -Value $Element -Force
} # Function

# Import UnTrusted Signers File
$UnTrustedPublishers = (Import-Csv -Path $UnTrustedSignersFile -Delimiter ';').UnTrustedPublisher

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
    If ($PublisherPublisherBinaryName -eq $null -or $PublisherPublisherBinaryName -eq '') {
        If (!($PublisherPath -eq $null -or $PublisherPath -eq '')) {
            $Publisher.Publisher.BinaryName = $($PublisherPath.Split('\\')[-1])
            $PublisherPublisherBinaryName = $Publisher.Publisher.BinaryName
        } Else {
            $PublisherPublisherBinaryName = "Missing in Cert"
        }
    }

        
    [string]$PublisherPath = $Publisher.Path
    
    # Check if rule already exists in TrustedPublishers by publisher name
    $ExistingRule = Select-String -Path $TrustedSignersFile -Pattern $PublisherPublisherName -SimpleMatch -Quiet

    If ($ExistingRule) {
        Continue
    } ElseIf ($UnTrustedPublishers.Contains($PublisherPublisherName)) {
        Continue
    } Else {
        Set-XMLElement
    }        

}
