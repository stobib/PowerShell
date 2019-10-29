<# 
# This Script:        Niall Brady      - http://www.windows-noob.com
#                                      - 2016/12/6.
#                                      - Installs WSUS for ConfigMgr, SQL should be installed priot
#>
  If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] “Administrator”))

    {
        Write-Warning “You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!”
        Break
    }
$WSUSFolder = "E:\WSUS"
$SourceFiles = "E:\Sources\SXS"
$servername="CM01"
# create WSUS folder
if (Test-Path $WSUSFolder){
 write-host "The WSUS folder already exists."
 } else {

New-Item -Path $WSUSFolder -ItemType Directory
}
if (Test-Path $SourceFiles){
 write-host "Windows Server 2016 source files found"
 } else {

write-host "Windows Server 2016 source files not found, aborting"
break
}

Write-Host "Installing roles and features, please wait... "  -nonewline
Install-WindowsFeature -ConfigurationFilePath E:\Sources\scripts\DeploymentConfigTemplate_WSUS.xml -Source $SourceFiles
Start-Sleep -s 10
& ‘C:\Program Files\Update Services\Tools\WsusUtil.exe’ postinstall SQL_INSTANCE_NAME=$servername CONTENT_DIR=$WSUSFolder |out-file Null
write-host "All done !"