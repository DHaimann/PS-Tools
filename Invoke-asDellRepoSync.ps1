$FilePath = "C:\Temp\DellCatalog"
$Destination = "\\DriverRepo\Dell"
$Catalog = "$($FilePath)\Dell Driver Repository.xml" 

If ($FilePath -eq "") { Exit }

# First run
Try {
    $Execution = Start-Process -FilePath "cmd.exe" -ArgumentList "/C $($FilePath)\UpdateCatalogs.Maker.exe --catalog `"$($Catalog)`" --target `"$($Destination)`" --baseLocation `"$($Destination)`"" -Wait -ErrorAction Stop
}
Catch {
    Write-Host "Error $($Execution.ExitCode)"
    Exit $Execution.ExitCode
}

# Cleanup repository
# Get Repository xml
[xml]$XMLFile = Get-Content -Path "filesystem::\\DriverRepo\Dell\Dell Driver Repository.xml"
$Folders = @()

# Grab file for path names
$InventoryComponents = $XMLFile.Manifest.InventoryComponent.path
$SoftwareComponents = $XMLFile.Manifest.SoftwareComponent.path

# InventoryComponent
foreach ($Item in $InventoryComponents) {
    $Folders += $Item.Split('/')[0]
}

# SoftwareComponent
foreach ($Item in $SoftwareComponents) {
    $Folders += $Item.Split('/')[0]
}

# Get all paths in repository
$Repository = Get-ChildItem -Path "filesystem::\\DriverRepo\Dell" -Directory -Depth 0

# Check if included in array and delete if not
foreach ($Item in $Repository) {
    $ExistingFolder = Select-String -InputObject $Item.Name -SimpleMatch $Folders
    If (!($ExistingFolder)) {
        Try {
            Remove-Item -Path "filesystem::\\DriverRepo\Dell\$($Item.Name)" -Recurse -Force
            Write-Host "Successfully removed obsolete folder $($Item.Name)"
        }

        Catch {
            Write-Host "Could'nt delete folder $($Item.Name)"
            continue
        }
    }
}
