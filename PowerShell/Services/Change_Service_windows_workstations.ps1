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
#                    Write-Host ("RoboCopy "+$Row.Source+" "+$Row.Destination+" /R:0 /W:0 > "+$env:temp+"\"+$Name.Split(".")[0]+"_"+$Counter+".tmp")
                    RoboCopy $Row.Source $Row.Destination /R:0 /W:0 > ($env:temp+"\"+$Name.Split(".")[0]+"_"+$Counter+".tmp")
                    $Destination=($Row.Destination.Replace("""","")+"\"+$ScriptName)
                    $Counter++
                }
#                Pause
#<#
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
<#
                        PSexec.exe ("\\"+$Name) cmd.exe /C "fsutil 8dot3name set 1"
                        PSexec.exe ("\\"+$Name) cmd.exe /C "$PShell Set-ExecutionPolicy -Scope CurrentUser Unrestricted"
                        PSexec.exe ("\\"+$Name) cmd.exe /C "$PShell Set-TimeZone -Name 'Central Standard Time'"
#>
                        ForEach($Path In $PathForDeletion){
                            Write-Host $SystemDivide
                            Write-Host ("Currently processing ["+$Path+"] for files older than ["+$DeletiontDate+"] to be deleted.")
                            PSexec.exe ("\\"+$Name) cmd.exe /C ("ForFiles /P "+$Path+" /S /M *.* /C ""cmd.exe /C Del /F /Q @Path"" /D -30")
                            Write-Host $SystemDivide
                        }
<#
                        PSexec.exe ("\\"+$Name) cmd.exe /C "$PShell Remove-Item ""$env:SystemRoot\Temp\*"" -Recurse"
                        PSexec.exe ("\\"+$Name) cmd.exe /C "$PShell Remove-Item ""$env:SystemRoot\SoftwareDistribution\Download\*"" -Recurse"
                        PSexec.exe ("\\"+$Name) cmd.exe /C "$PShell -ExecutionPolicy Bypass -File C:\Scripts\RemoteRegistry.ps1"
#<#
                        PSexec.exe ("\\"+$Name) cmd.exe /C "$PShell -ExecutionPolicy Bypass -File C:\ClientHealth\ConfigMgrClientHealth.ps1 -Config $CFGFile -Webservice https://$SiteServer/ConfigMgrClientHealth"
                        PSexec.exe ("\\"+$Name) cmd.exe /C "$PShell -ExecutionPolicy Bypass -File C:\ClientHealth\ClientHealthMonitor.ps1"
                        PSexec.exe ("\\"+$Name) cmd.exe /C "$PShell -ExecutionPolicy Bypass -File C:\ClientHealth\Remove-WMIInvalidContent.ps1"
                        PSexec.exe ("\\"+$Name) cmd.exe /C "$PShell Remove-Item ""C:\ClientHealth\*.xml"" -Recurse -Force"
                        PSexec.exe ("\\"+$Name) cmd.exe /C "$PShell Remove-Item ""C:\ClientHealth\*.ps1"" -Recurse -Force"
>
                        PSexec.exe ("\\"+$Name) cmd.exe /C "UsoClient StartScan"
                        PSexec.exe ("\\"+$Name) cmd.exe /C "UsoClient StartDownload"
                        PSexec.exe ("\\"+$Name) cmd.exe /C "UsoClient StartInstall"
                        PSexec.exe ("\\"+$Name) cmd.exe /C "UsoClient RestartDevice"
#>
                    }Catch{
                    }
                    Remove-Item $Destination
                }
                Write-Host $SystemDivide
#                Pause
#>
            }
        }
    }
}
Remove-Item $OutputFile -Force -Verbose