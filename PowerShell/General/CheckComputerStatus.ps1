Function CheckConnectivity{param([string]$SearchObject,[string]$SearchValue)
    Start-Process -FilePath "$env:comspec" -ArgumentList "/c ping $SearchObject -n $PingCount -w 1" -RedirectStandardOutput $PingResults -WindowStyle Hidden -Wait
    If(Test-Path $PingResults){
        ForEach($CurrentLine In Get-Content $PingResults){
            If($CurrentLine-like$SearchValue){
                Return $true;Break
            }
        }Return $false
    }
}
Function DeleteComputer{
    Write-Host "Attempting to remove '$DNSHostName' from $DomainName."
    $ADIdentity=@($($Computer.DistinguishedName))
    Remove-ADComputer -Credential $AuthUser -AuthType Negotiate -Server $DomainController -Identity "$ADIdentity" -Confirm
}
Function DisplayMessage{param([string]$Description,[string]$StatusMessage,$FontColor="White",$Background="DarkBlue")
    [int]$Buffer=$RightAlign-$Description.Length
    Write-Host @($($Description)) @($($StatusMessage).PadLeft($Buffer)) -ForegroundColor $FontColor -BackgroundColor $Background
    Return $($Description)
}
Function DNSLookup{param([string]$ObjectValue,[string]$SearchValue)
    Start-Process -FilePath "$env:comspec" -ArgumentList "/c nslookup $ObjectValue" -RedirectStandardOutput $NSLookupData -WindowStyle Hidden -Wait
    If(Test-Path $NSLookupData){
        ForEach($CurrentLine In Get-Content $NSLookupData){
            If($CurrentLine-like$SearchValue){
                Return $true;Break
            }
        }Return $false
    }
}
Function GetTempPassword{Param([int]$Characters=32,[string[]]$SourceData)
    For($Loop=1;$Loop–le$Characters;$Loop++){
    $TempPassword+=($SourceData | GET-RANDOM)
    }
    Return $TempPassword | ConvertTo-SecureString -AsPlainText -Force
}
Function TestCredential{[CmdletBinding()]Param($UserName,$Password,$HostName)
    if(!($UserName)-or!($Password)){
        Write-Warning 'TestCredential: Please specify both user name and password'
    }else{
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        $DS=New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$HostName)
        $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        $UnsecurePassword=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $DS.ValidateCredentials($UserName,$UnsecurePassword)
    }
}
Function VerifyIPv4Address{
    Switch(@($($Computer.IPv4Address).Split("."))[2]){
        {($_-ge4-and$_-le7)-or($_-ge20-and$_-le23)-or($_-ge36-and$_-le39)-or($_-ge52-and$_-le55)-or($_-ge68-and$_-le712)-or($_-ge84-and$_-le87)}{$SubDomain="prd";Break}
        {($_-eq10)-or($_-eq26)-or($_-eq42)-or($_-eq58)-or($_-eq74)-or($_-eq90)}{$SubDomain="trn";Break}
        {($_-eq11)-or($_-eq27)-or($_-eq43)-or($_-eq59)-or($_-eq75)-or($_-eq91)}{$SubDomain="sbx";Break}
        {($_-eq12)-or($_-eq28)-or($_-eq44)-or($_-eq60)-or($_-eq76)-or($_-eq92)}{$SubDomain="tst";Break}
        {($_-eq13)-or($_-eq29)-or($_-eq45)-or($_-eq61)-or($_-eq77)-or($_-eq93)}{$SubDomain="dev";Break}
        {($_-eq14)-or($_-eq30)-or($_-eq46)-or($_-eq62)-or($_-eq78)-or($_-eq94)}{$SubDomain="dmo";Break}
        {($_-eq8)-or($_-eq24)-or($_-eq40)-or($_-eq56)-or($_-eq72)-or($_-eq88)}{$SubDomain="uat";Break}
        {($_-eq9)-or($_-eq25)-or($_-eq41)-or($_-eq57)-or($_-eq73)-or($_-eq89)}{$SubDomain="fly";Break}
        {($_-eq64)-or($_-eq65)}{$SubDomain="bkp";Break}
        {($_-eq18)-or($_-eq19)}{$SubDomain="vdi";Break}
        {($_-eq0)-or($_-eq1)}{$SubDomain="inf";Break}
        {($_-eq2)}{$SubDomain="mgt";Break}
        Default{$SubDomain="all";Break}
    }Return $SubDomain
}
Function WriteCustomError{param([System.Exception]$Exception,$targetObject,[string]$errorID,[System.Management.Automation.ErrorCategory]$errorCategory="NotSpecified")
    $errorRecord=new-object System.Management.Automation.ErrorRecord($Exception,$errorID,$errorCategory,$targetObject)
    $PSCmdlet.WriteError($errorRecord)
}
Clear-Host;Clear-History
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
$SharedFile="\\fs8600a1.inf.utshare.local\sysadm\pmp\$ImportForPMP"
Write-Host "Retrieving list of domain computers from the'$SearchDomain' domain."
Write-Host "Exporting list of domain computers to '$WorkingPath\$ExportFile'."
$Headers='ResourceName','DNSName','Description','Department','Location','ResourceType','ResourceURL','UserAccount','Password','Notes','DistinguishedName'
Get-ADComputer -Credential $AuthUser -Server $DomainController -Filter * -Property * | Select-Object Name,LastLogonDate,PasswordLastSet,OperatingSystem,IPv4Address,DNSHostName,DistinguishedName,CanonicalName | Sort-Object -Property Name | Export-CSV $ExportFile -NoTypeInformation -Encoding UTF8
$ShowHeaders='DNSName','UserAccount','Password'
$FileData="TempImport.csv"
If(Test-Path $ExportFile){
    Write-Host "Completed export of domain computers to '$ExportFile'."
    Write-Host "Adding exported list of domain computers to memory."
    $ComputerList=Import-Csv $ExportFile
    $NSLookupData="nslookup.txt"
    $PingResults="PingData.txt"
    $ResultFile="Results.log"
    $AliasesFound=$true
    [int]$RightAlign=87
    $ImportOS="Windows"
    $ImportSheet=$null
    $DomainName=$null
    [int]$PingCount=2
    $IPv4Found=$false
    $ProcessDC=$false
    $Aliases=$null
    $DCCounter=0
    Write-Host "Completed import of domain computers to memory."
    If(Test-Path $ResultFile){Remove-Item -Path $ResultFile}
    If(Test-Path $ImportForPMP){Remove-Item -Path $ImportForPMP}
    Write-Host "Starting to process imported list of domain computers."
    $Message=DisplayMessage -Description "" -Background "Black"
    ForEach($Computer In $ComputerList){
        If(@($($Computer.IPv4Address).Split("."))[1]-like"118"){
            $IPv4Address=$($Computer.IPv4Address).ToString()
            If($($Computer.OperatingSystem)-like"Windows Server*"){
                $Message=DisplayMessage -Description "" -Background "Black"
                $root=$false
                $Campus=$false
                $Disabled=$null
                $SubDomain=$null
                $ProcessDC=$false
                $ErrorSettingPWD=$true
                $OnlineStatus="Offline"
                $HostName=@($($Computer.Name)).toLower()
                $LastLogonDate=$($Computer.LastLogonDate)
                $DNSHostName=@($($Computer.DNSHostName).toLower())
                $EndDate=@($($Computer.PasswordLastSet).Split(" "))[0]
                $EndDate=[datetime]::ParseExact($EndDate,'M/d/yyyy',$null)
                $DomainName=@($($Computer.CanonicalName).Split("/"))[0]
                $Message=DisplayMessage -Description "Working on current computer:" -StatusMessage $DNSHostName
                $AbleToPing=CheckConnectivity -SearchObject $DNSHostName -SearchValue ("Reply from*")
                If(!($AbleToPing)){$Message=DisplayMessage -Description "Not able to ping $DNSHostName by using hostname" -FontColor "Yellow" -Background "DarkRed"}
                If($AbleToPing){$Message=DisplayMessage -Description "'$DNSHostName' is online." -StatusMessage ($IPv4Address) -FontColor "Yellow"}
                $ServerFound=DNSLookup -ObjectValue $DNSHostName -SearchValue ("Name*"+$HostName+"*")
                If(!($ServerFound)){$Message=DisplayMessage -Description "Not able to resolve Forward DNS for $DNSHostName" -FontColor "Yellow" -Background "DarkRed"}
                $SubDomain=@($($DNSHostName).Split("."))[1]
                Switch($($HostName).Substring(0,2).toLower()){
                    {($_-eq"ar")-or($_-eq"da")-or($_-eq"pb")-or($_-eq"rg")-or($_-eq"ty")-or($_-eq"za")-or($_-eq"zb")}{$Campus=$true;Break}
                    default{$Campus=$false;Break}
                }
                If($Campus-eq$true){
                    Switch($($HostName).Substring(4,3).toLower()){
                        {($_-eq"cfg")-or($_-eq"cnv")}{$CheckSubDomain="fly";Break}
                        {($_-eq"prd")-or($_-eq"rpt")}{$CheckSubDomain="prd";Break}
                        "dev"{$CheckSubDomain="dev";Break}
                        "dmo"{$CheckSubDomain="dmo";Break}
                        "fly"{$CheckSubDomain="fly";Break}
                        "pum"{$CheckSubDomain="pum";Break}
                        "sbx"{$CheckSubDomain="sbx";Break}
                        "trn"{$CheckSubDomain="trn";Break}
                        "tst"{$CheckSubDomain="tst";Break}
                        "uat"{$CheckSubDomain="uat";Break}
                        Default{$CheckSubDomain=$null;Break}
                    }
                    If(($SubDomain-eq$null)-or!($SubDomain-eq$CheckSubDomain)){$SubDomain=VerifyIPv4Address}
                    $ZoneName=$SubDomain+"."+$SearchDomain
                    If(($Campus-eq$true)-and($HostName.Length-le9)){
                        $Aliases=$HostName.Substring(0,4)+$SubDomain+$HostName.Substring(4,5)
                    }
                    If((!($ServerFound)-or!($AbleToPing))-or($HostName.Length-le9)){
                        $ServerFound=DNSLookup -ObjectValue $IPv4Address -SearchValue ("Name*"+$HostName+"*")
                        $IPv4Found=DNSLookup -ObjectValue $IPv4Address -SearchValue ("Address*"+$IPv4Address)
                        $AliasesFound=DNSLookup -ObjectValue $Aliases -SearchValue ("Address*"+$IPv4Address)
                        $AbleToPing=CheckConnectivity -SearchObject $IPv4Address -SearchValue ("Reply from*")
                        $DNSHostName=@($($HostName)+"."+$($ZoneName)).toLower()
                        If($IPv4Found-and$AbleToPing){
                            If(($ServerFound-eq$true)-and!($AliasesFound-eq$true)){
                                $Message=DisplayMessage -Description "Creating CNAME for '$Aliases'" -FontColor "Cyan"
                                Add-DnsServerResourceRecordCName -ComputerName $DomainController -Name $Aliases -ZoneName $ZoneName -HostNameAlias $($DNSHostName)
                            }
                            If($AbleToPing-and!($ServerFound)){
                                $Message=DisplayMessage -Description "Creating A Record for '$HostName'" -FontColor "Cyan"
                                Add-DnsServerResourceRecordA -ComputerName $DomainController -Name $HostName -ZoneName $ZoneName -AllowUpdateAny -IPv4Address $IPv4Address
                            }
                        }
                    }
                }
                $DomainControllers=@($($Computer.CanonicalName).Split("/"))[1]-eq"Domain Controllers"
                If($DomainControllers){
                    $DCCounter++
                    $AbleToPing=CheckConnectivity -SearchObject $DNSHostName -SearchValue ("Reply from*")
                    If(!$AbleToPing){
                        $Message=DisplayMessage -StatusMessage "Not able to access domain controller at this time." -FontColor "Yellow" -Background "DarkRed"
                        $DCCounter--
                    }
                    If($DCCounter-eq1){
                        $Message=DisplayMessage -StatusMessage "Processing first available domain controller in the list." -FontColor "Green"
                        $ProcessDC=$true
                    }
                }Else{
                    If(!($ServerFound)-or!($AbleToPing)){
                        If(!($ServerFound)){
                            $ServerFound=DNSLookup -ObjectValue $IPv4Address -SearchValue ("Name*"+$HostName+"*")
                            If(!($ServerFound)){$Message=DisplayMessage -Description "Not able to resolve $DNSHostName using Reverse DNS" -FontColor "Yellow" -Background "DarkRed"}
                        }
                        If(!($AbleToPing)){
                            $AbleToPing=CheckConnectivity -SearchObject $IPv4Address -SearchValue ("Reply from*")
                            If(!($AbleToPing)){$Message=DisplayMessage -Description "Not able to ping $DNSHostName by using IP Address" -FontColor "Yellow" -Background "DarkRed"}
                        }
                    }
                }
                $DateDifference=(New-TimeSpan –Start $StartDate –End $EndDate).Days
                $Message=DisplayMessage -Description "'$DateDifference' day(s) until computer account password is changed."
                If((($DateDifference-eq0)-and!($AbleToPing))-or($DateDifference-lt0)){
                    $Message=DisplayMessage -Description "The computer hasn't changed it's password in over 30 days." -FontColor "Yellow" -Background "DarkRed"
                    $Message=DisplayMessage -Description "If the computer isn't able to successfully change the" -FontColor "Yellow" -Background "DarkRed"
                    $Message=DisplayMessage -Description "computer account password, it will risk becoming stale." -FontColor "Yellow" -Background "DarkRed"
                }
                If(($ProcessDC-eq$true)-or!($DomainControllers)){
                    $ComputerADSI=[ADSI] "WinNT://$($Computer.DNSHostName),Computer"
                    ForEach($ChildObject in $ComputerADSI.Children){
                        if($ChildObject.Class-ne"User"){
                            Continue
                        }
                        $Type="System.Security.Principal.SecurityIdentifier"
                        $ChildObjectSID=new-object $Type($ChildObject.objectSid[0],0)
                        if($ChildObjectSID.Value.EndsWith("-500")){
                            $UserName=@($($ChildObject.Name[0]))
                            $Message=DisplayMessage -Description "Local Administrator account name:" -StatusMessage $UserName
                            $Message=DisplayMessage -Description "Local Administrator account SID:" -StatusMessage $($ChildObjectSID.Value)
                            try{
                                $Disabled=$true <#
                                $AdminPassword=GetTempPassword -SourceData $Ascii
                                $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword)
                                $UnsecurePassword=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                                $Message=DisplayMessage -Description "Attempting to change password on" -StatusMessage $HostName
                                ([ADSI] "WinNT://$HostName/$UserName").SetPassword($UnsecurePassword);$Disabled=$false
                                $Resource="$HostName,$DNSHostName,,,,$ImportOS,,$UserName,$UnsecurePassword,,"
                                $Resource | ForEach{Add-Content -Path $ImportForPMP -Value $_}#>
                                $ErrorSettingPWD=$false
                            }catch [System.Management.Automation.MethodInvocationException]{
                                $Message="Cannot reset password for '$HostName\$UserName' due the following error: '$($_.Exception.InnerException.Message)'"
                                $Exception=new-object ($_.Exception.GetType().FullName)($Message,$_.Exception.InnerException)
                                WriteCustomError $Exception "$HostName\$UserName" $ScriptName
                            }
                            If($Disabled){
                                $ImportSheet=Import-Csv -LiteralPath $SharedFile -Header $Headers | Select $ShowHeaders | where {$_.DNSName-eq$DNSHostName}
                                $ImportSheet | Export-CSV $FileData -NoTypeInformation
                                $ImportSheet | ForEach-Object{
                                    ForEach($Property In $_.PSObject.Properties){
                                        Switch($Property.Name){
                                            "DNSName"{$DNSHostName=$Property.Value;Break}
                                            "UserAccount"{$UserName=$Property.Value;Break}
                                            "Password"{$AdminPassword=$Property.Value | ConvertTo-SecureString -AsPlainText -Force;Break}
                                        }
                                    }
                                }
                            }
                            If(TestCredential($UserName)($AdminPassword)($DNSHostName)){
                                $Message=DisplayMessage -Description "Successfully changed the password on" -StatusMessage $DNSHostName -FontColor "Green"
                                $OnlineStatus="Online"
                            }Break
                        }
                    }
                    If($ErrorSettingPWD-eq$true){
                        $Message=DisplayMessage -Description "Failed to retrieve user information on server: $DNSHostName" -FontColor "Yellow" -Background "DarkRed"
                        Add-Content -Path $ResultFile -Value $Message
                    }ElseIf($OnlineStatus-eq"Offline"){
                        $Message=DisplayMessage -Description "Server: $DNSHostName is not remote administration accessible" -FontColor "Yellow" -Background "DarkRed"
                        Add-Content -Path $ResultFile -Value $Message
                    }
                }
                $ChildObjectSID=$null
                $AdminPassword=$null
                $LastLogonDate=$null
                $ServerFound=$false
                $AliasesFound=$true
                $OnlineStatus=$null
                $ComputerName=$null
                $AbleToPing=$false
                $DNSHostName=$null
                $ChildObject=$null
                $ImportSheet=$null
                $IPv4Found=$false
                $DomainName=$null
                $HostName=$null
                $UserName=$null
                $Resource=$null
                $Aliases=$null
                $Message=$null
                $Message=DisplayMessage -Description "" -Background "Black"
            }
        }
    }
    $Message=DisplayMessage -Description "Completed processing imported list of local administrator's account password."
}
If(Test-Path $FileData){Remove-Item $FileData}
If(Test-Path $ExportFile){Remove-Item -Path $ExportFile -Force}
If(Test-Path $PingResults){Remove-Item -Path $PingResults -Force}
If(Test-Path $NSLookupData){Remove-Item -Path $NSLookupData -Force}
Write-Host "Deleted the temporary files from '$WorkingPath'."
$DomainController=$null
$ImportForPMP=$null
$SearchValue=$null
$ShowHeaders=$null
$WorkingPath=$null
$ExportFile=$null
$SharedFile=$null
$PingCount=$null
$ImportOS=$null
$Headers=$null
Set-Location -Path "C:\Windows\System32"