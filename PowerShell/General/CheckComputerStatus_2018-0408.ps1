Function DeleteComputer(){
    Write-Host "Attempting to remove '$DNSHostName' from $DomainName."
    $ADIdentity=@($($Computer.DistinguishedName))
    Remove-ADComputer -Credential $AuthUser -AuthType Negotiate -Server $DomainController -Identity "$ADIdentity" -Confirm
}
Function GET-TempPassword(){Param([int]$Characters=32,[string[]]$SourceData)
    For($Loop=1;$Loop–le$Characters;$Loop++){
    $TempPassword+=($SourceData | GET-RANDOM)
    }
    Return $TempPassword
}
Function Test-ADCredential{[CmdletBinding()]Param($UserName,$Password,$HostName)
    if(!($UserName)-or!($Password)){
        Write-Warning 'Test-ADCredential: Please specify both user name and password'
    }else{
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        $DS=New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$HostName)
        $DS.ValidateCredentials($UserName,$Password)
    }
}
Function Write-CustomError{param([System.Exception]$Exception,$targetObject,[String]$errorID,[System.Management.Automation.ErrorCategory]$errorCategory="NotSpecified")
    $errorRecord=new-object System.Management.Automation.ErrorRecord($Exception,$errorID,$errorCategory,$targetObject)
    $PSCmdlet.WriteError($errorRecord)
}
Clear
$StartDate=(Get-Date).AddDays(-30).toString('M/d/yyyy')
$StartDate=[datetime]::ParseExact($StartDate,'M/d/yyyy',$null)
$ScriptName=$MyInvocation.MyCommand.Name
Write-Host "Beginning '$ScriptName' to reset the local administrator's account password."
$Ascii=$null;For($a=48;$a–le122;$a++){$ascii+=,[char][byte]$a}
$WorkingPath="C:\Users\Public\Documents"
Set-Location -Path $WorkingPath
$ImportForPMP="ImportForPMP.csv"
$ExportFile="ExportList.csv"
$SearchDomain="utshare.local"
$DomainController="dca01."+$SearchDomain
$AuthUser=$env:USERDOMAIN+"\"+$env:USERNAME
If(Test-Path $ExportFile){Remove-Item -Path $ExportFile}
Write-Host "Exporting list of domain computers to '$ExportFile'."
Get-ADComputer -Credential $AuthUser -Server $DomainController -Filter * -Property * | Select-Object Name,LastLogonDate,PasswordLastSet,OperatingSystem,IPv4Address,DNSHostName,DistinguishedName,CanonicalName | Sort-Object -Property Name | Export-CSV $ExportFile -NoTypeInformation -Encoding UTF8
Write-Host "Completed export of domain computers to '$ExportFile'."
Write-Host "Adding exported list of domain computers to memory."
$ComputerList=Import-Csv $ExportFile
$NSLookupData="nslookup.txt"
$PingResults="PingData.txt"
$ResultFile="Results.log"
$ErrorSettingPWD=$true
$ImportOS="Windows"
$DomainName=$null
[int]$PingCount=2
$DCCounter=0
Write-Host "Completed import of domain computers to memory."
If(Test-Path $ResultFile){Remove-Item -Path $ResultFile}
If(Test-Path $ImportForPMP){Remove-Item -Path $ImportForPMP}
Write-Host "Starting to process imported list of domain computers."
Write-Host ""
ForEach($Computer In $ComputerList){
    If(@($($Computer.IPv4Address).Split("."))[1]-like"118"){
        If($($Computer.OperatingSystem)-like"Windows Server*"){
            $root=$false
            $Campus=$false
            $AbleToPing=$false
            $ComputerName=$null
            $BadDNSRecord=$false
            $HostName=@($($Computer.Name)).toLower()
            $DNSHostName=@($($Computer.DNSHostName))
            $LastLogonDate=$($Computer.LastLogonDate)
            $EndDate=@($($Computer.PasswordLastSet).Split(" "))[0]
            $EndDate=[datetime]::ParseExact($EndDate,'M/d/yyyy',$null)
            $DomainName=@($($Computer.CanonicalName).Split("/"))[0]
            If(@($($Computer.CanonicalName).Split("/"))[1]-eq"AllServers"){
                $SubDomain=@($($DNSHostName).Split("."))[1]
                If($SubDomain-eq@($($SearchDomain).Split("."))[0]){
                    Switch($($HostName).Substring(0,2).toLower()){
                       "ar"{$Campus=$true;Break}
                       "da"{$Campus=$true;Break}
                       "pb"{$Campus=$true;Break}
                       "rg"{$Campus=$true;Break}
                       "ty"{$Campus=$true;Break}
                       "za"{$Campus=$true;Break}
                       "zb"{$Campus=$true;Break}
                       default{$root=$true;Break}
                    }
                    If($Campus-eq$true){
                        Switch($($HostName).Substring(4,3).toLower()){
                            "cfg"{$SubDomain="fly";Break}
                            "cnv"{$SubDomain="fly";Break}
                            "dev"{$SubDomain="dev";Break}
                            "dmo"{$SubDomain="dmo";Break}
                            "fly"{$SubDomain="fly";Break}
                            "prd"{$SubDomain="prd";Break}
                            "pum"{$SubDomain="pum";Break}
                            "rpt"{$SubDomain="prd";Break}
                            "sbx"{$SubDomain="sbx";Break}
                            "trn"{$SubDomain="trn";Break}
                            "tst"{$SubDomain="tst";Break}
                            "uat"{$SubDomain="uat";Break}
                            default{$SubDomain="all";Break}
                        }
                        $DNSHostName=@($($HostName)+"."+$($SubDomain)+"."+$($SearchDomain)).toLower()
                    }Else{
                        $DNSHostName=@($($HostName)+".inf."+$($SearchDomain)).toLower()
                    }
                    $BadDNSRecord=$true
                }
            }
            Write-Host "Working on current computer:                     $DNSHostName"
            Start-Process -FilePath "$env:comspec" -ArgumentList "/c ping $DNSHostName -n $PingCount -w 1" -RedirectStandardOutput $PingResults -WindowStyle Hidden -Wait
            $DoubleCheck={
                $ServerFound=$false
                $SearchValue="Reply from*"
                If(Test-Path $PingResults){
                    ForEach($CurrentLine In Get-Content $PingResults){
                        If($CurrentLine-like$SearchValue){
                            $AbleToPing=$true
                            Break
                        }
                    }
                    $DateDifference=(New-TimeSpan –Start $StartDate –End $EndDate).Days
                    If(($AbleToPing-eq$true)-and($ComputerName-eq$null)){
                        Write-Host "'$DNSHostName' is online." -ForegroundColor Green
                    }ElseIf(($AbleToPing-eq$true)-and!($ComputerName-eq$null)){
                        Write-Host "'$ComputerName' is online." -ForegroundColor Cyan
                        $DNSHostName=$ComputerName
                    }ElseIf(($ComputerName-eq$null)-and!($AbleToPing-eq$true)){
                        $ServerStatus="not found in Windows DNS"
                        $SearchValue="Name*$HostName*"
                        Start-Process -FilePath "$env:comspec" -ArgumentList "/c nslookup $DNSHostName" -RedirectStandardOutput $NSLookupData -WindowStyle Hidden -Wait
                        If(Test-Path $NSLookupData){
                            ForEach($CurrentLine In Get-Content $NSLookupData){
                                If($CurrentLine-like$SearchValue){
                                    $ServerStatus="not responding to ping"
                                    $ServerFound=$true
                                    Break
                                }
                            }
                            Write-Host "The server: '$DNSHostName' is $ServerStatus" -ForegroundColor Yellow -BackgroundColor DarkRed
                            Write-Host "'Last Logon Date' is: "$LastLogonDate -ForegroundColor White -BackgroundColor DarkRed
                            If(!($ServerFound-eq$true)){
                                $ComputerName=@($($HostName)+"."+$($SearchDomain)).toLower()
                                Write-Host "Attempting to ping '$ComputerName' using the root domain: '$SearchDomain'"
                                Start-Process -FilePath "$env:comspec" -ArgumentList "/c ping $ComputerName -n $PingCount -w 1" -RedirectStandardOutput $PingResults -WindowStyle Hidden -Wait
                                .$DoubleCheck
                            }ElseIf(($DateDifference-lt0)-and!($AbleToPing-eq$true)){DeleteComputer}
                        }
                    }ElseIf((!($ComputerName-eq$null)-and!($AbleToPing-eq$true))-or(($DateDifference-lt0)-and!($AbleToPing-eq$true))){
                        Write-Host "The server: '$ComputerName' is not pingable using the root domain." -ForegroundColor Yellow -BackgroundColor DarkRed;DeleteComputer
                    }
                    If(($AbleToPing-eq$true)-and($ComputerName-eq$null)){
                        $ErrorSettingPWD=$true
                        $OnlineStatus="Offline"
                        $DomainController=$false
                        Write-Host "Retrieving local account information from:       $DNSHostName"
                        If(@($($Computer.DistinguishedName))-like"*OU=Domain Controllers*"){
                            $DCCounter++;$DomainController=$true
                        }
                        If(($DCCounter-le1-and$DomainController-eq$true)-or($DomainController-eq$false)){
                            $AdminPassword=GET-TempPassword -SourceData $Ascii
                            $ComputerADSI=[ADSI] "WinNT://$($Computer.DNSHostName),Computer"
                            ForEach($ChildObject in $ComputerADSI.Children){
                                if($ChildObject.Class-ne"User"){
                                    Continue
                                }
                                $Type="System.Security.Principal.SecurityIdentifier"
                                $ChildObjectSID=new-object $Type($ChildObject.objectSid[0],0)
                                if($ChildObjectSID.Value.EndsWith("-500")){
                                    $UserName=@($($ChildObject.Name[0]))
                                    Write-Host "Local Administrator account name:                $UserName"
                                    Write-Host "Local Administrator account SID:                 $($ChildObjectSID.Value)"
                                    try{
                                        Write-Host "Attempting to change password on                 $HostName"
                                        ([ADSI] "WinNT://$HostName/$UserName").SetPassword($AdminPassword)
                                        $Resource="$HostName,$DNSHostName,,,,$ImportOS,,$UserName,$AdminPassword,,"
                                        $Resource | ForEach{Add-Content -Path $ImportForPMP -Value $_}
                                        $ErrorSettingPWD=$false
                                    }catch [System.Management.Automation.MethodInvocationException]{
                                        $Message="Cannot reset password for '$HostName\$UserName' due the following error: '$($_.Exception.InnerException.Message)'"
                                        $Exception=new-object ($_.Exception.GetType().FullName)($Message,$_.Exception.InnerException)
                                        Write-CustomError $Exception "$HostName\$UserName" $ScriptName
                                    }
                                    Write-Host "Verifying the password was changed on            $HostName"
                                    If(Test-ADCredential($UserName)($AdminPassword)($DNSHostName)){
                                        $OnlineStatus="Online"
                                        Write-Host "Successfully changed the password on             '$DNSHostName'" -ForegroundColor Green
                                    }Break
                                }
                            }
                            If($ErrorSettingPWD-eq$true){
                                $Message="Failed to retrieve user information on server:  '$DNSHostName'"
                                Add-Content -Path $ResultFile -Value $Message -PassThru
                            }ElseIf($OnlineStatus-eq"Offline"){
                                $Message="Server: $DNSHostName is not remote administration accessible"
                                Add-Content -Path $ResultFile -Value $Message -PassThru
                            }
                        }
                        Write-Host ""
                    }
                }$ComputerName=$null
            }
            If($AbleToPing-eq$false){&$DoubleCheck}
            $ChildObjectSID=$null
            $AdminPassword=$null
            $LastLogonDate=$null
            $OnlineStatus=$null
            $DNSHostName=$null
            $ChildObject=$null
            $DomainName=$null
            $HostName=$null
            $ImportOS=$null
            $UserName=$null
            $Resource=$null
            $Message=$null
            Write-Host ""
        }
    }
}
Write-Host "Completed processing imported list of local administrator's account password."
If(Test-Path $PingResults){Remove-Item -Path $PingResults}
If(Test-Path $NSLookupData){Remove-Item -Path $NSLookupData}
If(Test-Path $ExportFile){Remove-Item -Path $ExportFile -Force}
Write-Host "Deleted the temporary files from '$WorkingPath'."
$SearchValue=$null
$PingCount=$null
Set-Location -Path "C:\Windows\System32"