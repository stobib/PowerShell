Clear-Host;Clear-History
Import-Module ProcessCredentials
$Global:Domain=("utshare.local")
$Global:DomainUser=(($env:USERNAME+"@"+$Domain).ToLower())
$SCCMClientLocation=("\\w19sccmmpb01.inf."+$Domain+"\SMS_B01\Client")
Switch($DomainUser){
    {($_-like"sy10*")-or($_-like"sy60*")}{Break}
    Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
}
$SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain ($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=Get-Credential}
$HostName=("win10admy001.vdi."+$Domain).ToLower()
$RemoteTemp=("\\"+$HostName+"\Admin$\Temp")
$UnInstallClient=@"
@Echo Off
Type "Beginning script to uninstall the SCCM Client." > C:\Windows\Temp\SCCMClient.log
Echo: Uninstalling the old SCCM client ... Please Wait!
%1\ccmsetup.exe /Uninstall
Type "Monitoring the progress of the uninstall process." > C:\Windows\Temp\SCCMClient.log
:Start
Type "Still processing uninstall..." > C:\Windows\Temp\SCCMClient.log
Tasklist /FI "ImageName eq ccmsetup.exe" | Find /i "ccmsetup.exe" >> null
IF ERRORLEVEL 2 Goto Running
IF ERRORLEVEL 1 Goto End
:Running
Goto Start
:end
Type "Completed the uninstall process." > C:\Windows\Temp\SCCMClient.log
Echo: Uninstall of the old SCCM client is complete.
Exit
"@
Add-Content $RemoteTemp\UnInstallClient.bat $UnInstallClient
$RemoteScript=($env:SystemRoot+"\Temp\UnInstallClient.bat")
If(Test-Connection -ComputerName $HostName -Quiet){
    Try{
        Invoke-Command -ComputerName $HostName -Credential $SecureCredentials -FilePath $RemoteScript -ArgumentList $SCCMClientLocation
    }Catch{
    }
}
Remove-Item ($RemoteTemp+"\UnInstallClient.bat")
