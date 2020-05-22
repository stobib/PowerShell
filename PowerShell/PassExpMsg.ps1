[CmdletBinding()]
param(
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string[]]$LogFileNames=@()
)
# NOTE: The below default parameter value option can be used to set default values to command line parameters
$DefaultParameterValues=@{"LogFileNames"="AccountChanges","EmailMessages"}
If(!$LogFileNames){$LogFileNames+=($DefaultParameterValues.LogFileNames)}
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
    $LogFile=(Get-Variable -Name "LogFN$($intCount)").Value
    If(!(Test-Path -Path $LogLocation)){
        New-Item -Path $LogLocation -ItemType Directory|Out-Null
    }
    $LogFiles+=$LogFile
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
[string]$ScriptTitle="Password Expiration Message"
[int64]$iPriorDays=-365
[datetime]$ScriptStartTime=Get-Date -Format o
("Beginning new log file for processing "+$ScriptTitle+" emails to end-users.")|Out-File -FilePath $LogFN1 -NoClobber
Function Clean-String($Str){ # Function to Remove special character s and punctuations from Input string
    ForEach($Char in [Char[]]"!@#$%^&*(){}|\/?><,.][+=-_"){$str=$str.replace("$Char",'')}
    Return $str
}
Function Check-Description($ADUserData){
    [string]$Desc=""
    [string]$SvcAcct="Service Account"
    [string[]]$Description=@($ADUserData).Split(" ")
    ForEach($Word In $Description){
        Switch($Word){
            {$_-Like"S*v*c*"}{$Word="Service";Break}
            {$_-Like"a*c*t*"}{$Word="account";Break}
            Default{$Word|Check-Spelling;Break}
        }
        If($Desc-eq""){
            $Desc=$Word -replace("`t|`n|`r`n"," ")
        }Else{
            $Desc=($Desc+" "+$Word -replace("`t|`n|`r`n"," "))
        }
    }
    If($Desc-eq""){$Desc=$SvcAcct}
    Try{
        Get-ADUser -Identity $ADUserData.SamAccountName|Set-ADUser -Description $Desc -WhatIf|Out-Null
        ("Changed the description on account: ["+$ADUserData.SamAccountName+"] to ["+$Desc+"]")|Out-File -FilePath $LogFN1 -Append
    }Catch{}
}
Function Check-Spelling(){[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=0,ValueFromPipeline=$True)]
        [String] $String,
        [Switch] $ShowErrors,
        [Switch] $RemoveSpecialChars)
    Process{
        If($RemoveSpecialChars){
            $String=Clean-String $String
        }
        ForEach($S in $String){
            $SplatInput=@{
                Uri="https://api.projectoxford.ai/text/v1.0/spellcheck?Proof"
                Method='Post'
            }
            $Headers=@{'Ocp-Apim-Subscription-Key'="XXXXXXXXXXXXXXXXXXXXXXXXXX"}
            $body=@{'text'=$s}
            Try{
                $SpellingErrors=(Invoke-RestMethod @SplatInput -Headers $Headers -Body $body).SpellingErrors
                $OutString=$String # Make a copy of string to replace the errorswith suggestions.
                If($SpellingErrors){  # If Errors are Found
                    ForEach($E in $spellingErrors){ # Nested ForEach to generate the Rectified string Post Spell-Check
                        If($E.Type -eq 'UnknownToken'){ # If an unknown word identified, replace it with the respective sugeestion from the API results
                            $OutString=ForEach($s in $E.suggestions.token){
                                $OutString -replace $E.token, $s
                            }
                        }Else{  # If REPEATED WORDS then replace the set by an instance of repetition
                            $OutString=$OutString -replace "$($E.token) $($E.token) ", "$($E.token) "
                        }
                    }
                    If($ShowErrors -eq $true){ # InCase ShowErrors switch is ON
                        Return $SpellingErrors|Select @{n='ErrorToken';e={$_.Token}},@{n='Type';e={$_.Type}}, @{n='Suggestions';e={($_.suggestions).token|?{$_ -ne $null}}}
                    }Else{ # Else Return the spell checked string
                        Return $OutString 
                    }
                }Else{ # When No error is found in the input string
                    Return "No errors found in the String."
                }
            }Catch{
#                "Something went wrong, please try running the script again"
            }
        }
    }
}
Function RecordActivity(){[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=0,ValueFromPipeline=$True)]
        [uint32] $iRecords,
        [string] $Header,
        [string] $Progress)
    $PercentComplete=(100.0/$giTotalRecords)*$iRecords
    $PercentComplete=[Math]::Min(99,$PercentComplete)
    Write-Progress -Activity $Header -CurrentOperation $Progress -PercentComplete $PercentComplete
}
[string[]](Set-Variable -Name UserList -Value =@)
[string[]]$CampusIDList=@("AR","AU","DA","EP","HH","HS","HT","MB","MD","PB","SA","SW","SY","TY")
[string]$Global:DomainTitle=$Domain
[string]$Global:DomainFullTitle="UT System, Shared Information Services"
[string]$Global:SelfServiceTitle=("UT System, SIS self-service password portal")
[string]$Global:SelfServiceUrl=("https://selfserve.utshare.utsystem.edu")
[string]$Global:DomainShortTitle="UTS - SIS"
[string]$Global:SvcCntrTitle="Service Center Title"
[string]$Global:SvcCntrPhone="(800) 123-4567"
[string]$Global:SvcCntrTeam="your friendly Service Center team"
[boolean]$Global:gbSvcAcct=$false
[int16]$Global:giLineWidth=120
[int64]$toFast=5
[uint16]$iLoop=0
Do{
    $iLoop++
    [uint32]$iRecordCount=0
    [string]$RecordHeader=""
    [string]$RecordProgress=""
    [uint64]$Global:giTotalRecords=0
    [datetime]$GetDate=((Get-Date).Date).AddDays($iPriorDays)
    $Records=(Get-ADUser -Filter{(PasswordLastSet -le $GetDate)} -Properties AccountExpirationDate,`
        altSecurityIdentities,Created,Description,EmailAddress,Enabled,GivenName,HomeDirectory,HomeDrive,`
        LastLogonDate,PasswordLastSet,PasswordNeverExpires,ProtectedFromAccidentalDeletion)
    ("Starting to count the number of user object records that match: PasswordLastSet "+$iPriorDays+" days.")|Out-File -FilePath $LogFN1 -Append
    ForEach($Record In $Records){$giTotalRecords++}
    ("There are ["+$giTotalRecords+"] records that match: PasswordLastSet "+$iPriorDays+" days at this time.")|Out-File -FilePath $LogFN1 -Append
    $RecordHeader=("Processing the user account records that match: PasswordLastSet ["+$iPriorDays+"] days.")
    ForEach($Record In $Records){
        $iRecordCount++
        [boolean]$gbSvcAcct=$false
        [boolean]$ByPassEmail=$false
        $RecordProgress=("Currently working on ["+$iRecordCount+"] of the ["+$giTotalRecords+"] records.")
        RecordActivity -iRecords $iRecordCount -Header $RecordHeader -Progress $RecordProgress;Start-Sleep -Milliseconds $toFast
        If(($Record.Name-eq$null)`
        -or($Record.Name-like"*tst*")`
        -or($Record.Name-like"*test*")`
        -or($Record.Name-like"*vendor*")`
        -or($Record.Name-eq$Record.Surname)`
        -or($Record.Surname-like"*test*")`
        -or($Record.Surname-eq$null)`
        -or($Record.GivenName-eq$null)`
        -or($Record.Description-like"*Built-in*")`
        -or($Record.Description-like"*Test*")`
        -or($Record.DistinguishedName-like"*Service*")`
        -or($Record.DistinguishedName-like"*CN=Users*")`
        -and($Record.DistinguishedName-notlike"*OU=Users*")`
        ){
            $gbSvcAcct=$true
            Check-Description -ADUserData $Record.Description
        }ElseIf(($Record.Name-eq$null)`
            -or($Record.Name-like"*tst*")`
            -or($Record.Name-like"*test*")`
            -or($Record.Name-like"*vendor*")`
            -or($Record.Name-eq$Record.Surname)`
            -or($Record.Surname-like"*test*")`
            -or($Record.Surname-eq$null)`
            -or($Record.GivenName-eq$null)`
            -or($Record.Description-like"*Built-in*")`
            -or($Record.Description-like"*Test*")`
            -and($Record.DistinguishedName-like"*OU=Users*")`
            -and($Record.ProtectedFromAccidentalDeletion-eq$false)){
            $gbSvcAcct=$true
            [string]$NewPath=""
            [string]$SplitPath=""
            [string]$VerifyOUStructure=""
            Check-Description -ADUserData $Record.Description
            $NewPath=(($Record.DistinguishedName).Replace("OU=Users","OU=Services")) -Split(("CN="+$Record.Name+","))
            $VerifyOUStructure=Get-ADOrganizationalUnit -Identity $NewPath
            If($VerifyOUStructure-eq""){
                $SplitPath=$NewPath -Split("OU=Services,")
                New-ADOrganizationalUnit -Name "Services" -Path $SplitPath -WhatIf|Out-Null
                ("Create new OU for [Services] to ["+$SplitPath+"]")|Out-File -FilePath $LogFN1 -Append
            }
            Get-ADUser -Identity $Record.SamAccountName|Move-ADObject -TargetPath $NewPath -WhatIf|Out-Null
            ("Changed the OU for ["+$Record.SamAccountName+"] to ["+$NewPath+"]")|Out-File -FilePath $LogFN1 -Append
        }
        If($gbSvcAcct-eq$true){
            If($Record.PasswordNeverExpires-eq$false){
                Get-ADUser -Identity $Record.SamAccountName|Move-ADObject -PasswordNeverExpires $true -WhatIf|Out-Null
                ("Changed the [Password Never Expires] value to ["+$true+"] for ["+$Record.SamAccountName+"]")|Out-File -FilePath $LogFN1 -Append
            }
        }
        If($gbSvcAcct-eq$false){
            [string]$HomeDir=""
            [string]$HomeDrv="W:"
            [string]$TestID=($Record.Name).ToUpper()
            $TestID=$TestID[0..($TestID.length)][0]+$TestID[0..($TestID.length)][1]
            [string](Set-Variable -Name Greeting -Value "Good ")
            ForEach($CampusID In $CampusIDList){
                Switch($TestID){
                    $CampusID{$TestID=$CampusID;Break}
                    Default{$TestID="SY"}
                }
            }
            If(($Record.HomeDirectory-like"*replication*")-or($Record.HomeDirectory-eq$null)){
                $HomeDir=("\\"+$Domain+"\cifs\Users\"+$TestID+"\"+$Record.Name)
                Try{
                    Get-ADUser -Identity $Record.SamAccountName|Set-ADUser -HomeDirectory $HomeDir -WhatIf
                    ("Changed the [Home Directory] for ["+$Record.SamAccountName+"] to ["+$HomeDir+"]")|Out-File -FilePath $LogFN1 -Append
                    If(Test-Path -Path $HomeDir){
                        New-Item -Path $HomeDir -ItemType Directory|Out-Null
                        ("Changed the [Home Directory] for ["+$Record.SamAccountName+"] had to be created")|Out-File -FilePath $LogFN1 -Append
                    }
                }Catch{
                }
            }
            If(!$Record.HomeDrive-eq"W:"){
                Try{
                    Get-ADUser -Identity $Record.SamAccountName|Set-ADUser -HomeDrive $HomeDrv -WhatIf
                    ("Changed the [Home Drive] for ["+$Record.SamAccountName+"] to ["+$HomeDrv+"]")|Out-File -FilePath $LogFN1 -Append
                }Catch{
                }
            }
            [string]$SendToAddress=""
            If($Record.EmailAddress-eq$null){
                If($Record.altSecurityIdentities-ne$null){
                    Get-ADUser -Identity $Record.SamAccountName|Set-ADUser -EmailAddress $Record.altSecurityIdentities -WhatIf
                    ("Added the [Email Address] for ["+$Record.SamAccountName+"] to ["+$Record.altSecurityIdentities+"]")|Out-File -FilePath $LogFN1 -Append
                    $SendToAddress=$Record.altSecurityIdentities
                }Else{
                    $ByPassEmail=$true
                }
            }Else{
                $SendToAddress=$Record.EmailAddress
            }
            If($Record.PasswordNeverExpires-eq$true){
                Get-ADUser -Identity $Record.SamAccountName|Move-ADObject -PasswordNeverExpires $false -WhatIf
                ("Changed the [Password Never Expires] value to ["+$false+"] for ["+$Record.SamAccountName+"]")|Out-File -FilePath $LogFN1 -Append
            }
            [uint16]$GetTime=(Get-Date).Hour
            Switch($GetTime){
                {$_-lt12}{($Greeting+="morning")|Out-Null;Break}
                {$_-lt18}{($Greeting+="afternoon")|Out-Null;Break}
                Default{($Greeting+="evening")|Out-Null;Break}
            }
            If($ByPassEmail-eq$false){
                ("Scripting message to be sent to ["+$Record.SamAccountName+"] using email address: ["+$SendToAddress+"]")|Out-File -FilePath $LogFN2 -Append
                ("-"*$giLineWidth)|Out-File -FilePath $LogFN2 -Append
                $TextInfo=(Get-Culture).TextInfo
                $UserName=$TextInfo.ToTitleCase(($Record.GivenName).ToLower())
                [string]$MessageBody=($Greeting+" "+$UserName+",`r`n") # |Out-Host
                [string]$strDate=(($Record.PasswordLastSet).Date).tostring("MM/dd/yyyy")
                $MessageBody+=("This is a reminder that your "+$DomainFullTitle+" password is set to expire on "+$strDate+".  Your "+$DomainShortTitle+" credentials are used for accessing "+$DomainTitle+" on the "+$DomainShortTitle+" network.`r`n") # |Out-Host
                $MessageBody+=("Passwords may be changed either while logged into a remote desktop workstation (RDP System) or from "+$SelfServiceUrl+".  If your using an RDP System, you can press the key combination [CTRL+ALT+END] to bring up the security menu on the remote workstation.  From there you can select to change your password, or you can use the self-service portal.  The "+$SelfServiceTitle+" site is your self-service website for changing your "+$DomainTitle+" password.`r`n") # |Out-Host
                $MessageBody+=("A brief set of instructions is given below.  Please contact the "+$SvcCntrTitle+" "+$SvcCntrPhone+", if you have any questions.`r`n") # |Out-Host
                $TitleBlock=$TextInfo.ToTitleCase(($SvcCntrTeam).ToLower())
                $MessageBody+=("Thank You,`r`n"+$TitleBlock+"`r`n") # |Out-Host
                $MessageBody+=("This message has been digitally signed by the "+$SvcCntrTitle+".  To examine the signature, click the red ribbon icon in the upper right corner of this message.  If you would like to further verify the authenticity of this message, please contact "+$SvcCntrPhone+".`r`n") # |Out-Host
                ($MessageBody)|Out-File -FilePath $LogFN2 -Append
                
                ("-"*$giLineWidth)|Out-File -FilePath $LogFN2 -Append
            }Else{
            }
        }
    }
    Write-Progress -Activity $RecordHeader -Status $RecordProgress -Completed
}Until($iLoop-eq1)
"Completed processing the "+$ScriptTitle+" script for sending end-users that are ["+$iPriorDays+"] days out of Maximum Password Age."|Out-File -FilePath $LogFN1 -Append
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