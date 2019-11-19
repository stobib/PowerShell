Clear-Host;Clear-History
$Global:Message=$null
$ScriptPath=$MyInvocation.MyCommand.Definition
$ScriptName=$MyInvocation.MyCommand.Name
$ErrorActionPreference='SilentlyContinue'
Set-Location ($ScriptPath.Replace($ScriptName,""))
Set-Variable -Name LogFolder -Value ($ScriptName.Replace(".ps1",""))
Set-Variable -Name LogFolderPath -Value ($env:USERPROFILE+"\Desktop\"+$LogFolder)
Set-Variable -Name LogName -Value ($LogFolder+".log")
$Global:LogFile=($LogFolderPath+"\"+$LogName)
Set-Variable -Name InputName -Value ($ScriptName.Replace("ps1","txt"))
Set-Variable -Name InputFile -Value ($LogFolderPath+"\"+$InputName)
Set-Variable -Name NotRunningName -Value ("SMS_Not_Running.log")
Set-Variable -Name NotRunningFile -Value ($LogFolderPath+"\"+$NotRunningName)
Set-Variable -Name NotInstalledName -Value ("SMS_Not_Installed.log")
Set-Variable -Name NotInstalledFile -Value ($LogFolderPath+"\"+$NotInstalledName)
Set-Variable -Name OfflineName -Value ("Systems_Offline.log")
Set-Variable -Name OfflineFile -Value ($LogFolderPath+"\"+$OfflineName)
$Script:ClearLogs=@($LogFile,$NotRunningFile,$NotInstalledFile,$OfflineFile)
Function RunSCCMClientAction{[CmdletBinding()]param(
    [Parameter(Position=0, Mandatory=$true,HelpMessage="Provide server names",ValueFromPipeline=$true)][string[]]$Computername,
    [ValidateSet('MachinePolicy','DiscoveryData','AppDeployment','HardwareInventory','UpdateDeployment','UpdateScan','SoftwareInventory')][string[]]$ClientAction)
    $ActionResults=@()
    Try{
        ForEach($Item In $ClientAction){
            $Status=$null
            Switch($Item){
                "MachinePolicy"{$TriggerID='{00000000-0000-0000-0000-000000000021}';Break}
                "DiscoveryData"{$TriggerID='{00000000-0000-0000-0000-000000000003}';Break}
                "AppDeployment"{$TriggerID='{00000000-0000-0000-0000-000000000121}';Break}
                "HardwareInventory"{$TriggerID='{00000000-0000-0000-0000-000000000001}';Break}
                "UpdateDeployment"{$TriggerID='{00000000-0000-0000-0000-000000000108}';Break}
                "UpdateScan"{$TriggerID='{00000000-0000-0000-0000-000000000113}';Break}
                "SoftwareInventory"{$TriggerID='{00000000-0000-0000-0000-000000000002}';Break}
            }
            $Object=@{}|Select-Object "Action name",Status
            Try{
                $ScheduleID=($Item+" - "+$TriggerID)
                Write-Verbose("Processing '"+$ScheduleID+"'")
                $Return=Invoke-WMIMethod -ComputerName $Computername -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule $TriggerID
                If($Return.ReturnValue-eq""){
                    $Status="Started"
                    $Color="Yellow"
                }Else{
                    $Status="Success"
                    $Color="DarkCyan"
                }
            }Catch{
                $Status="Failed"
                $Color="Red"
            }
            Write-Verbose("Operation status - "+$Status)
            $Object."Action name"=$Item
            $Object.Status=$Status
            $Message=("`t`t"+$Object)
            ($Message)|Out-File $LogFile -Append
            $Message|Write-Host -ForegroundColor $Color
        }
    }Catch{
        Write-Error $_.Exception.Message
    }
    Return("`t"+$ActionResults)
}
ForEach($CurrentLog In $ClearLogs){
    If(Test-Path -Path $CurrentLog){
        Remove-Item $CurrentLog
    }
    ("Beginning new log file for "+$LogFolder+".")|Out-File $CurrentLog
    Get-Date -Format "dddd MM/dd/yyyy HH:mm K"|Out-File $CurrentLog -Append
    If($CurrentLog-ne$LogFile){
        $Header="Computer Name"
        $Line=("_"*$Header.Length)
        ("`r`t"+$Header)|Out-File $CurrentLog -Append
        ("`t"+$Line)|Out-File $CurrentLog -Append
    }
}
If(Test-Path -Path $InputFile){
    $ServiceName="SMS Agent Host"
    ForEach($ComputerName In [System.IO.File]::ReadLines($InputFile)){
        $ComputerName=($ComputerName.Split("."))[0]
        $Computer=(Get-ADComputer -Identity "$ComputerName" -Properties DNSHostName).DNSHostName
        $Status=(Test-NetConnection $Computer).PingSucceeded
        If($Status-eq$true){
            $Message=("Checking '"+$Computer+"' for status of '"+$ServiceName+"' service.")
            ("`t"+$Message)|Out-File $LogFile -Append
            $Message|Write-Host -ForegroundColor Cyan
            $Running=Get-Service -Name $ServiceName -ComputerName $Computer
            If($Running.Status -eq "Running"){
                $ServiceStatus="Running"
                $Message=("`t"+$Computer+"`t`t"+$ServiceStatus)
                ($Message)|Out-File $LogFile -Append
                $Message|Write-Host -ForegroundColor Green
                $Message=RunSCCMClientAction -Computername $Computer -ClientAction 'HardwareInventory','SoftwareInventory','UpdateScan','UpdateDeployment'
            }ElseIf($Running.Status -eq "Stopped"){ 
                $Message=("`t"+$Computer)
                ($Message)|Out-File $NotRunningFile -Append
                $Message|Write-Host -ForegroundColor Yellow
            }Else{
                $Message=("`t"+$Computer)
                ($Message)|Out-File $NotInstalledFile -Append
                $Message|Write-Host -ForegroundColor Red
            }
        }Else{
            $Message=("`t"+$Computer)
            ($Message)|Out-File $OfflineFile -Append
            $Message|Write-Host -ForegroundColor Magenta
        }
    }
}Else{
    RunSCCMClientAction -Computername $env:ComputerName -ClientAction 'HardwareInventory','SoftwareInventory','UpdateScan','UpdateDeployment'
}
Set-Location ($env:SystemRoot+"\System32")
