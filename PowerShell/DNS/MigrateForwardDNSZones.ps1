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
Set-Variable -Name DnsServers -Value @("w19dnsasy01","w19dnsasy02","w19dnsasz01","w19dnsasz02")
Set-Variable -Name AllDCs -Value @(Get-ADDomainController -Filter *|Select-Object HostName,IsGlobalCatalog|Sort HostName|Where-Object{$_.IsGlobalCatalog-eq$true}).HostName
ForEach($GC In $AllDCs){
    $DnsServer=@(Get-DnsServer -ComputerName $GC).ServerSetting.ComputerName
    Set-Variable -Name ForwardZones -Value @(Get-DnsServerZone -ComputerName $DnsServer|Where-Object{$_.ZoneName -like ("*"+$Domain)})
    ForEach($ZoneData In $ForwardZones){
        If($ZoneData.ZoneName-notlike"_*"){
            $ZoneName=$ZoneData.ZoneName
            $ZoneFile=($ZoneName+".dns")
            $FullPath=("\\"+$DnsServer+"\Admin$\System32\DNS\"+$ZoneFile)
            If(Test-Path -Path $FullPath){
                Remove-Item $FullPath -Force
            }
            DNSCMD $DnsServer /ZoneExport $ZoneName $ZoneFile
            If(!(Test-Path -Path ($ZoneFile+"\"+$ZoneFile))){
                ForEach($NewServer In $DnsServers){
                    $PrimaryDNS=($NewServer+"."+$Domain)
                    $Destination=("\\"+$PrimaryDNS+"\DNS$")
                    If(!(Test-Path -Path ($Destination+"\"+$ZoneFile))){
                        XCopy $FullPath $Destination
                        If(Test-Path -Path ($Destination+"\"+$ZoneFile)){
                            DNSCMD $PrimaryDNS /ZoneAdd $ZoneName /Primary /File $ZoneFile /Load
                        }
                    }
                }
            }
        }
    }
}
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