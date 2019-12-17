Clear-Host;Clear-History
Import-Module ProcessCredentials
$Global:Domain=("utshare.local")
$Global:DomainUser=(($env:USERNAME+"@"+$Domain).ToLower())
$SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain ($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=Get-Credential}
$HostName=("win10admy001.vdi."+$Domain).ToLower()
$UnInstallClient=@"
@Echo Off
Echo: Uninstalling the old SCCM client ... Please Wait!
%1\ccmsetup.exe /Uninstall
:Start
Tasklist /FI "ImageName eq ccmsetup.exe" | Find /i "ccmsetup.exe" >> null
IF ERRORLEVEL 2 Goto Running
IF ERRORLEVEL 1 Goto End
:Running
Goto Start
:end
Echo: Uninstall of the old SCCM client is complete.
Exit
"@
$RS=New-PSSession -ComputerName $HostName -Credential $Credentials
Enter-PSSession -Session $RS
Add-Content $Env:TEMP\UnInstallClient.bat $UnInstallClient
Invoke-Command -Session $RS -ScriptBlock{($Env:TEMP+"\UnInstallClient.bat "+$SCCMClientLocation)}
Remove-Item "$Env:TEMP\UnInstallClient.bat"
