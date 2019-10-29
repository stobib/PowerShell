<# 
# This Script:        Niall Brady      - http://www.windows-noob.com
#                                      - 2016/12/6.
#                                      - Installs SQL Server 2016 with Management Studio from here http://go.microsoft.com/fwlink/?linkid=832812
#                                      - copy the SSMS (Management Studio) file to $folderpath\SSMS-Setup-ENU.exe in advance if you don't want the script to download it
#>
If(-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]“Administrator”)){
    Write-Warning “You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!”
    Break
}
# User define variables
$ProgFileDir="Program Files"
$DataDrive="F:\$ProgFileDir"
$LogsDrive="G:\$ProgFileDir"
$TempDrive="H:\$ProgFileDir"
$BckpDrive="I:\$ProgFileDir"
# below variables are customizable
$folderpath="C:\Scripts"
$inifile="$folderpath\ConfigurationFile.ini"
# next line sets user as a SQL sysadmin
$userDomain=$env:USERDOMAIN
$yourusername="$userDomain\zasvccm_naa"
# path to the SQL media
$SQLsource="D:\"
# configurationfile.ini settings https://msdn.microsoft.com/en-us/library/ms144259.aspx
$ACTION="Install"
$ASCOLLATION="Latin1_General_CI_AS"
$ErrorReporting="False"
$SUPPRESSPRIVACYSTATEMENTNOTICE="False"
$IACCEPTROPENLICENSETERMS="False"
$ENU="True"
$QUIET="True"
$QUIETSIMPLE="False"
$UpdateEnabled="True"
$USEMICROSOFTUPDATE="False"
$FEATURES="SQLENGINE,RS,CONN,IS,BC,SDK,BOL"
$UpdateSource="MU"
$HELP="False"
$INDICATEPROGRESS="False"
$X86="False"
$INSTANCENAME="SCCM"
$INSTALLSHAREDDIR="E:\Program Files\Microsoft SQL Server"
$INSTALLSHAREDWOWDIR="E:\Program Files (x86)\Microsoft SQL Server"
$INSTANCEID="MSSQLSERVER"
$RSINSTALLMODE="DefaultNativeMode"
$SQLTELSVCACCT="NT Service\SQLTELEMETRY"
$SQLTELSVCSTARTUPTYPE="Automatic"
$ISTELSVCSTARTUPTYPE="Automatic"
$ISTELSVCACCT="NT Service\SSISTELEMETRY130"
$INSTANCEDIR="E:\Program Files\Microsoft SQL Server"
$AGTSVCACCOUNT="NT AUTHORITY\SYSTEM"
$AGTSVCSTARTUPTYPE="Automatic"
$ISSVCSTARTUPTYPE="Disabled"
$ISSVCACCOUNT="NT AUTHORITY\System"
$COMMFABRICPORT="0"
$COMMFABRICNETWORKLEVEL="0"
$COMMFABRICENCRYPTION="0"
$MATRIXCMBRICKCOMMPORT="0"
$SQLSVCSTARTUPTYPE="Automatic"
$FILESTREAMLEVEL="0"
$ENABLERANU="False"
$SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS"
$SQLSVCACCOUNT="NT AUTHORITY\System"
$SQLSVCINSTANTFILEINIT="False"
$SQLSYSADMINACCOUNTS="$yourusername"
$SQLTEMPDBFILECOUNT="1"
$SQLTEMPDBFILESIZE="8"
$SQLTEMPDBFILEGROWTH="64"
$SQLTEMPDBLOGFILESIZE="8"
$SQLTEMPDBLOGFILEGROWTH="64"
$ADDCURRENTUSERASSQLADMIN="True"
$TCPENABLED="1"
$NPENABLED="1"
$BROWSERSVCSTARTUPTYPE="Disabled"
$RSSVCACCOUNT="NT AUTHORITY\System"
$RSSVCSTARTUPTYPE="Automatic"
$IAcceptSQLServerLicenseTerms="True"
# User define variables
$SQLUSERDBDIR="$DataDrive\$INSTANCENAME\MSSQL\Data"
$SQLUSERDBLOGDIR="$LogsDrive\$INSTANCENAME\MSSQL\Data"
$SQLTEMPDBDIR="$TempDrive\$INSTANCENAME\MSSQL\Data"
$SQLBACKUPDIR="$BckpDrive\$INSTANCENAME\MSSQL\Data"
# do not edit below this line
$conffile=@"
[OPTIONS]
Action="$ACTION"
ErrorReporting="$ERRORREPORTING"
Quiet="$Quiet"
Features="$FEATURES"
InstanceName="$INSTANCENAME"
InstanceDir="$INSTANCEDIR"
SQLSVCAccount="$SQLSVCACCOUNT"
SQLSysAdminAccounts="$SQLSYSADMINACCOUNTS"
SQLSVCStartupType="$SQLSVCSTARTUPTYPE"
SQLUSERDBDIR="$SQLUSERDBDIR"
SQLUSERDBLOGDIR="$SQLUSERDBLOGDIR"
SQLTEMPDBDIR="$SQLTEMPDBDIR"
SQLBACKUPDIR="$SQLBACKUPDIR"
AGTSVCACCOUNT="$AGTSVCACCOUNT"
AGTSVCSTARTUPTYPE="$AGTSVCSTARTUPTYPE"
RSSVCACCOUNT="$RSSVCACCOUNT"
RSSVCSTARTUPTYPE="$RSSVCSTARTUPTYPE"
ISSVCACCOUNT="$ISSVCACCOUNT" 
ISSVCSTARTUPTYPE="$ISSVCSTARTUPTYPE"
ASCOLLATION="$ASCOLLATION"
SQLCOLLATION="$SQLCOLLATION"
TCPENABLED="$TCPENABLED"
NPENABLED="$NPENABLED"
IAcceptSQLServerLicenseTerms="$IAcceptSQLServerLicenseTerms"
"@
# Check for Script Directory & file
If(Test-Path "$folderpath"){
    Write-Host "The folder '$folderpath' already exists, will not recreate it."
}Else{
    MkDir "$folderpath"
}
If(Test-Path "$folderpath\ConfigurationFile.ini"){
    Write-Host "The file '$folderpath\ConfigurationFile.ini' already exists, removing..."
    Remove-Item -Path "$folderpath\ConfigurationFile.ini" -Force
}Else{
# Create file:
    Write-Host "Creating '$folderpath\ConfigurationFile.ini'..."
    New-Item -Path "$folderpath\ConfigurationFile.ini" -ItemType File -Value $Conffile
}
# Create firewall rule
If(!(Get-NetFirewallRule -DisplayName "SQL Server (TCP 1433) Inbound" -ErrorAction SilentlyContinue)){
    Write-Host "Creating firewall rule"
    New-NetFirewallRule -DisplayName "SQL Server (TCP 1433) Inbound" -Action Allow -Direction Inbound -LocalPort 1433 -Protocol TCP
}
# start the SQL installer
Try{
    If(Test-Path $SQLsource){
        Write-Host "about to install SQL Server 2016..."
        $FileExe="$SQLsource\setup.exe"
        $CONFIGURATIONFILE="$folderpath\ConfigurationFile.ini $FileExe /CONFIGURATIONFILE=$CONFIGURATIONFILE"
    }Else{
        Write-Host "Could not find the media for SQL Server 2016..."
        Break
    }
}Catch{
    Write-Host "Something went wrong with the installation of SQL Server 2016, aborting."
    Break
}
# start the SQL SSMS downloader
$filepath="$folderpath\SSMS-Setup-ENU.exe"
If(!(Test-Path $filepath)){
    Write-Host "Downloading SQL Server 2016 SSMS..."
    $URL="https://download.microsoft.com/download/3/1/D/31D734E0-BFE8-4C33-A9DE-2392808ADEE6/SSMS-Setup-ENU.exe"
    $clnt=New-Object System.Net.WebClient
    $clnt.DownloadFile($url,$filepath)
    Write-Host "done!" -ForegroundColor Green
}Else{
    Write-Host "found the SQL SSMS Installer, no need to download it..."
}
# start the SQL SSMS installer
Write-Host "about to install SQL Server 2016 SSMS..." -nonewline
$Parms=" /Install /Quiet /Norestart /Logs log.txt"
$Prms=$Parms.Split(" ")+"$filepath"+$Prms|Out-Null
Write-Host "done!" -ForegroundColor Green
# exit script
Write-Host "Exiting script, goodbye."