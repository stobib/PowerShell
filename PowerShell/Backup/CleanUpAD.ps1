[CmdletBinding()]
param(
  [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string[]]$ComputerNames=@(),
  [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string[]]$ComputerTypes=@(),
  [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][int]$OfflineLimit,
  [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][int]$DeletionDays
)
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
[string]$Global:LogFN1=($LogLocation+"\"+$ScriptName.Replace(".ps1","")+$LogDate+".log")
[string]$Global:LogFN2=($LogLocation+"\Missing_IP_"+$LogDate+".log")
# NOTE: Add log filenames and path if different than current folder for
#       each file.  Each log file will need to be separated using a comma.
[string[]]$LogFiles=@($LogFN1,$LogFN2)
If(!(Test-Path -Path $LogLocation)){New-Item -Path $LogLocation -ItemType Directory}
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
$Script:ProcessTypes=@()
$Script:RetiredSVR="OU=Servers,OU=Retired,DC=utshare,DC=local"
$Script:RetiredWKS="OU=Workstations,OU=Retired,DC=utshare,DC=local"
[datetime]$ScriptStartTime=Get-Date -Format o
("Beginning new log file for processing retired systems.")|Out-File -FilePath $LogFN1 -NoClobber
If($OfflineLimit-eq0){$OfflineLimit=30}
If(($ComputerTypes.ToLower()-like"*server*")-or($ComputerTypes.ToLower()-like"*svr*")-or($ComputerTypes.ToLower()-like"*srv*")){
    ("Scheduled to process 'servers' during this run that have been offline for at least ["+$OfflineLimit+"] days.")|Out-File -FilePath $LogFN1 -Append
    $ProcessTypes+="SRV"
}
If(($ComputerTypes.ToLower()-like"*workst*")-or($ComputerTypes.ToLower()-like"*wks*")){
    ("Scheduled to process 'workstations' during this run that have been offline for at least ["+$OfflineLimit+"] days.")|Out-File -FilePath $LogFN1 -Append
    $ProcessTypes+="WKS"
}
If(!($ComputerTypes.Length-gt0)){$ProcessTypes+="WKS"}
$Script:CurrentProcessFile=("Missing_IP_"+$LogDate+".log")
$File2Process=((Split-Path -Path $LogLocation)+"\VM_PowerState\"+$CurrentProcessFile)
If(!(Test-Path -Path $File2Process)){
    ("The log file ["+$CurrentProcessFile+"] doesn't exist.  Looking for most recent log file to process.")|Out-File -FilePath $LogFN1 -Append
    $MissingIPLogsPath=((Split-Path -Path $File2Process)+"\*")
    $FileSearch=[string]$CurrentProcessFile.Split($LogDate)[0]
    $FileList=Get-Item -Path $MissingIPLogsPath
    ForEach($FileName In $FileList){
        If($FileName.Name-like($FileSearch+"*.log")){
            If($FileName.Name-notlike"*(*).log"){
                $File2Process=((Split-Path -Path $File2Process)+"\"+$FileName.Name)
            }
        }
    }
}
If($File2Process){
    Copy-Item -Path $File2Process -Destination $LogFN2
    ("Copied log file: ["+$File2Process+"] to ["+$LogFN2+"] for processing this run.")|Out-File -FilePath $LogFN1 -Append
    $ProcessFile=$LogFN2
}
If(Test-Path -Path $ProcessFile){
    $LineValue=Get-Content -Path $ProcessFile
    ForEach($Line In $LineValue){
        $DNSHostname=$Line.Substring($Line.IndexOf('[')+1,($Line.IndexOf(']')-$Line.IndexOf('['))-1)
        If($DNSHostname){
            ("Adding ["+$DNSHostname+"] to be processed during this run.")|Out-File -FilePath $LogFN1 -Append
            $ComputerNames+=$DNSHostname
        }
    }
}
[boolean]$Script:bToBeDeleted=$false
If($DeletionDays-ge90){
    $bToBeDeleted=$true
}
ForEach($Type In $ProcessTypes){
    $RetirementOU=""
    $SystemType=""
    Switch($Type){
        "SRV"{$RetirementOU=$RetiredSVR;$SystemType="server";Break}
        "WKS"{$RetirementOU=$RetiredWKS;$SystemType="workstation";Break}
    }
    ("Setting Offline Limit to: ["+$OfflineLimit+"].  Moving "+$SystemType+" systems that meet the Offline Limit to ["+$RetirementOU+"].")|Out-File -FilePath $LogFN1 -Append
    If($ComputerNames){
        ForEach($NetBIOS In $ComputerNames){
            [datetime]$CurrentTime=Get-Date -Format o
            $ADComputer=Get-ADComputer -Identity ($NetBIOS).Split(".")[0] -Properties IPv4Address,LastLogonDate
            [int]$DaysLastLogon=(New-TimeSpan -Start $ADComputer.LastLogonDate -End $CurrentTime).Days
            If($DaysLastLogon-gt$OfflineLimit){
                ("Adding ["+($NetBIOS).Split(".")[0]+"] to retirement folder due to being offline for ["+$DaysLastLogon+"] days.")|Out-File -FilePath $LogFN1 -Append
                If(!($ADComputer.IPv4Address)){
                    $nslookup=Test-NetConnection -ComputerName $ADComputer.DNSHostName -WarningAction SilentlyContinue
                    If(!($nslookup.PingSucceeded)){
                        ("Moved ["+($NetBIOS).Split(".")[0]+"] to the ["+$RetirementOU+"] staging OU.")|Out-File -FilePath $LogFN1 -Append
                        Move-ADObject -Identity $ADComputer.DistinguishedName -TargetPath ("OU=Workstations,OU=Retired,"+([ADSI]"").distinguishedName)
                        ("Setting computer: ["+($NetBIOS).Split(".")[0]+"] to disabled.")|Out-File -FilePath $LogFN1 -Append
                        Set-ADComputer -Identity ($NetBIOS).Split(".")[0] -Enabled $false -Confirm:$false
                        If($bToBeDeleted){
                            $CurrentHost=("CN="+([string]($NetBIOS).Split(".")[0]).ToUpper()+","+$RetirementOU)
                            [datetime]$MinimumDate=(Get-Date).AddDays($DeletionDays)
                            ("Verifying that computer: ["+$CurrentHost+"] was last logged on before; "+$MinimumDate+" so that it can be deleted.")|Out-File -FilePath $LogFN1 -Append
                            Get-ADComputer -Filter {(DistinguishedName -eq $CurrentHost)-and(LastLogonDate -le $MinimumDate)}|Remove-ADComputer -Confirm:$false
                        }
                    }
                }
            }
        }
    }
}
"Completed processing retired systems for this log file."|Out-File -FilePath $LogFN1 -Append
[datetime]$ScriptEndTime=Get-Date -Format o
$RunTime=(New-TimeSpan -Start $ScriptStartTime -End $ScriptEndTime)
("Script runtime: ["+$RunTime+"]")|Out-File -FilePath $LogFN1 -Append
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