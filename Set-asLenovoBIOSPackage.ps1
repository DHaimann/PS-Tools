$Repository = "\\server\LenovoDriverRepository`$"
[xml]$Database = Get-Content -Path "$Repository\database.xml"
$BIOS = $Database.Database.Package | Where -FilterScript { $_.Name -match "BIOS" }

foreach ($Item in $BIOS) {
    $FilePath = $Item.LocalPath
    $XMLFile = Join-Path -Path $Repository -ChildPath $FilePath
    [xml]$XMLContent = Get-Content -Path $XMLFile
    $Node = $XMLContent.Package.Reboot
    $Node.SetAttribute("type", 3)
    $XMLContent.Save($XMLFile)
}
