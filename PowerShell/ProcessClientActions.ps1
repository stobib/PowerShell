Clear-Host;Clear-History
Import-Module ProcessCredentials
$Global:SecureCredentials=$null
$Global:Domain=("utshare.local")
$Global:DomainUser=(($env:USERNAME+"@"+$Domain).ToLower())
$ScriptPath=$MyInvocation.MyCommand.Definition
$ScriptName=$MyInvocation.MyCommand.Name
$ErrorActionPreference='SilentlyContinue'
Set-Location ($ScriptPath.Replace($ScriptName,""))
Set-Variable -Name SecureCredentials -Value $null
Set-Variable -Name LogName -Value ($ScriptName.Replace("ps1","log"))
Set-Variable -Name LogFile -Value ($env:USERPROFILE+"\Desktop\"+$LogName)
Set-Variable -Name InputName -Value ($ScriptName.Replace("ps1","txt"))
Set-Variable -Name InputFile -Value ($env:USERPROFILE+"\Desktop\"+$InputName)
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
            $Object=@{} | Select-Object "Action name",Status
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
            Write-Host("`t`t"+$Object) -ForegroundColor $Color
        }
    }Catch{
        Write-Error $_.Exception.Message
    }
    Return("`t"+$ActionResults)
}
Switch($DomainUser){
    {($_-like"sy10*")-or($_-like"sy60*")}{Break}
    Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
}
$SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain ($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=get-credential}
If(Test-Path -Path $InputFile){
    $ServiceName="SMS Agent Host"
    ForEach($ComputerName In [System.IO.File]::ReadLines($InputFile)){
        $Computer=(Get-ADComputer -Identity "$ComputerName" -Properties DNSHostName).DNSHostName
        $Status=(Test-NetConnection $Computer).PingSucceeded
        If($Status-eq$true){
            Write-Host("Checking '"+$Computer+"' for status of '"+$ServiceName+"' service.")
            $Running=Get-Service -Name $ServiceName -ComputerName $Computer
            If($Running.Status -eq "Running"){
                $ServiceStatus="Running"
                Write-Host("`t"+$Computer+"`t`t"+$ServiceStatus) -ForegroundColor Green
                RunSCCMClientAction -Computername $Computer -ClientAction 'HardwareInventory','SoftwareInventory','UpdateScan','UpdateDeployment'
            }ElseIf($Running.Status -eq "Stopped"){ 
                $ServiceStatus="Not Running"
                Write-Host("`t"+$Computer+"`t`t"+$ServiceStatus) -ForegroundColor Yellow
            }Else{
                $ServiceStatus="Not Installed"
                Write-Host("`t"+$Computer+"`t`t"+$ServiceStatus) -ForegroundColor Red
            }
        }Else{
            Write-Host("Connection to '"+$Computer+"' failed.") -ForegroundColor Yellow
        }
    }
}Else{
    RunSCCMClientAction -Computername $env:ComputerName -ClientAction 'HardwareInventory','SoftwareInventory','UpdateScan','UpdateDeployment'
}
Set-Location ($env:SystemRoot+"\System32")
