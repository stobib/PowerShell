Function DateDiff{param([datetime]$StartDate,$EndDate)
    $LastPass=[datetime]::ParseExact($EndDate,'M/d/yyyy',$null)
    $Days=(New-TimeSpan –Start $ResetDate –End $LastPass).Days
    Return $($Days)
}
Function DisplayMessage{param([string]$Description,[string]$StatusMessage,$FontColor="Yellow",$Background="Black")
    [int]$Buffer=$RightAlign-$Description.Length
    $Message=$Description+" "+$StatusMessage.PadLeft($Buffer)
    Write-Host $Message -ForegroundColor $FontColor -BackgroundColor $Background
#    Add-Content -Path $ResultFile -Value $Message -PassThru
    Return $($Description)
}
Function DNSLookup{param([string]$ObjectValue,[string]$SearchValue)
    If(Test-Path $NSLookupData){Remove-Item -Path $NSLookupData -Force}
    Start-Process -FilePath "$env:comspec" -ArgumentList "/c nslookup $ObjectValue" -RedirectStandardOutput $NSLookupData -WindowStyle Hidden -Wait
    If(Test-Path $NSLookupData){
        ForEach($CurrentLine In Get-Content $NSLookupData){
            If($CurrentLine-like$SearchValue){
                Return $true,$ResolvedIP
                If($SearchValue-like"Name*"){
                    $SearchValue="Address*"
                }Else{
                    $ResolvedIP=@($CurrentLine).ToString().Split(":")[1]
                    Break
                }
            }
        }Return $false,$ResolvedIP
    }
}
Function ProcessPing{param([string]$ObjectValue,[string]$SearchValue)
    If(Test-Path $PingResults){Remove-Item -Path $PingResults -Force}
    Start-Process -FilePath "$env:comspec" -ArgumentList "/c ping $ObjectValue" -RedirectStandardOutput $PingResults -WindowStyle Hidden -Wait
    If(Test-Path $PingResults){
        ForEach($CurrentLine In Get-Content $PingResults){
            If($CurrentLine-like$SearchValue){
                Return $true,$ResolvedIP
                Break
            }ElseIf($ObjectValue-like"-a *"){
                If($CurrentLine-like"*$ForwardDNS*"){
                    $ResolvedIP=$CurrentLine.Split(" ")[2]
                    $ResolvedIP=$ResolvedIP.Remove(0,1)
                    $Len=$ResolvedIP.Length
                    $ResolvedIP=$ResolvedIP.Remove($Len-1,1)
                    $ForwardLookup=$true
                }
            }
        }Return $false,$ResolvedIP
    }
}
Function TimeDiff{param([datetime]$StartDate,$EndDate)
    $MinsPast=[datetime]::ParseExact($EndDate,'H:mm:ss-M/d/yyyy',$null)
    $Minutes=(New-TimeSpan –Start $StartDate –End $MinsPast).Minutes
    Return $($Minutes)
}
Function ZoneName{param([int]$Octate3)
    Switch($Octate3){
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
Clear-Host;Clear-History
$ResetDate=(Get-Date).AddDays(-30).toString('M/d/yyyy')
$ResetDate=[datetime]::ParseExact($ResetDate,'M/d/yyyy',$null)
$BGC=(Get-Host).UI.RawUI.BackgroundColor
$FGC=(Get-Host).UI.RawUI.ForegroundColor
$Buffer=(Get-Host).UI.RawUI.BufferSize
$WorkingPath="C:\Users\Public\Documents"
[int]$RightAlign=$Buffer.Width-2
Set-Location -Path $WorkingPath
$ResultFile="Results.log"
$ForwardLookup=$false;$ReverseLookup=$false;$GoodIPAddress=$null;$ValidDCName=$false;$SearchDomain=$null;$BadIPAddress=$null
$BadComputer=$null;$UserDomain=$null;$ForwardDNS=$null;$HostName=$null;$UserName=$null;$AuthUser=$null;$Active=$false;$ResolvedIP=$null
$Counter=$null;$Message=$null;$FocusDC=$null;$DCCount=$null;$DCList=$null;$SystemList=@(0,1,2,3,4,5);$CorrectZone=$false
Do{
    $Counter++
    Switch($Counter){
        "1"{$Prompt="Enter your search domain";Break}
        Default{$Prompt="Enter the FQDN, please";Break}
    }
    $SearchDomain=Read-Host -Prompt $Prompt
    $SearchDomain=$SearchDomain.ToLower()
    If(($SearchDomain-eq"")-or($SearchDomain-eq$null)){$SearchDomain=$env:USERDOMAIN}
}Until($SearchDomain-like'*.*')
$UserDomain=$SearchDomain.Split(".")[0].ToUpper()
$UserName=Read-Host -Prompt 'Enter your credentials[username]'
If($UserName-eq$null){$UserName=$env:USERNAME}
$UserName=$UserName.ToLower()
$AuthUser=$UserDomain+"\"+$UserName
$Counter=$null
Do{
    $Counter++
    Switch($Counter){
        "1"{$DomainController=Read-Host -Prompt "Enter the name a domain controller for $SearchDomain";Break}
        Default{$DomainController=$DomainController+"."+$SearchDomain;Break}
    }
    If($DomainController-eq""){$DomainController="dca01."+$SearchDomain}
}Until($DomainController-like'*.*')
$DomainController=$DomainController.Split(".")[0].ToLower()
$ExportFile="ExportList-$DomainController.csv"
$DomainController=$DomainController+"."+$SearchDomain
$FilterBy='ObjectClass -eq "Computer"'
$StartTime=(Get-Date).AddDays(-30).toString('yyyy/M/d H:mm:ss')
$StartTime=[datetime]::ParseExact($StartTime,'yyyy/M/d H:mm:ss',$null)
If(Test-Path $ResultFile){Remove-Item -Path $ResultFile}
$Message=DisplayMessage -Description ""
$Message=DisplayMessage -Description "Retrieving list of domain computers for the'$SearchDomain' domain from $DomainController,"
$Message=DisplayMessage -Description "and exporting list of domain computers to '$WorkingPath\$ExportFile'."
$Headers='Name','LastLogonDate','PasswordLastSet','OperatingSystem','IPv4Address','DNSHostName','DistinguishedName','CanonicalName'
#If(Test-Path $ExportFile){Remove-Item -Path $ExportFile}
#Get-ADComputer -Credential $AuthUser -Server $DomainController -Filter $FilterBy -Property $Headers | Select-Object $Headers | Sort-Object -Property Name | Export-CSV $ExportFile -NoTypeInformation -Encoding UTF8
If(Test-Path $ExportFile){
    $Message=DisplayMessage -Description "Completed export of domain computers to '$ExportFile'."
    $Message=DisplayMessage -Description "Adding exported list of domain computers to memory.  Searching for other Domain Controllers..."
    $ComputerList=Import-Csv $ExportFile
    $Counter=$null
    ForEach($Computer In $ComputerList){
        If($Computer.CanonicalName-like"*Domain Controller*"){
            If(($Computer.DNSHostName).ToLower()-eq$DomainController){
                $FocusDC=$Computer.Name
                $ValidDCName=$true
            }Else{
                $Counter++
                Switch($Counter){
                    "1"{$DCList=($Computer.DNSHostName).ToLower();Break}
                    Default{$DCList=$DCList+","+($Computer.DNSHostName).ToLower();Break}
                }
            }
        }
    }
    If($ValidDCName-eq$true){
        $Counter=$null
        $DCCount=0
<#        ForEach($DC in $DCList.Split(",")){
            $NewDC=$DC.Split(".")[0]
            $FileName=$ExportFile.Replace($FocusDC.ToLower(),$NewDC)
            $Message=DisplayMessage -Description ""
            $Message=DisplayMessage -Description "Retrieving list of domain computers from $NewDC.$SearchDomain,"
            $Message=DisplayMessage -Description "and exporting list of domain computers to '$WorkingPath\$FileName'."
            If(Test-Path $FileName){Remove-Item -Path $FileName}
            Get-ADComputer -Credential $AuthUser -Server $DC -Filter $FilterBy -Property $Headers | Select-Object $Headers | Sort-Object -Property Name | Export-CSV $FileName -NoTypeInformation -Encoding UTF8
            $Message=DisplayMessage -Description "Completed export of domain computers to '$FileName'."
            $SystemList[$DCCount]=Import-Csv $FileName
            $DCCount++
        }#>
        $ImportForPMP="ImportForPMP.csv"
        $NSLookupData="nslookup.txt"
        $PingResults="PingData.txt"
        $ResultFile="Results.log"
        $AliasesFound=$true
        $Message=DisplayMessage -Description "Completed import of domain computers to memory."
        If(Test-Path $ResultFile){Remove-Item -Path $ResultFile}
        If(Test-Path $ImportForPMP){Remove-Item -Path $ImportForPMP}
        $Message=DisplayMessage -Description "Starting to process imported list of domain computers." -FontColor "Cyan"
        For($Loop=0;$Loop-le2;$Loop++){
            $Message=DisplayMessage -Description "" -Background "Black"
        }
        ForEach($Computer In $ComputerList){
            $ForwardDNS=$($Computer.DNSHostName).ToLower()
            $CheckForwardDNS=$false
            $CheckReverseDNS=$false
            $ForwardLookup=$false
            $IPv4AddressAD=$null
            $ResolvedIP=$null
            $OS=$Computer.OperatingSystem.ToLower()
            If(($OS-like"*8*")-or($OS-like"*10*")){$OS="workstation"}Else{$OS=$null}
            $Active=$false
            If(!$OS-eq"workstation"){
                $HostName=$($Computer.Name).ToUpper()
                $DaysPast=DateDiff -StartDate $ResetDate -EndDate (@($($Computer.PasswordLastSet).Split(" "))[0])
                If(!$($Computer.LastLogonDate)-eq""){
                    $DaysLogon=DateDiff -StartDate $ResetDate -EndDate (@($($Computer.LastLogonDate).Split(" "))[0])
                    If((0-lt$DaysPast)-or(0-lt$DaysLogon)){
                        $Active=$true
                        $Message=DisplayMessage -Description "$($HostName.ToLower()) changed it's password and/or logged into the '$SearchDomain' domain within 30 days" -FontColor "White" -Background "DarkMagenta"
                    }Else{
                        For($Counter=0;$Counter-le$DCCount;$Counter++){
                            ForEach($CN In $SystemList[$Counter]){
                                If($CN.Name-eq$HostName){
                                    $DaysPast=DateDiff -StartDate $ResetDate -EndDate (@($($CN.PasswordLastSet).Split(" "))[0])
                                    If(!$($CN.LastLogonDate)-eq""){
                                        $DaysLogon=DateDiff -StartDate $ResetDate -EndDate (@($($CN.LastLogonDate).Split(" "))[0])
                                        If((0-lt$DaysPast)-or(0-lt$DaysLogon)){
                                            $Message=DisplayMessage -Description "$($HostName.ToLower()) changed it's password and/or logged into the '$SearchDomain' domain within 30 days" -FontColor "Yellow" -Background "DarkGray"
                                            $Active=$true
                                        }
                                    }
                                    Break
                                }
                            }
                        }
                        If($Active-eq$false){$Message=DisplayMessage -Description "$HostName last logon: '$($Computer.LastLogonDate)' and password was set on: '$($Computer.PasswordLastSet)'" -Background "DarkRed"}
                    }
                }
                #Validate FOrward DSN Lookup
                $CheckForwardDNS=DNSLookup -ObjectValue $ForwardDNS -SearchValue ("Name*"+$ForwardDNS+"*")
                $ResolvedIP=$CheckForwardDNS[1]
                If($CheckForwardDNS[0]-eq$true){
                    $Message=DisplayMessage -Description "Forward Lookup was able to resolve $ForwardDNS to $($Computer.IPv4Address)" -FontColor "Yellow" -Background "DarkGreen"
                }Else{
                    $Message=DisplayMessage -Description "Forward Lookup does not resolve to $ForwardDNS" -FontColor "Yellow" -Background "DarkRed"
                }
                If(!$($Computer.IPv4Address)-eq""){
                    $IPv4AddressAD=$($Computer.IPv4Address)
                    $CheckReverseDNS=DNSLookup -ObjectValue $IPv4AddressAD -SearchValue ("Name*"+$ForwardDNS+"*")
                    $ResolvedIP=$CheckForwardDNS[1]
                    If($CheckReverseDNS[0]-eq$true){
                        $Message=DisplayMessage -Description "Reverse Lookup was able to resolve $IPv4AddressAD to $($Computer.DNSHostName)" -FontColor "Yellow" -Background "DarkGreen"
                    }Else{
                        $Message=DisplayMessage -Description "Reverse Lookup record does not exist for $($Computer.DNSHostName)" -FontColor "Yellow" -Background "DarkRed"
                    }
                }Else{
                    $Message=DisplayMessage -Description "$HostName does not have an IP Address listed in: '$SearchDomain'" -Background "DarkRed"
                }
                #Validate server is in the correct zone
                $PartIP=$($Computer.IPv4Address.Split(".")[2])
                If($(ZoneName -Octate3 $PartIP)-eq$($Computer.DNSHostName).Split(".")[1]){$CorrectZone=$true}
                If($CorrectZone-eq$false){
                    If($($Computer.DNSHostName).Split(".")[1]-eq$AuthUser.ToLower()){$RootDomain=$false}
                }
                If($Active-eq$true){
                    If(@($($Computer.IPv4Address).Split("."))[1]-like"118"){
                        $Message=DisplayMessage -Description "$ForwardDNS is located at ARDC" -FontColor "Cyan" -Background "DarkBlue"
                        $IPv4AddressAD=$($Computer.IPv4Address).ToString()
                        $Message=DisplayMessage -Description "Beginning process to ping $IPv4AddressAD" -FontColor "Cyan" -Background "DarkBlue"
                        $AbleToPing=ProcessPing -ObjectValue "-a $IPv4AddressAD" -SearchValue "Reply from*bytes=*"
                        $ResolvedIP=$AbleToPing[1]
                        If($AbleToPing[0]-eq$true){
                            $Message=DisplayMessage -Description "Was able to successfully ping $ForwardDNS using the IP Address: $ResolvedIP" -FontColor "Cyan" -Background "DarkBlue"
                        }Else{
                            $Message=DisplayMessage -Description "Failed to ping '$HostName' using the IP Address: $IPv4AddressAD" -FontColor "Red"
                        }
                    }ElseIf(@($($Computer.IPv4Address).Split("."))[1]-like"126"){
                        $Message=DisplayMessage -Description "$ForwardDNS is located at UDCC" -FontColor "Green" -Background "DarkBlue"
                        $IPv4AddressAD=$($Computer.IPv4Address).ToString()
                        $Message=DisplayMessage -Description "Beginning process to ping $IPv4AddressAD" -FontColor "Green" -Background "DarkBlue"
                        $AbleToPing=ProcessPing -ObjectValue "-a $IPv4AddressAD" -SearchValue "Reply from*bytes=*"
                        $ResolvedIP=$AbleToPing[1]
                        If($AbleToPing[0]-eq$true){
                            $Message=DisplayMessage -Description "Was able to successfully ping $ForwardDNS using the IP Address: $ResolvedIP" -FontColor "Green" -Background "DarkBlue"
                        }Else{
                            $Message=DisplayMessage -Description "Failed to ping '$HostName' using the IP Address: $IPv4AddressAD" -FontColor "Red"
                        }
                    }
                }Else{
                    If($CheckForwardDNS-eq$true){
                        $AbleToPing=ProcessPing -ObjectValue "-a $IPv4AddressAD" -SearchValue "Reply from*bytes=*"
                        $ResolvedIP=$AbleToPing[1]
                        If($AbleToPing[0]-eq$true){
                            $Message=DisplayMessage -Description "Was able to successfully ping $ForwardDNS using the IP Address: $ResolvedIP" -FontColor "Cyan" -Background "DarkBlue"
                        }Else{
                            $Message=DisplayMessage -Description "Failed to ping '$HostName' using the IP Address: $IPv4AddressAD" -FontColor "Red"
                        }
                    }ElseIf($CheckReverseDNS-eq$true){
                        $AbleToPing=ProcessPing -ObjectValue "$ForwardDNS" -SearchValue "Reply from*bytes=*"
                        $ResolvedIP=$AbleToPing[1]
                        If($AbleToPing[0]-eq$true){
                            $Message=DisplayMessage -Description "Was able to successfully ping $ForwardDNS using the IP Address: $ResolvedIP" -FontColor "Cyan" -Background "DarkBlue"
                        }Else{
                            $Message=DisplayMessage -Description "Failed to ping '$HostName' using the IP Address: $IPv4AddressAD" -FontColor "Red"
                        }
                    }
                }
                For($Loop=0;$Loop-le2;$Loop++){
                    $Message=DisplayMessage -Description "" -Background "Black"
                }
            }
            If($AbleToPing-eq$true){$GoodIPAddress++}
            If($AbleToPing-eq$false){$BadIPAddress++}
            If($Active-eq$false){$BadComputer++}
            $LastLogon=$null
            $DaysLogon=$null
            $LastPass=$null
            $DaysPast=$null
        }
    }Else{$Message=DisplayMessage -Description "$DomainController IS NOT a valid domain controller for the $SearchDomain domain." -Background "DarkRed"}
}
$BGC=(Get-Host).UI.RawUI.BackgroundColor=$BGC
$FGC=(Get-Host).UI.RawUI.ForegroundColor=$FGC
If(Test-Path $NSLookupData){Remove-Item -Path $NSLookupData -Force}
$EndTime=TimeDiff -StartDate $StartTime -EndDate (Get-Date).toString('H:mm:ss-M/d/yyyy')
Write-Host "'$EndTime minutes have past, Good computers: $GoodIPAddress, Failed to ping: $BadIPAddress, Not in DNS: $BadComputer'"
Set-Location -Path "C:\Windows\System32"
$DomainController=$null;$GoodIPAddress=$null;$BadIPAddress=$null;$BadComputer=$null;$WorkingPath=$null;$ValidDCName=$null;$ResolvedIP=$null
$UserDomain=$null;$UserName=$null;$AuthUser=$null;$Counter=$null;$Message=$null;$FocusDC=$null;$DCCount=$null;$Active=$null;
$DCList=$null;$LastPass=$null;$DaysPast=$null;$LastLogon=$null;$DaysLogon=$null;$SystemList=$null;$SearchDomain=$null