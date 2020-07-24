[CmdletBinding()]
param(
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string[]]$LogFileNames=@()
)
# NOTE: The below default parameter value option can be used to set default values to command line parameters
$DefaultParameterValues=@{"LogFileNames"=""}
If!($LogFileNames){$LogFileNames+=($DefaultParameterValues.LogFileNames)}
<#             http://msdn.microsoft.com/en-us/library/x83z1d9f(v=vs.84).aspx             #>
<# Button Types
                    Decimal value    Hexadecimal value    Description
                    0                0x0                  Show OK button.
                    1                0x1                  Show OK and Cancel buttons.
                    2                0x2                  Show Abort, Retry, and Ignore buttons.
                    3                0x3                  Show Yes, No, and Cancel buttons.
                    4                0x4                  Show Yes and No buttons.
                    5                0x5                  Show Retry and Cancel buttons.
                    6                0x6                  Show Cancel, Try Again, and Continue buttons.
#>#             Button Types
<# Icon Types
                    Decimal value    Hexadecimal value    Description
                    16               0x10                 Show "Stop Mark" icon.
                    32               0x20                 Show "Question Mark" icon.
                    48               0x30                 Show "Exclamation Mark" icon.
                    64               0x40                 Show "Information Mark" icon.
#>#             Icon Types
<# Return Value
                    Decimal value    Description
                    -1               The user did not click a button before nSecondsToWait seconds elapsed.
                    1                OK button
                    2                Cancel button
                    3                Abort button
                    4                Retry button
                    5                Ignore button
                    6                Yes button
                    7                No button
                    10               Try Again button
                    11               Continue button
#>#             Return Value
[datetime]$Global:StartTime=Get-Date -Format o
[datetime]$Global:EndTime=0
$Global:LogonServer=$null
Clear-History;Clear-Host
[boolean]$Global:bElevated=([System.Security.Principal.WindowsIdentity]::GetCurrent()).Groups -contains "S-1-5-32-544"
If($bElevated){
    Set-Variable -Name RestartNeeded -Value 0
    Set-Variable -Name Repositories -Value @('PSGallery')
    Set-Variable -Name PackageProviders -Value @('Nuget')
    Set-Variable -Name ModuleList -Value @('Rsat.ActiveDirectory.')
    Set-Variable -Name OriginalPref -Value $ProgressPreference
    # PowerShell Version (.NetFramework Error Checking) >>>--->
    [int]$PSVersion=([string]$PSVersionTable.PSVersion.Major+"."+[string]$PSVersionTable.PSVersion.Minor)
    If($PSVersion-lt7){
        $ProgressPreference="SilentlyContinue"
        Write-Host ("Please be patient while prerequisite modules are installed and loaded.")
        $NugetPackage=Find-PackageProvider -Name $PackageProviders
                            ForEach($Provider In $PackageProviders){
        $FindPackage=Find-PackageProvider -Name $Provider
        $GetPackage=Get-PackageProvider -Name $Provider
        If($FindPackage.Version-ne$GetPackage.Version){
            Install-PackageProvider -Name $FindPackage.Name -Force -Scope CurrentUser
        }
        }
            ForEach($Repository In $Repositories){
        Set-PSRepository -Name $Repository -InstallationPolicy Trusted
        }
                                    ForEach($ModuleName In $ModuleList){
        $RSATCheck=Get-WindowsCapability -Name ($ModuleName+"*") -Online|Select-Object -Property Name,State
        If($RSATCheck.State-eq"NotPresent"){
            $InstallStatus=Add-WindowsCapability -Name $RSATCheck.Name -Online
            If($InstallStatus.RestartNeeded-eq$true){
                $RestartNeeded=1
            }
        }
        }
        Write-Host ("THe prerequisite modules are now installed and ready to process this script.")
        $ProgressPreference=$OriginalPref
    }
    # PowerShell Version (.NetFramework Error Checking) <---<<<
}
Import-Module ActiveDirectory
Import-Module ProcessCredentials
$ErrorActionPreference='SilentlyContinue'
[string]$Global:DomainUser=($env:USERNAME.ToLower())
[string]$Global:Domain=($env:USERDNSDOMAIN.ToLower())
[string]$Global:ScriptPath=$MyInvocation.MyCommand.Definition
[string]$Global:ScriptName=$MyInvocation.MyCommand.Name
Set-Location ($ScriptPath.Replace($ScriptName,""))
Set-Variable -Name System32 -Value ($env:SystemRoot+"\System32")
Switch($DomainUser){
    {($_-like"sy100*")-or($_-like"sy600*")}{Break}
    Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
}
$SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=Get-Credential}
# Get current domain using logged-on user's credentials
$CurrentDomain="LDAP://"+([ADSI]"").distinguishedName
$LogonServer=New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,
$SecureCredentials.UserName,$SecureCredentials.GetNetworkCredential().Password)
$SecureFilePath=($env:USERPROFILE+"\AppData\Local\Credentials\"+($Domain).Split(".")[0])
If($LogonServer.Name-eq$null){ # <<---<<< Added "!()" for testing
    [boolean]$bMissing=$false
    If(Test-Path -Path $SecureFilePath){
        $Files=Get-Item -Path ($SecureFilePath+"\*")
        [int]$FileCount=0
        [datetime]$FileDate1=0
        [datetime]$FileDate2=0
        ForEach($File In $Files){
            $FileName=($File.Name).Split(".")[0]
            If($FileName-eq$DomainUser){
                $FileDate2=$File.CreationTime
                $Key2=(Get-Content -Path ($SecureFilePath+"\"+$FileName+".*") -Raw).Substring(0,37)
            }Else{
                $FileDate1=$File.CreationTime
                $Key1=(Get-Content -Path ($SecureFilePath+"\"+$FileName+".*") -Raw).Substring(0,37)
            }
            $FileCount++
        }
        [int]$CreationTime=(New-TimeSpan -Start $FileDate1 -End $FileDate2).TotalMilliseconds
        If(($FileCount-lt2)-or($CreationTime-gt100)){
            If(!($Key1-eq$Key2)){
                $bMissing=$true
            }
        }
    }
    If($bMissing){
        Set-Location $System32
        $ProgressPreference=$OriginalPreference
        Write-Host ("Authentication failed - please verify your username: ["+$SecureCredentials.UserName+"] and password.")
        Exit # Terminate the script.
    }
}Else{
    write-host ("Successfully authenticated with domain ["+$Domain+"].")
}
# Process Existing Log Files
[string]$Global:LogLocation=($ScriptPath.Replace($ScriptName,"")+"Logs\"+$ScriptName.Replace(".ps1",""))
[string]$Global:LogDate=Get-Date -Format "yyyy-MMdd"
[string[]]$LogFiles=@()
[int]$intCount=0
ForEach($LogFile In $LogFileNames){
    $intCount++
    New-Variable -Name "LogFN$($intCount)" -Value ([string]($LogLocation+"\"+$LogFile+$LogDate+".log"))
    $LogFiles+=(Get-Variable -Name "LogFN$($intCount)").Value
}
ForEach($LogFile In $LogFiles){
    If(Test-Path -Path $LogFile){
        $FileName=(Split-Path -Path $LogFile -Leaf).Replace(".log","")
        $Files=Get-Item -Path ($LogLocation+"\*.*")
        [int]$FileCount=0
        ForEach($File In $Files){
            If(!($File.Mode-eq"d----")-and($File.Name-like($FileName+"*"))){
                $FileCount++
            }
        }
        If($FileCount-gt0){
            Rename-Item -Path $LogFile -NewName ($FileName+"("+$FileCount+").log")
        }
    }
}
Clear-History;Clear-Host
# Script Body >>>--->> Unique code for Windows PowerShell scripting
Function ReadCopyEventLogs($HostNames,[string]$EventLog,[string]$ImportLog){
    $ComboEventLog=(Get-EventLog -LogName $ImportLog -Newest 1|Select-Object *)
    $TimeWritten=$ComboEventLog.TimeWritten
    ForEach($Server In $HostNames){
        If($TimeWritten){
            $RemoteEvents=@(Get-EventLog -LogName $EventLog -ComputerName $Server -After $TimeWritten|Select-Object *)
            ForEach($Event In $RemoteEvents){
                $EntryType=$Event.EntryType
                $Category=$Event.CategoryNumber
                $EventID=$Event.EventID
                $Message=$Event.Message
                Write-EventLog -LogName $ImportLog -Source Script -EntryType $EntryType -Category $Category -EventId $EventID -Message $Message
            }
        }Else{
            $RemoteEvents=(Get-EventLog -LogName $EventLog -ComputerName $Server -Newest 1|Select-Object *)
            $EntryType=$RemoteEvents.EntryType
            $Category=$RemoteEvents.CategoryNumber
            $EventID=$RemoteEvents.EventID
            $Message=$RemoteEvents.Message
            Write-EventLog -LogName $ImportLog -Source Script -EntryType $EntryType -Category $Category -EventId $EventID -Message $Message
        }
    }
}
Function Set-EventLogPath([string]$HostName,[string]$NewLogPath,[string]$CurrentLog){
    [reflection.assembly]::LoadWithPartialName("System.Diagnostics.Eventing.Reader")
    $EventLogSession=New-Object System.Diagnostics.Eventing.Reader.EventLogSession -ArgumentList $HostName
    ForEach($LogName In $Eventlogsession.GetLogNames()){
        If($LogName-eq$CurrentLog){
            $EventLogConfig=New-Object System.Diagnostics.Eventing.Reader.EventLogConfiguration -ArgumentList $LogName,$EventLogSession
            If($bDefaultPath){
                $NewLogFilePath=$NewLogPath
            }Else{
                $NewLogFilePath=($NewLogPath+"\"+$EventLogConfig.LogType)
                If(!(Test-Path -Path $NewLogFilePath)){
                    New-Item -Path $NewLogPath -Name $EventLogConfig.LogType -ItemType "Directory"|Out-Null
                }
            }
            $LogFilePath=$EventLogConfig.LogFilePath
            $LogFile=Split-Path $LogFilePath -Leaf
            $NewLogFilePath=($NewLogFilePath+"\"+$LogFile)
            If($EventLogConfig.IsEnabled){
                $EventLogConfig.IsEnabled=$false
                $EventLogConfig.SaveChanges()
            }
            $EventLogConfig.LogFilePath=$NewLogFilePath
            $EventLogConfig.IsEnabled=$true
            $EventLogConfig.SaveChanges()
        }
    }
}
Set-Variable -Name ServerList -Value @()
Set-Variable -Name EventLogPath -Value ""
Set-Variable -Name bDefaultPath -Value $false
Set-Variable -Name bExistingLog -Value $false
Set-Variable -Name WindowsLogs -Value @("Security")
Set-Variable -Name LogNames -Value ("DomainController-SecurityLogs")
Set-Variable -Name ComboADSecLogs -Value ("E:\Windows\System32\Winevt\Logs")
Set-Variable -Name AllDCs -Value (Get-ADDomainController -Filter *|Select-Object HostName,IsGlobalCatalog|Sort HostName)
ForEach($Log In $LogNames){
    Remove-EventLog -LogName $Log|Out-Null
}
Do{
    $Online={$ServerList}.Invoke()
    ForEach($GC In $AllDCs){
        If($GC.IsGlobalCatalog-eq$true){
            $ServerList+=$GC.HostName
        }
    }
    ForEach($Server In $ServerList){
        $ConnectResult=Test-NetConnection -ComputerName $Server -Port 135
        If($ConnectResult.TcpTestSucceeded){
            $Online.Add($Server)|Out-Null
        }Else{
            $Online.Remove($Server)|Out-Null
        }
    }
    If($ServerList-ne$null){
        $AvailableLogs=Get-WinEvent -ListLog *
        $Collection={$WindowsLogs}.Invoke()
        ForEach($NewLog In $LogNames){
            $bExistingLog=$false
            ForEach($EventLog In $AvailableLogs){
                If($bExistingLog){Break}
                Switch($EventLog){
                    {($_.LogName-eq$NewLog)}{$bExistingLog=$true;Break}
                }
            }
            ForEach($LogName In $Collection){
                If(!($bExistingLog)){
                    New-EventLog -LogName $NewLog -Source Script
                    If($bDefaultPath){
                        $EventLogPath=($env:SystemRoot+"\System32\Winevt\Logs")
                    }Else{
                        $EventLogPath=$ComboADSecLogs
                    }
                    Set-EventLogPath -HostName $env:COMPUTERNAME -NewLogPath $EventLogPath -CurrentLog $NewLog
                }
                ReadCopyEventLogs -HostNames $ServerList -EventLog $LogName -ImportLog $NewLog;Break
            }
            $Collection.Remove($LogName)|Out-Null
        }
    }
}While($Online)
# Script Body <<---<<< Unique code for Windows PowerShell scripting
If($EndTime-eq0){
    [datetime]$EndTime=Get-Date -Format o
    $RunTime=(New-TimeSpan -Start $StartTime -End $EndTime)
    Write-Host ("Script runtime: ["+$RunTime+"]")
}Else{
    Write-Host ("Script runtime: ["+$RunTime.Hours+":"+$RunTime.Minutes+":"+$RunTime.Seconds+"."+$RunTime.Milliseconds+"]")
}
Set-Location $System32
$ProgressPreference=$OriginalPreference
