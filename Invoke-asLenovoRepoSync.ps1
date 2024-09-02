# Requirement: Download script from https://github.com/CDRT/Library/tree/master/get-lnvupdatesrepo

$Date = Get-Date -Format yy-MM-dd
$Log = "$Date-LnvUpdatesRepo.log"

$Parameters = @{
    MachineTypes = '21C2,21H2,40AY'
    OS = '11'
    PackageTypes = '1,2,3,4'
    RebootTypes = '0,3,5'
    RepositoryPath = 'C:\Repository\Lenovo'
    LogPath = "C:\Repository\Lenovo\$Log"
}

. C:\Tools\DriverRepositories\Get-LnvUpdatesRepo.ps1 -RT5toRT3 @Parameters
