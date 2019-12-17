Clear-Host;Clear-History
$Global:Message=$null
$ScriptPath=$MyInvocation.MyCommand.Definition
$ScriptName=$MyInvocation.MyCommand.Name
$ErrorActionPreference='SilentlyContinue'
Set-Location ($ScriptPath.Replace($ScriptName,""))
Set-Variable -Name System32 -Value ($env:SystemRoot+"\System32")
Set-Variable -Name LogFolder -Value ($ScriptName.Replace(".ps1",""))
Set-Variable -Name LogFolderPath -Value ($env:USERPROFILE+"\Desktop\"+$LogFolder)
Set-Variable -Name LogName -Value ($LogFolder+".log")
$Global:LogFile=($LogFolderPath+"\"+$LogName)
Set-Variable -Name InputName -Value ($ScriptName.Replace("ps1","txt"))
Set-Variable -Name InputFile -Value ($LogFolderPath+"\"+$InputName)
Set-Variable -Name SystemListName -Value ("ServerList.txt")
Set-Variable -Name SystemListFile -Value ($LogFolderPath+"\"+$SystemListName)
Set-Variable -Name NotRunningName -Value ("SMS_Not_Running.log")
Set-Variable -Name NotRunningFile -Value ($LogFolderPath+"\"+$NotRunningName)
Set-Variable -Name NotInstalledName -Value ("SMS_Not_Installed.log")
Set-Variable -Name NotInstalledFile -Value ($LogFolderPath+"\"+$NotInstalledName)
Set-Variable -Name OfflineName -Value ("Systems_Offline.log")
Set-Variable -Name OfflineFile -Value ($LogFolderPath+"\"+$OfflineName)
$Script:ClearLogs=@($LogFile,$NotRunningFile,$NotInstalledFile,$OfflineFile,$SystemListFile)
If(!(Test-Path -LiteralPath $LogFolderPath)){
    New-Item -Path $LogFolderPath -ItemType Directory
}
ForEach($CurrentLog In $ClearLogs){
    If(Test-Path -Path $CurrentLog){
        Remove-Item $CurrentLog
    }
    If($CurrentLog-ne$SystemListFile){
        ("Beginning new log file for '"+$CurrentLog+"'.")|Out-File $CurrentLog
        Get-Date -Format "dddd MM/dd/yyyy HH:mm K"|Out-File $CurrentLog -Append
        If($CurrentLog-ne$LogFile){
            $Header="Computer Name"
            $Line=("_"*$Header.Length)
            ("`r`t"+$Header)|Out-File $CurrentLog -Append
            ("`t"+$Line)|Out-File $CurrentLog -Append
        }
    }Else{
        Get-ADComputer -Filter 'OperatingSystem -like "*windows*server*"' -Properties OperatingSystem|FT DNSHostName,OperatingSystem -A|Out-File $SystemListFile
    }
}
If(Test-Path -LiteralPath $SystemListFile){
    ForEach($CurrentLineValue In Get-Content -Path $SystemListFile){
        If($CurrentLineValue-like"*Windows Server*"){
            $ServerName=($CurrentLineValue -Split("Windows Server"))[0].Trim()
            $ProcessID=(Get-Process -Name CcmExec -ComputerName $ServerName).Id
        }
    }
}
Set-Location $System32