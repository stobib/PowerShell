Clear-History;Clear-Host
Import-Module ActiveDirectory
Import-Module ProcessCredentials
$Global:ScriptName="RemoteRegistry.ps1"
$Global:Domain=($env:USERDNSDOMAIN.ToLower())
$Global:DomainUser=(($env:USERNAME+"@"+$Domain).ToLower())
$Global:PShell="C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe"
Set-Variable -Name OutputFile -Value ($env:TEMP+"\WindowsWorkstations.txt")
Set-Variable -Name SystemDivide -Value "-------------------------------------------------------------------------------"
Get-ADComputer -Filter{(OperatingSystem -like "Windows 10*")-or(OperatingSystem -like "Windows 8.*")} -Properties Name,IPv4Address,OperatingSystem|Sort-Object Name|Select-Object DNSHostName,IPv4Address,OperatingSystem|Out-File $OutputFile
#Get-ADComputer -Filter{DNSHostName -like "win10admy001.*"} -Properties Name,IPv4Address,OperatingSystem|Sort-Object Name|Select-Object DNSHostName,IPv4Address,OperatingSystem|Out-File $OutputFile
$HostnameList=(Get-Content -Path $OutputFile)
Switch($DomainUser){
    {($_-like"sy100*")-or($_-like"sy600*")}{Break}
    Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
}
$SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain ($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=Get-Credential}
Clear-History;Clear-Host
ForEach($Hostname In $HostnameList){
    $IPv4=$null
    $Loop=0
    If($Hostname-like("*."+$Domain+"*")){
        $Hostname=$Hostname.Replace(" ",",")
        $Name=($Hostname.Split(",")[0])
        Do{
            $Loop++
            $IPv4=($Hostname.Split(",")[$Loop])
        }
        Until((!$IPv4-eq"")-or($Loop-gt$Hostname.Length))
        If(($IPv4-like"10.118.*")-or($IPv4-like"10.126.*")){
            If(Test-Connection -ComputerName $Name -Quiet){
                Write-Host $SystemDivide
                Write-Host $Name
                $Sysinternals={PSexec.exe ("\\"+$Name) cmd.exe}
                $CurrentDate=Get-Date
                $Destination=$null
                $SiteServer=$null
                $SiteCode=$null
                $CFGFile=$null
                $OldFiles=-30
                Switch($IPv4){
                    {($_-like"10.118.*")}{$SiteCode="A01";Break}
                    Default{$SiteCode="B01";Break}
                }
                Switch($SiteCode){
                    "A01"{$SiteServer="w19sccmmpa01.inf.utshare.local";$CFGFile="C:\ClientHealth\configa.xml";Break}
                    "B01"{$SiteServer="w19sccmmpb01.inf.utshare.local";$CFGFile="C:\ClientHealth\configb.xml";Break}
                }
                $Counter=0
                [System.Collections.ArrayList]$RCHeaders=@()
                $RCSrcValues=@('"\\'+$SiteServer+'\Sources\Apps"';'"\\'+$SiteServer+'\ClientHealth\prd"';'"\\'+$Domain+'\cifs\Utilities\Services"')
                $RCDesValues=@('"\\'+$Name+'\Admin$\System32"';'"\\'+$Name+'\C$\ClientHealth"';'"\\'+$Name+'\C$\Scripts"')
                ForEach($Src In $RCSrcValues){
                    $NewRow=[PSCustomObject]@{'Source'=$Src;'Destination'=$RCDesValues[$Counter]};$Counter++
                    $RCHeaders.Add($NewRow)|Out-Null
                    $NewRow=$null
                }
                $Counter=0
                ForEach($Row In $RCHeaders){
                    RoboCopy $Row.Source $Row.Destination /R:0 /W:0 > ($env:temp+"\"+$Name.Split(".")[0]+"_"+$Counter+".tmp")
                    $Destination=($Row.Destination.Replace("""","")+"\"+$ScriptName)
                    $Counter++
                }
                $DeletiontDate=$CurrentDate.AddDays($OldFiles)
                PSexec.exe ("\\"+$Name) cmd.exe /C ("ForFiles /P %SystemDrive%\users\ > %SystemDrive%\Scripts\Users.tmp")
                [System.Collections.ArrayList]$PathForDeletion=@()
                ForEach($UserAccount In Get-Content -Path ("\\"+$Name+"\C$\Scripts\Users.tmp")){
                    If(($UserAccount-like"*100*")-or($UserAccount-like"*500*")-or($UserAccount-like"*600*")){
                        $NewRow=@(("%SystemDrive%\users\$UserAccount\Appdata\Local\Temp\").Replace("""",""))
                        $PathForDeletion.Add($NewRow)|Out-Null
                        $NewRow=$null
                    }
                }
                $Counter=0
                Do{
                    Switch($Counter){
                        0{$NewRow="%SystemRoot%\Temp\";Break}
                        1{$NewRow="%SystemRoot%\SoftwareDistribution\Download\";Break}
                    }
                    $PathForDeletion.Add($NewRow)|Out-Null
                    $NewRow=$null
                    $Counter++
                }Until($Counter-eq2)
                If(Test-Path -Path $Destination){
                    Try{
                        ForEach($Path In $PathForDeletion){
                            Write-Host $SystemDivide
                            Write-Host ("Currently processing ["+$Path+"] for files older than ["+$DeletiontDate+"] to be deleted.")
                            PSexec.exe ("\\"+$Name) cmd.exe /C ("ForFiles /P "+$Path+" /S /M *.* /C ""cmd.exe /C Del /F /Q @Path"" /D -30")
                            Write-Host $SystemDivide
                        }
                        $RemoteTemp=("\\"+$Name+"\C$\Scripts")
                        $ClientHealth=@"
@Echo Off
REM param($SiteCode)
If $SiteCode EQU B01 Goto SiteB
:SiteA
Set CFGFile=C:\ClientHealth\configa.xml
Set SiteServer=https://w19sccmmpa01.inf.utshare.local/ConfigMgrClientHealth
Goto Start
:SiteB
Set CFGFile=C:\ClientHealth\configb.xml
Set SiteServer=https://w19sccmmpb01.inf.utshare.local/ConfigMgrClientHealth
:Start
Set PShell="C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe"
Echo "Beginning script for checking the Client Health of the workstation." > C:\ClientHealth\RemoteCheck.log
Echo:   "Using the "File System Utility" to remove "8.3" backward compatibility!"
Echo "Using the 'File System Utility' to remove '8.3' backward compatibility!" >> C:\ClientHealth\RemoteCheck.log
fsutil 8dot3name set 1
Echo:   "Setting the PowerShell "Execution Policy" to "Unrestricted" for the CurrentUser scope."
Echo "Setting the PowerShell 'Execution Policy' to 'Unrestricted' for the CurrentUser scope." >> C:\ClientHealth\RemoteCheck.log
%PShell% Set-ExecutionPolicy -Scope CurrentUser Unrestricted
Echo:   "Setting the computer's timezone to 'Central Standard Time'."
Echo "Setting the computer's timezone to 'Central Standard Time'." >> C:\ClientHealth\RemoteCheck.log
%PShell% Set-TimeZone -Name 'Central Standard Time'
Echo:   "Beginning to process 'C:\Scripts\RemoteRegistry.ps1' for enabling the Remote Registry service."
Echo "Beginning to process 'C:\Scripts\RemoteRegistry.ps1' for enabling the Remote Registry service." >> C:\ClientHealth\RemoteCheck.log
%PShell% -ExecutionPolicy Bypass -File C:\Scripts\RemoteRegistry.ps1
Echo:   "Beginning to process 'C:\ClientHealth\ConfigMgrClientHealth.ps1' for validating the SCCM Client installation."
Echo "Beginning to process 'C:\ClientHealth\ConfigMgrClientHealth.ps1' for validating the SCCM Client installation." >> C:\ClientHealth\RemoteCheck.log
%PShell% -ExecutionPolicy Bypass -File C:\ClientHealth\ConfigMgrClientHealth.ps1 -Config %CFGFile% -Webservice %SiteServer%
Echo:   "Beginning to process 'C:\ClientHealth\ClientHealthMonitor.ps1' to get the current health of the SCCM Client."
Echo "Beginning to process 'C:\ClientHealth\ClientHealthMonitor.ps1' to get the current health of the SCCM Client." >> C:\ClientHealth\RemoteCheck.log
%PShell% -ExecutionPolicy Bypass -File C:\ClientHealth\ClientHealthMonitor.ps1
Echo:   "Beginning to cleanup the temporary files used in this script."
Echo "Beginning to cleanup the temporary files used in this script." >> C:\ClientHealth\RemoteCheck.log
%PShell% Remove-Item ""%SystemDrive%\ClientHealth\*.xml"" -Force
%PShell% Remove-Item ""%SystemDrive%\ClientHealth\*.ps1"" -Force
%PShell% Remove-Item ""%SystemDrive%\Scripts\Users.tmp"" -Force
Echo:   "Completed processing the computer's client health."
Echo "Completed processing the computer's client health." >> C:\ClientHealth\RemoteCheck.log
Echo:   "Kicking off Windows Security Updates Scan/Download/Install/Reboot process."
Echo "Kicking off Windows Security Updates Scan/Download/Install/Reboot process." >> C:\ClientHealth\RemoteCheck.log
REM UsoClient StartScan
REM UsoClient StartDownload
REM UsoClient StartInstall
REM UsoClient RestartDevice
Exit
"@
                        Add-Content $RemoteTemp\ClientHealth.bat $ClientHealth
                        $RemoteScript=($env:SystemDrive+"\Scripts\ClientHealth.bat")
                        If(Test-Connection -ComputerName $Name -Quiet){
                            Try{
                                If(Test-Path -Path ("\\"+$Name+"\C$\ClientHealth\RemoteCheck.log")){
                                    Remove-Item ("\\"+$Name+"\C$\ClientHealth\RemoteCheck.log")
                                }
                                PSexec.exe ("\\"+$Name) cmd.exe /C $RemoteScript
                                Write-Host ("Completed processing: ["+$RemoteScript+"] on ["+$Name+"].")
                            }Catch{
                                Write-Host ("Failed to process: ["+$RemoteScript+"] on ["+$Name+"].")
                            }
                        }
                    }Catch{
                    }
                    If(Test-Path -Path ("\\"+$Name+"\C$\ClientHealth\RemoteCheck.log")){
                        Remove-Item ($RemoteTemp+"\ClientHealth.bat")
                        Remove-Item $Destination
                    }
                }
                Write-Host $SystemDivide
            }
        }
    }
}
Remove-Item $OutputFile -Force -Verbose