Clear-Host;Clear-History
<# 
#Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#Install once and then disable these packages.
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module Posh-SSH
Install-Module PSWriteColor
#>
Function Add-StartupVariables{[CmdletBinding(SupportsShouldProcess)]param([Parameter(Mandatory)][ValidateSet('AllUsersAllHosts','AllUsersCurrentHost','CurrentUserAllHosts','CurrentUserCurrentHost')]$Location)
    $Content=@'
$StartupVariables=@()
$StartupVariables=Get-Variable|Select-Object -ExpandProperty Name
'@
    If(-not(Test-Path -Path $Profile.$Location)){
        New-Item -Path $Profile.$Location -ItemType File|Set-Content -Value $Content
    }ElseIf(-not(Get-Content -Path $Profile.$Location|Select-String -SimpleMatch '$StartupVariables=Get-Variable|Select-Object -ExpandProperty Name')) {
        Add-Content -Path $Profile.$Location -Value "`r`n$Content"
    }Else{
        Write-Verbose -Message "`$StartupVariables already exists in '$($Profile.$Location)'"
    }
}
<#
Function ClearVariables{[CmdletBinding(SupportsShouldProcess)]param()
    If($StartupVariables){
        $UserVariables=Get-Variable -Exclude $StartupVariables -Scope Global
        ForEach($UserItem In $UserVariables){
            Try{
                Clear-Variable -Name "UserItem" -Force -Scope Global -ErrorAction SilentlyContinue
            }Catch [Exception]{
                If($($_.Exception.Message)-eq"Cannot find a variable with the name '$($UserItem.Name)'."){
                }Else{
                    $Message="Error: [ClearVariables]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Yellow -BackgroundColor DarkRed
                }
            }
        }
    }
}
#>
Function ClearVariables{[CmdletBinding()]param([Parameter(Mandatory=$true)]$VariableList=@())
    Try{
        ForEach($Item In $VariableList){
            If($Item.length-lt1){
            }Else{
                Set-Variable -Name $Item -Value $null
                Clear-Variable -Name $Item -Scope Global -Force -ErrorAction SilentlyContinue
            }
        }
    }Catch [Exception]{
        If($_.Exception.Message-eq"Cannot find a variable with the name '$Item'."){
        }Else{
            $Message=$_.Exception.Message
            Write-Host $Message -ForegroundColor Yellow -BackgroundColor DarkRed
        }
    }
}
Function Get-DateDiff{param([DateTime]$StartDate,[DateTime]$EndDate)
    $Days=(New-TimeSpan –Start $StartDate.AddDays(-30) –End $EndDate).Days
    Return $($Days)
}
Function Get-ForwardDnsData{param([Parameter(Position=0,Mandatory=$true)][String]$WorkLocation,[Parameter(Position=1,Mandatory=$true)][String]$DNSServer,[String]$SystemName="",[IPAddress]$IPAddress=$null)
    NullVariables -ItemList 'Data','FileName','ForwardZoneInfo','Found','Record','RecordType','RRType','SubDomain','Zone','ZoneName','ZoneRecord','ZoneRecords','Zones'
    Try{
        $Found=$false
        If(($SystemName-like"*.*")){
            $SystemName=$SystemName.Split(".")[0]
        }
        If($SystemName.Substring(0,2)-eq"fs"){
            $SubDomain="inf",$SystemName
        }Else{
            If($IPAddress.IPAddressToString.Length-gt1){
                $Results=Get-SubDomain -NetBIOS $SystemName -IPAddress $IPAddress.IPAddressToString
            }Else{
                $Results=Get-SubDomain -NetBIOS $SystemName
            }
            NullVariables -ItemList 'Campus','Left','Right','SubDomain'
            $SubDomain=$Results.SubDomain
        }
        $ZoneName="$($SubDomain).$SearchDomain"
        $FileName="$WorkLocation\$ZoneName.csv"
        If(Test-Path -Path "$FileName"){
            $ForwardZoneInfo=Import-Csv $FileName|Sort -Property HostName
            ForEach($Record In $ForwardZoneInfo){
                If($Record.HostName-eq$SystemName){
                    $SystemName=$Record.HostName
                    $RecordType=$Record.RecordType
                    $Zones=@(Get-DnsServerZone -ComputerName $DNSServer)|Where-Object{$_.ZoneName-eq$ZoneName}|Sort -Property ZoneName
                    ForEach($Zone In $Zones){
                        If($Zone.ZoneName-eq$ZoneName){
                            $ZoneRecords=$Zone|Get-DnsServerResourceRecord -ComputerName $DNSServer|Where-Object{$_.RecordType-eq"$RecordType"}
                            ForEach($ZoneRecord In $ZoneRecords){
                                If($ZoneRecord.HostName-eq$SystemName){
                                    Switch($RecordType){
                                        "A"{$Data="IPv4Address";Break}
                                        Default{$Data="";Break}
                                    }
                                    $RecordData=$ZoneRecord.RecordData.$Data
                                    $Found=$true
                                    Break
                                }
                            }
                            Break
                        }
                    }
                    Break
                }
            }
        }
        $ParseArray=New-Object PSObject
        $ParseArray|Add-Member -MemberType NoteProperty -Name "Found" -Value $Found
        $ParseArray|Add-Member -MemberType NoteProperty -Name "HostName" -Value $SystemName
        [IPAddress]$AddressList=$($RecordData.AddressList)
        $SubArray=New-Object PSObject
        ForEach($AddressList In $RecordData){
            $SubArray|Add-Member -MemberType NoteProperty -Name "Address" -Value $AddressList.Address
            $SubArray|Add-Member -MemberType NoteProperty -Name "AddressFamily" -Value $AddressList.AddressFamily
            $SubArray|Add-Member -MemberType NoteProperty -Name "ScopeId" -Value $AddressList.ScopeId
            $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6Multicast" -Value $AddressList.IsIPv6Multicast
            $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6LinkLocal" -Value $AddressList.IsIPv6LinkLocal
            $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6SiteLocal" -Value $AddressList.IsIPv6SiteLocal
            $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6Teredo" -Value $AddressList.IsIPv6Teredo
            $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv4MappedToIPv6" -Value $AddressList.IsIPv4MappedToIPv6
            $SubArray|Add-Member -MemberType NoteProperty -Name "IPAddressToString" -Value $AddressList.IPAddressToString
        }
        $ParseArray|Add-Member -MemberType NoteProperty -Name "AddressList" -Value $SubArray
        $ParseArray|Add-Member -MemberType NoteProperty -Name "ZoneName" -Value $ZoneName
        $ParseArray|Add-Member -MemberType NoteProperty -Name "RRType" -Value $RecordType
        Return $ParseArray
    }Catch [Exception]{
        $Message="Error: [Get-ForwardDnsData]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Yellow -BackgroundColor DarkRed
        Return $Found
    }
}
Function Protect-String{[CmdletBinding()]param([String][Parameter(Mandatory=$true)]$String,[String][Parameter(Mandatory=$true)]$Key)
    Begin{}
    Process{      
        If(([System.Text.Encoding]::Unicode).GetByteCount($Key)*8-notin128,192,256){
            Throw "Given encryption key has an invalid length.  The specified key must have a length of 128, 192, or 256 bits."
        }
        $SecureKey=ConvertTo-SecureString -String $Key -AsPlainText -Force
        Return ConvertTo-SecureString $String -AsPlainText -Force|ConvertFrom-SecureString -SecureKey $SecureKey
    }
    End{}
}
Function Unprotect-String{[CmdletBinding()]param([String][Parameter(Mandatory=$true)]$String,[String][Parameter(Mandatory=$true)]$Key)
    Begin{}
    Process{
        If(([System.Text.Encoding]::Unicode).GetByteCount($Key)*8-notin128,192,256){
            Throw "Given encryption key has an invalid length.  The specified key must have a length of 128, 192, or 256 bits."
            Return $false
        }
        $SecureKey=ConvertTo-SecureString -String $Key -AsPlainText -Force
        $PrivateKey=Get-Content -Path $EncryptionKeyFile|ConvertTo-SecureString -SecureKey $SecureKey
        $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PrivateKey)
        Return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    End{}
}
Function Get-ReverseDnsData{param([Parameter(Position=0,Mandatory=$true)][String]$WorkLocation,[Parameter(Position=1,Mandatory=$true)][String]$DNSServer,[String]$SystemName="",[IPAddress]$IPAddress=$null)
    NullVariables -ItemList 'Data','FileName','ReverseZoneInfo','Found','Record','RecordData','RecordType','RRType','Zone','ZoneName','ZoneRecord','ZoneRecords','Zones'
    Try{
        $Found=$false
        [Int]$Octate1=0
        [Int]$Octate2=0
        [Int]$Octate3=0
        [Int]$Octate4=0
        For($o=0;$o-le3;$o++){
            Switch($o){
                "0"{[Int]$Octate1=$IPAddress.IPAddressToString.Split(".")[$o];Break}
                "1"{[Int]$Octate2=$IPAddress.IPAddressToString.Split(".")[$o];Break}
                "2"{[Int]$Octate3=$IPAddress.IPAddressToString.Split(".")[$o];Break}
                "3"{[Int]$Octate4=$IPAddress.IPAddressToString.Split(".")[$o];Break}
            }
        }
        $ZoneName="$Octate3.$Octate2.$Octate1.in-addr.arpa"
        $FileName="$WorkLocation\$ZoneName.csv"
        If(Test-Path -Path "$FileName"){
            $ReverseZoneInfo=Import-Csv $FileName|Sort -Property HostName
            ForEach($Record In $ReverseZoneInfo){
                If($Record.HostName-eq$Octate4){
                    $Octate4=$Record.HostName
                    $RecordType=$Record.RecordType
                    $Zones=@(Get-DnsServerZone -ComputerName $DNSServer)|Where-Object{$_.ZoneName-eq$ZoneName}|Sort -Property ZoneName
                    ForEach($Zone In $Zones){
                        If($Zone.ZoneName-eq$ZoneName){
                            $ZoneRecords=$Zone|Get-DnsServerResourceRecord -ComputerName $DNSServer|Where-Object{$_.RecordType-eq"$RecordType"}
                            ForEach($ZoneRecord In $ZoneRecords){
                                If($ZoneRecord.HostName-eq$Octate4){
                                    Switch($RecordType){
                                        "PTR"{$Data="PtrDomainName";Break}
                                        Default{$Data="";Break}
                                    }
                                    $RecordData=$ZoneRecord.RecordData.$Data
                                    $Found=$true
                                    Break
                                }
                            }
                            Break
                        }
                    }
                    Break
                }
            }
        }
        $ParseArray=New-Object PSObject
        $ParseArray|Add-Member -MemberType NoteProperty -Name "Found" -Value $Found
        $ParseArray|Add-Member -MemberType NoteProperty -Name "HostName" -Value $Octate4
        $ParseArray|Add-Member -MemberType NoteProperty -Name "PtrDomainName" -Value $RecordData
        $ParseArray|Add-Member -MemberType NoteProperty -Name "ZoneName" -Value $ZoneName
        $ParseArray|Add-Member -MemberType NoteProperty -Name "RRType" -Value $RecordType
        Return $ParseArray
    }Catch [Exception]{
        $Message="Error: [Get-ReverseDnsData]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Yellow -BackgroundColor DarkRed
        Return $Found
    }
}
Function Get-SubDomain{param([Parameter(Position=0,Mandatory=$true)][String]$NetBIOS,[Parameter(Position=1,Mandatory=$false)][IPAddress]$IPAddress=$null)
    NullVariables -ItemList 'Campus','Left','Right','SubDomain'
    [IPAddress]$IPv4=$null
    [String]$SubDomain=""
    If($IPAddress.IpAddressToString.Length-gt1){$IPv4=$IPAddress}
    $NetBIOS=$NetBIOS.Split(".")[0]
    If($NetBIOS.Substring(0,2)-eq"fs"){
    }Else{
        $Campus=@($NetBIOS.Remove(2)).ToLower()
        If($Campus-eq"ar"-or$Campus-eq"da"-or$Campus-eq"pb"-or$Campus-eq"rg"-or$Campus-eq"ty"-or$Campus-eq"za"){
            $Campus=$true
            Switch($NetBIOS){
                {($_-like"*prd*"-or$_-like"*rpt*")}{$SubDomain="prd";Break}
                {($_-like"*uat*")}{$SubDomain="uat";Break}
                {($_-like"*fly*"-or$_-like"*cfg*"-or$_-like"*cnv*")}{$SubDomain="fly";Break}
                {($_-like"*trn*")}{$SubDomain="trn";Break}
                {($_-like"*sbx*")}{$SubDomain="sbx";Break}
                {($_-like"*tst*")}{$SubDomain="tst";Break}
                {($_-like"*dev*")}{$SubDomain="dev";Break}
                {($_-like"*dmo*")}{$SubDomain="dmo";Break}
                {($_-like"*pum*")}{$SubDomain="inf";Break}
                Default{$SubDomain="";Break}
            }
        }
    }
    If($IPv4.IpAddressToString.Length-lt1){
    }ElseIf($SubDomain.Length-lt1){
        $SubDomain=Get-ZoneName -Octate3 $($IPv4.IpAddressToString.Split(".")[2])
        If(($Campus-eq$true)-and(($NetBIOS.Length-lt12)-or($NetBIOS.Length-gt12))){
            $NetBIOS="$($Left=$NetBIOS.Substring(0,4))$SubDomain$($Right=$NetBIOS.Substring(4,5))"
        }
    }
    If(($RootSystems-notcontains$NetBIOS)-and($IPv4.IpAddressToString.Length-lt1)-and($SubDomain.Length-lt1)-and($Campus-ne$true)){
        $SubDomain="inf"
    }
    $ParseArray=New-Object PSObject
    $ParseArray|Add-Member -MemberType NoteProperty -Name "SubDomain" -Value $SubDomain
    $ParseArray|Add-Member -MemberType NoteProperty -Name "HostName" -Value $NetBIOS
    Return $ParseArray
}
Function Get-SystemNetDNS{param([IPAddress]$IPAddress=$null,[String]$ComputerName=$null)
    NullVariables -ItemList 'AddressList','LineItem','RecordData','Results','SearchType','SearchValue','SubArray','ValueCheck'
    Try{
        $Results=$null
        $ValueCheck=""
        $SearchType="IPAddress"
        If(!$($ComputerName).Length-lt1){
            $ValueCheck=$($ComputerName.Split(" "))
            Switch($ValueCheck[1].Length-gt1){
                {($_-eq$true)}{$ComputerName=$ValueCheck[1];Break}
                Default{Break}
            }
            $SearchValue=$ComputerName;$SearchType="HostName"
        }
        If($($IPAddress.AddressFamily)-eq"InterNetwork"){$SearchValue=$IPAddress.IPAddressToString}
        Switch($SearchType){
            Default{$Results=[System.Net.Dns]::GetHostEntry($SearchValue);Break}
        }
        If($ComputerName-eq$env:COMPUTERNAME){
            $ParseArray=New-Object PSObject
            $ParseArray|Add-Member -MemberType NoteProperty -Name "Found" -Value $true
            $ParseArray|Add-Member -MemberType NoteProperty -Name "HostName" -Value $($Results.HostName)
            $ParseArray|Add-Member -MemberType NoteProperty -Name "Aliases" -Value $($Results.Aliases)
            For($i=0;$($Results.AddressList[$i])-ne$null;$i++){
                If($($Results.AddressList[$i].IPAddressToString)-ne"::1"){
                    [IPAddress]$AddressList=$($Results.AddressList[$i])
                    $SubArray=New-Object PSObject
                    $SubArray|Add-Member -MemberType NoteProperty -Name "Address" -Value $AddressList.Address
                    $SubArray|Add-Member -MemberType NoteProperty -Name "AddressFamily" -Value $AddressList.AddressFamily
                    $SubArray|Add-Member -MemberType NoteProperty -Name "ScopeId" -Value $AddressList.ScopeId
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6Multicast" -Value $AddressList.IsIPv6Multicast
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6LinkLocal" -Value $AddressList.IsIPv6LinkLocal
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6SiteLocal" -Value $AddressList.IsIPv6SiteLocal
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6Teredo" -Value $AddressList.IsIPv6Teredo
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv4MappedToIPv6" -Value $AddressList.IsIPv4MappedToIPv6
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IPAddressToString" -Value $AddressList.IPAddressToString
                }
            }
            $ParseArray|Add-Member -MemberType NoteProperty -Name "AddressList" -Value $SubArray
        }Else{
            $ParseArray=New-Object PSObject
            $ParseArray|Add-Member -MemberType NoteProperty -Name "Found" -Value $true
            ForEach($RecordData In $Results){
                $ParseArray|Add-Member -MemberType NoteProperty -Name "HostName" -Value $RecordData.HostName
                $ParseArray|Add-Member -MemberType NoteProperty -Name "Aliases" -Value $RecordData.Aliases
                [IPAddress]$AddressList=$($RecordData.AddressList.IPAddressToString)
                $SubArray=New-Object PSObject
                ForEach($LineItem In $AddressList){
                    $SubArray|Add-Member -MemberType NoteProperty -Name "Address" -Value $LineItem.Address
                    $SubArray|Add-Member -MemberType NoteProperty -Name "AddressFamily" -Value $LineItem.AddressFamily
                    $SubArray|Add-Member -MemberType NoteProperty -Name "ScopeId" -Value $LineItem.ScopeId
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6Multicast" -Value $LineItem.IsIPv6Multicast
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6LinkLocal" -Value $LineItem.IsIPv6LinkLocal
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6SiteLocal" -Value $LineItem.IsIPv6SiteLocal
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6Teredo" -Value $LineItem.IsIPv6Teredo
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv4MappedToIPv6" -Value $LineItem.IsIPv4MappedToIPv6
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IPAddressToString" -Value $LineItem.IPAddressToString
                }
                $ParseArray|Add-Member -MemberType NoteProperty -Name "AddressList" -Value $SubArray
            }
        }
        Return $ParseArray
    }Catch [Exception]{
        If($($_.Exception.Message)-eq"No such host is known"){
        }Else{
            $Message="Error: [Get-SystemNetDNS]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Yellow -BackgroundColor DarkRed
        }
        Return $false
    }
}
Function Get-TimeDiff{param([DateTime]$StartDate,[DateTime]$EndDate)
    $ElapsedTime=(New-TimeSpan –Start $StartDate –End $EndDate)
    Return $($ElapsedTime)
}
Function Get-VMComputerData{param([IPAddress]$VCMManagerIP,[String]$VMServer,[PSCredential]$AdminAccount,[String]$FileName)
    NullVariables -ItemList 'Connected','Error','Message','NetworkCards','NtwkCard','ReportedVM','ReportedVMs','VM','VMs'
    Try{
        $VCMManagerIP=$VCMManagerIP.IPAddressToString
        Write-debug "Connecting to vCenter using '$VCMManagerIP', please wait..."
        $Connected=Connect-VIServer -Server $VCMManagerIP -Protocol https -Credential $AdminAccount -ErrorAction SilentlyContinue
        Trap{
            If($Error[0].exception-like"*incorrect user name or password*"){
                $Message="Error: [Get-VMComputerData]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Magenta -BackgroundColor Black
                Return $null
            }
        }
        If($Connected){
            $ReportedVMs=New-Object System.Collections.ArrayList
            $VMs=Get-View -ViewType VirtualMachine|Sort-Object -Property{$_.Config.Hardware.Device|Where{$_-is[VMware.Vim.VirtualEthernetCard]}|Measure-Object|select -ExpandProperty Count} -Descending
            ForEach($VM in $VMs){
                $ReportedVM=New-Object PSObject
                Add-Member -Inputobject $ReportedVM -MemberType noteProperty -name Guest -value $VM.Name
                Add-Member -InputObject $ReportedVM -MemberType noteProperty -name UUID -value $($VM.Config.Uuid)
                $NetworkCards=$VM.guest.net| ?{$_.DeviceConfigId-ne-1}
                $i=0
                ForEach($NtwkCard in $NetworkCards){
                    Add-Member -InputObject $ReportedVM -MemberType NoteProperty -Name "networkcard${i}.Network" -Value $NtwkCard.Network
                    Add-Member -InputObject $ReportedVM -MemberType NoteProperty -Name "networkcard${i}.MacAddress" -Value $NtwkCard.Macaddress  
                    Add-Member -InputObject $ReportedVM -MemberType NoteProperty -Name "networkcard${i}.IPAddress" -Value $($NtwkCard.IPAddress|?{$_-like"*.*"})
                    Add-Member -InputObject $ReportedVM -MemberType NoteProperty -Name "networkcard${i}.Device" -Value $(($VM.Config.Hardware.Device|?{$_.key-eq$($NtwkCard.DeviceConfigId)}).GetType().Name)
                    $i++
                }
                $ReportedVMs.add($ReportedVM)|Out-Null
            }
            $ReportedVMs|Export-CSV $FileName -NoTypeInformation -Encoding UTF8|Out-Null
            $Message=Set-DisplayMessage -Description "Export complete!  Safe to disconnect from '$($VMServer) [$($VCMManagerIP)]' server."
            Disconnect-VIServer -Server $Connected -Force -Confirm
            Return $true
        }Else{
            $Message=Set-DisplayMessage -Description "Error: [Get-VMComputerData]: Failed to connect to vCenter using '$VCMManagerIP'.";Write-Host $Message -ForegroundColor Magenta -BackgroundColor Black
            Return $false
        }
    }Catch [Exception]{
        $Message="Error: [Get-VMComputerData]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Magenta -BackgroundColor Black
        Return $false
    }
}
Function Get-VMExportedInfo{param([String]$MacAddress,[String]$GuestName,[Int]$Site)
    NullVariables -ItemList 'ExportVMData','Left','NetworkMAC','SiteLabel','VMAdapter','VMComputerList','VMComputerName','VMGuest','VMIPAddress','VMNetwork','VMPowerState'
    If($Site-eq0){
        $MacAddress=""
        $Left=$GuestName.Length-3
        $SiteLabel=$GuestName.Substring($Left,1)
        Switch($SiteLabel){
            {($_-eq"b")-or($_-eq"y")}{$Site=2;Break}
            Default{$Site=1;Break}
        }
    }Else{
        $GuestName=""
        Switch($Site){
            "126"{$Site=2;Break}
            Default{$Site=1;Break}
        }
    }
    $VMPowerState="Off"
    $VMComputerName=$null
    $ExportVMData="VMComputerData-Site$Site.csv"
    $VMComputerList=Import-Csv $ExportVMData|Sort -Property "Guest"
    ForEach($VMGuest In $VMComputerList){
        $VMComputerName=$VMGuest.Guest
        For($i=0;$i-lt1;$i++){
            $NetworkMAC=$VMGuest.$('networkcard'+$i+'.MacAddress')
            If(($MacAddress-eq$NetworkMAC-and$MacAddress.Length-lt1)-or($VMComputerName-like"*$GuestName*"-and$GuestName.Length-lt1)){
                $VMComputerName=$VMGuest.Guest
                $VMNetwork=$VMGuest.$('networkcard'+$i+'.Network').ToString()
                $VMIPAddress=$VMGuest.$('networkcard'+$i+'.IPAddress').ToString()
                $VMAdapter=$VMGuest.$('networkcard'+$i+'.Device').ToString()
                If($VMNetwork-ne$VMPoweredOffState){
                    $VMPowerState="On"
                }
                $ParseArray=New-Object PSObject
                $ParseArray|Add-Member -MemberType NoteProperty -Name "Found" -Value $true
                $ParseArray|Add-Member -MemberType NoteProperty -Name "HostName" -Value $VMComputerName
                $ParseArray|Add-Member -MemberType NoteProperty -Name "Network" -Value $VMNetwork
                $ParseArray|Add-Member -MemberType NoteProperty -Name "IPAddress" -Value $VMIPAddress
                $ParseArray|Add-Member -MemberType NoteProperty -Name "Device" -Value $VMAdapter
                $ParseArray|Add-Member -MemberType NoteProperty -Name "State" -Value $VMPowerState
                Return $ParseArray
                Break
            }
        }
    }
    Return $false
}
Function Get-ZoneName{param([Int]$Octate3)
    Switch($Octate3){
        {($_-eq0)-or($_-eq1)}{$SubDomain="inf";Break}
        {($_-eq2)}{$SubDomain="mgt";Break}
        {($_-ge4-and$_-le7)-or($_-ge20-and$_-le23)-or($_-ge36-and$_-le39)-or($_-ge52-and$_-le55)-or($_-ge68-and$_-le712)-or($_-ge84-and$_-le87)}{$SubDomain="prd";Break}
        {($_-eq8)-or($_-eq24)-or($_-eq40)-or($_-eq56)-or($_-eq72)-or($_-eq88)}{$SubDomain="uat";Break}
        {($_-eq9)-or($_-eq25)-or($_-eq41)-or($_-eq57)-or($_-eq73)-or($_-eq89)}{$SubDomain="fly";Break}
        {($_-eq10)-or($_-eq26)-or($_-eq42)-or($_-eq58)-or($_-eq74)-or($_-eq90)}{$SubDomain="trn";Break}
        {($_-eq11)-or($_-eq27)-or($_-eq43)-or($_-eq59)-or($_-eq75)-or($_-eq91)}{$SubDomain="sbx";Break}
        {($_-eq12)-or($_-eq28)-or($_-eq44)-or($_-eq60)-or($_-eq76)-or($_-eq92)}{$SubDomain="tst";Break}
        {($_-eq13)-or($_-eq29)-or($_-eq45)-or($_-eq61)-or($_-eq77)-or($_-eq93)}{$SubDomain="dev";Break}
        {($_-eq14)-or($_-eq30)-or($_-eq46)-or($_-eq62)-or($_-eq78)-or($_-eq94)}{$SubDomain="dmo";Break}
        {($_-eq18)-or($_-eq19)}{$SubDomain="vdi";Break}
        {($_-eq64)-or($_-eq65)}{$SubDomain="bkp";Break}
        Default{$SubDomain="all";Break}
    }
    Return $SubDomain
}
Function NullVariables{param([Parameter(Position=0,Mandatory=$true)]$ItemList=@())
    Try{
        ForEach($Item In $ItemList){
            If($Item.Length-lt1){
            }Else{
                Clear-Variable -Name "$Item" -Scope Global -Force -ErrorAction SilentlyContinue
            }
        }
    }Catch [Exception]{
        If($_.Exception.Message-eq"Cannot find a variable with the name '$Item'."){
        }Else{
            $Message="Error: [NullVariables]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Magenta -BackgroundColor Black
        }
    }
}
Function Set-DisplayMessage{param([String]$Description,[String]$StatusMessage,$FontColor="Yellow",$Background="Black",$RightJustified=$true)
    NullVariables -ItemList 'Height','Left','Message','Right','RightAlign','Width','WindowSize'
    [Int]$RightAlign=$Buffer.Width
    [Int]$WindowSize=$($RightAlign-$($Description.Length+1+$StatusMessage.Length+1))
    If($Buffer.Width-le$WindowSize){
        $Width=$WindowSize
        For($Height=0;$Buffer.Width-le$Width;$Height++){
            $Width=$Width-$Buffer.Width
        }
        $Buffer.Height=$Height
        $WindowSize=$Width
    }
    If($RightJustified-eq$true){
        For($Left=0;$Left-lt$WindowSize;$Left++){
            $Description=" "+$Description
        }
    }ElseIf($RightJustified-eq$false){
        For($Right=0;$Right-lt$WindowSize;$Right++){
            $Description=$Description+" "
        }
    }ElseIf($StatusMessage.Length-gt0-or($Description.Length-lt1-and$StatusMessage.Length-lt1)){
        For($Left=0;$Left-lt$WindowSize;$Left++){
            $StatusMessage=$StatusMessage+" "
        }
    }
    [String]$Message=$Description
    If($FontColor[1].Length-gt1){
        Write-Color "$Message"," $StatusMessage" -Color $FontColor[0],$FontColor[1]
    }Else{
        Write-Host $Message,$StatusMessage -ForegroundColor $FontColor -BackgroundColor $Background
    }
    If($Background-eq"DarkRed"){
        Add-Content -Path $ResultFile -Value $($Message.Trim()) -PassThru
    }
}
Function UnloadPowerCli{
    $VMLoadOrder=@('VMware.VimAutomation.Core','VMware.VimAutomation.Vds','VMware.VimAutomation.Cloud','VMware.VimAutomation.PCloud','VMware.VimAutomation.Cis.Core','VMware.VimAutomation.Storage','VMware.VimAutomation.HorizonView','VMware.VimAutomation.HA','VMware.VimAutomation.vROps','VMware.VumAutomation','VMware.DeployAutomation','VMware.ImageBuilder','VMware.VimAutomation.License')
    ForEach($ModuleName In $VMLoadOrder){
        Remove-Module -Name $ModuleName -Force
    }
    $ListModules=Get-Module|Where-Object{$_.Name-like"*VMware*"}
    ForEach($ModuleName In $ListModules){
        Remove-Module -Name $ModuleName
    }
}
Function Verify-IPAddress{[CmdletBinding()][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][ValidateScript({$_ -match [IPAddress]$_ })]
Param([String]$IPAddress)
    Begin{}
    Process{
        Try{
            [IPAddress]$IPAddress
        }Catch [Exception]{
            $Message="Error: [Set-DisplayMessage]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Magenta -BackgroundColor Black
            Return $false
        }
    }
    End{}
}
Add-StartupVariables -Location AllUsersAllHosts
$Buffer=(Get-Host).UI.RawUI.BufferSize
# Retrieving the Starting Date for calculating the computer password age from computer in the AD Export. #
$ResetDate=(Get-Date).toString('M/d/yyyy')
$ResetDate=[DateTime]::ParseExact($ResetDate,'M/d/yyyy',$null)
$StartTime=(Get-Date).toString('yyyy/M/d H:mm:ss')
$StartTime=[DateTime]::ParseExact($StartTime,'yyyy/M/d H:mm:ss',$null)
Set-Location -Path "$($env:USERProfile)\Documents"
Set-Variable -Name "AuthUser" -Value "bstobie@utsystem.edu"
Set-Variable -Name "WorkingPath" -Value "$env:USERProfile\Documents\Passwords"
Set-Variable -Name "SecureFile" -Value "$WorkingPath\Encrypted.pwd"
$SearchDomain=$env:USERDNSDOMAIN.ToLower()
$ResultFile="Results.log"
$RootSystems="w16arootca01"
$Encrypted=""
$Site=0
[Int]$i=0
[Int]$Sites=2
[Int]$Octate1=0
[Int]$Octate2=0
[Int]$Octate3=0
[Int]$Octate4=0
[Int]$NotLoggedOn=0
[Int]$BadComputer=0
[Int]$BadIPAddress=0
[Int]$StaleConnection=0
[Int]$ActiveConnection=0
NullVariables -ItemList 'Encrypted'
Do{
    $i++
    Switch($i){
        "1"{$Prompt="Enter your search domain: [$SearchDomain]";Break}
        Default{$Prompt="Enter the FQDN, please";Break}
    }
    $SearchDomain=Read-Host -Prompt $Prompt
    If($SearchDomain.Length-lt1){$SearchDomain=$env:USERDNSDOMAIN}
    $SearchDomain=$SearchDomain.ToLower()
}Until($SearchDomain-like'*.*')
NullVariables -ItemList 'i','Prompt'
$UserDomain=$SearchDomain.Split(".")[0].ToUpper()
$UserName=Read-Host -Prompt "Enter your credentials: [$env:USERNAME]"
If($UserName.Length-lt1){
    $UserName=$env:USERNAME
}Else{
    If($UserName-like"*\*"){
        $UserDomain=$($UserName.Split("\")[0]).ToLower()
        $UserName=$($UserName.Split("\")[1])
    }
}
$UserName=$UserName.ToLower()
$AuthUser=$UserDomain+"\"+$UserName
# Retrieve and encrypt the users password to use when credentials are required to access network resources. #
$SecureString=Read-Host -Prompt "Enter your [$AuthUser] credentials" -AsSecureString
$BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
$Encrypted=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
If($Encrypted.Length-lt1){
    Set-Variable -Name "EncryptionKeyFile" -Value ""
    Set-Variable -Name "Characters" -Value ""
    Set-Variable -Name "PrivateKey" -Value ""
    Set-Variable -Name "SecureKey" -Value ""
    [String]$Key=0
    [Int]$Min=8
    [Int]$Max=1024
    $Prompt="Enter the length you want to use for the security key: [up to 16 bytes]"
    If($Prompt.Length-eq0){$Prompt=8}
    [Int]$RandomKey=Read-Host -Prompt $Prompt
    If(Test-Path $WorkingPath){
        $Results=Get-ChildItem -Path $WorkingPath -File
        ForEach($File In $Results){
            $FileName=$($File.Name).Split(".")[0]
            If($FileName.length-eq$RandomKey){
                $KeyFile="$($File.Name)"
                $Key=$($KeyFile).Split(".")[0]
                If(([System.Text.Encoding]::Unicode).GetByteCount($Key)*8-notin"128,192,256"){
                    $EncryptionKeyFile="$WorkingPath\$KeyFile"
                    $SecureKey=ConvertTo-SecureString -String $Key -AsPlainText -Force
                    $PrivateKey=Get-Content -Path $EncryptionKeyFile|ConvertTo-SecureString -SecureKey $SecureKey
                    $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PrivateKey)
                    $UnEncrypted=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                    Break
                }
            }
        }
    }Else{
        $Dir=MkDir $WorkingPath
    }
    If($PrivateKey.length-lt1){
        Do{
            Switch($RandomKey){
                {($_-eq8)}{
                    $Key=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    $Key+=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    Break
                }
                {($_-eq12)}{
                    $Key=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    $Key+=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    $Key+=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    Break
                }
                {($_-eq16)}{
                    $Key=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    $Key+=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    $Key+=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    $Key+=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    Break
                }
                {($Key.length-lt$RandomKey)}{
                    $RandomKey+=1
                    Break
                }
                {($Key.length-gt$RandomKey)}{
                    $RandomKey-=1
                    Break
                }
                Default{
                    $RandomKey=16
                    Break
                }
            }
        }Until(($Key.length-eq8)-or($Key.length-eq12)-or($Key.length-eq16))
        $i=0
        Do{
            $i++
            If(Test-Path -Path $SecureFile){
                $SecureFile="$WorkingPath\Encrypted$i.pwd"
            }
        }While((Test-Path -Path $SecureFile)-eq$true)
        $Prompt="Enter the amount of characters you want to use for the encryption key: [min $Min, max $Max]"
        Do{
            [Int]$Characters=Read-Host -Prompt $Prompt
            If(($Characters-ge$Min)-and($Characters-le$Max)){
            }Else{
                $Prompt="Please enter a value between the minimum '$Min' and maximum '$Max' range"
            }
        }Until(($Characters-ge$Min)-and($Characters-le$Max))
        For($i=0;$i-le$Characters;$i++){
            Switch($i){
                {($_-gt0)-and($_-le$Characters)}{$Set=-join((65..90)+(97..122)|Get-Random -Count 1|%{[Char]$_});Break}
                Default{$PrivateKey="";$Set="";Break}
            }
            $PrivateKey+=$Set
        }
        Set-Variable -Name "EncryptionKeyFile" -Value "$WorkingPath\$Key.key"
        Protect-String $PrivateKey $Key|Out-File -Filepath $EncryptionKeyFile
        $Validate=Unprotect-String $PrivateKey $Key
        If($Validate-ne$false){
            $SecureKey=ConvertTo-SecureString -String $Key -AsPlainText -Force
        }
        $SecureString=Read-Host -Prompt "Enter your [$AuthUser] credentials" -AsSecureString
        $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        $EncryptedString=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $EncryptedString|ConvertTo-SecureString -AsPlainText -Force|ConvertFrom-SecureString -SecureKey $SecureKey|Out-File -FilePath $SecureFile
    }
    Try{
        $SecureString=Get-Content -Path $SecureFile|ConvertTo-SecureString -SecureKey $SecureKey -ErrorAction Stop
        $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        $Validate=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }Catch [Exception]{
        $Message="Error: [Validation]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Yellow -BackgroundColor DarkRed
    }
}
$PassCredentials=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AuthUser,$SecureString
ClearVariables -VariableList 'AuthUser','BSTR','Characters','Encrypted','EncryptedString','EncryptionKeyFile','File','FileName','i','Key','Max','Message','Min','PrivateKey','Prompt','RandomKey','Results','SecureFile','SecureKey','SecureString','Set','Validate','WorkingPath'
[Int]$i=0
Do{
    $i++
    Switch($i){
        "1"{$Prompt="Enter the name a domain controller for $($SearchDomain): [dca01]";Break}
        Default{$DCServerName="dca01";Break}
    }
    $DCServerName=Read-Host -Prompt $Prompt
    If($DCServerName.Length-lt1){$DCServerName="dca01."+$SearchDomain}
}Until($DCServerName-like'*.*')
NullVariables -ItemList 'i','Prompt'
[Int]$Counter=0
$VMServerIP=[System.Collections.ArrayList]@(0)
Do{
    $Counter++
    Switch($Counter){
        "1"{$Prompt="Enter the IP Address of the Virtual Platform management server: [10.118.0.4]";Break}
        Default{$Prompt="Please enter a valid IP Address: [10.118.0.4]";Break}
    }
    $VMServerIP[0]=Read-Host -Prompt $Prompt
    If($VMServerIP[0].Length-lt1){$VMServerIP[0]="10.118.0.4"}
    $Results=Verify-IPAddress $VMServerIP[0]
    If($Results-eq$false){$VMServerIP[0]=-1}
}Until($VMServerIP[0]-gt0)
NullVariables -ItemList 'Counter','i','Prompt','Results'
$ValidCredentials=$true
# Loading PowerCLI Modules for VMWare connection. #
# Loading PowerCLI Modules for VMWare connection. #
<#$ValidCredentials=$false
Do{
    [String]$CurrentIP=""
    If($VMServerIP-like"*,*"){
        $CurrentIP=$VMServerIP.ToString().Split(",")[$Site]
    }Else{
        $CurrentIP=$VMServerIP
    }
    For($o=0;$o-le3;$o++){
        Switch($o){
            "0"{[Int]$Octate1=$VMServerIP[$Site].ToString().Split(".")[$o];Break}
            "1"{[Int]$Octate2=$VMServerIP[$Site].ToString().Split(".")[$o];Break}
            "2"{[Int]$Octate3=$VMServerIP[$Site].ToString().Split(".")[$o];Break}
            "3"{[Int]$Octate4=$VMServerIP[$Site].ToString().Split(".")[$o];Break}
        }
    }
    If($Octate2-eq118){
        $Octate2=126
    }
    $Site++
    $ExportVMData="VMComputerData-Site$Site.csv"
    If(Test-Path -Path $ExportVMData){Remove-Item -Path $ExportVMData}
    $Results=Get-SystemNetDNS -IPAddress $CurrentIP
    NullVariables -ItemList 'AddressList','LineItem','RecordData','SearchType','SearchValue','SubArray','ValueCheck'
    If($Results.Found-eq$true){
        $VMServerDNS=$Results.HostName
    }
    For($l=0;$l-lt2;$l++){
        Switch($l){
            "1"{$Message="Beginning to export the current state of VMs to '$WorkingPath\$ExportVMData'.  Please wait, this export could take upto a few minutes to complete.";Break}
            Default{$Message="";Break}
        }
        $Message=Set-DisplayMessage -Description $Message -FontColor White -Background Black -RightJustified $false
    }
    $Results=Get-VMComputerData -VCMManagerIP $CurrentIP -VMServer $VMServerDNS -AdminAccount $PassCredentials -FileName $ExportVMData
    If($Results-eq$true){
        $Results="Successfully completed exporting the current state of Virtual Machine's from '$VMServerDNS'.",'White','Black'
        $ValidCredentials=$true
    }ElseIf($Results-eq$false){
        $Results="Wasn't able to retrieve the current state of Virtual Machine's from '$CurrentIP'.",'Yellow','DarkRed'
    }Else{
        Break
    }
    For($l=0;$l-le2;$l++){
        Switch($l){
            "1"{$Message=$Results[0],$Results[1],$Results[2];Break}
            Default{$Message="","Yellow","Black";Break}
        }
        $Message=Set-DisplayMessage -Description $Message[0] -FontColor $Message[1] -Background $Message[2] -RightJustified $false
    }
    $VMServerIP="$VMServerIP,$Octate1.$Octate2.$Octate3.$Octate4"
}While($Site-lt$Sites)#>
# Loading PowerCLI Modules for VMWare connection. #
# Loading PowerCLI Modules for VMWare connection. #
NullVariables -ItemList 'CurrentIP','ExportVMData','l','Message','o','Octate1','Octate2','Octate3','Octate4','Prompt','Results','Site','Sites','VMServerDNS','VMServerIP'
If($ValidCredentials-eq$true){
    [String]$VMPoweredOffState="4f f8 01 50 ed 0b 98 8c-7a 70 b6 ff 16 54 8e d1"
    $DCServerName=$DCServerName.Split(".")[0].ToLower()
    $ExportFile="ExportList-$DCServerName.csv"
    $DCServerName=$DCServerName+"."+$SearchDomain
    $FilterBy='ObjectClass -eq "Computer"'
    $StartVariables="StartVariablesList.csv"
    $FinishVariables="FinishVariablesList.csv"
    If(Test-Path -Path $ResultFile){Remove-Item -Path $ResultFile}
    $Message=Set-DisplayMessage -Description "" -RightJustified $false
    $Message=Set-DisplayMessage -Description "Retrieving list of domain computers for the '$SearchDomain' domain from $DCServerName, and exporting list of domain computers to '$WorkingPath\$ExportFile'." -FontColor White -RightJustified $false
    $AdHeader='Name','LastLogonDate','PasswordLastSet','PasswordExpired','OperatingSystem','IPv4Address','DNSHostName','DistinguishedName','CanonicalName','whenChanged','whenCreated','LockedOut'
    <# Beginning process of validating the computers from the AD Export against the Forward and Reverse Zones in DNS. #>
    If(Test-Path -Path $ExportFile){Remove-Item -Path $ExportFile}
    Get-ADComputer -Credential $PassCredentials -Server $DCServerName -Filter $FilterBy -Property $AdHeader|Select-Object $AdHeader|Sort-Object -Property Name|Export-CSV $ExportFile -NoTypeInformation -Encoding UTF8
    If(Test-Path -Path $ExportFile){
        $Message=Set-DisplayMessage -Description "Completed export of domain computers to '$ExportFile'." -FontColor Yellow -Background Black
        For($i=0;$i-lt2;$i++){
            $Message=Set-DisplayMessage -Description ""
        }
        $Message=Set-DisplayMessage -Description "Adding exported list of domain computers to memory.  Searching for other Domain Controllers..." -FontColor White -RightJustified $false
        NullVariables -ItemList 'FocusDC','i','Message'
        [Int]$Counter=0
        $ZoneCount=0
        $ComputerList=Import-Csv $ExportFile|Sort-Object Name
        ForEach($Computer In $ComputerList){
            If($Computer.CanonicalName-like"*Domain Controller*"){
                If(($Computer.DNSHostName).ToLower()-eq$DCServerName){
                    $RootSystems+=",$($Computer.Name.ToLower())"
                    [String]$FocusDC=$DCServerName
                    $ValidDCName=$true
                }Else{
                    $Counter++
                    $RootSystems+=",$($Computer.Name.ToLower())"
                    Switch($Counter){
                        "1"{$DCList=($Computer.DNSHostName).ToLower();Break}
                        Default{$DCList=$DCList+","+($Computer.DNSHostName).ToLower();Break}
                    }
                }
            }
        }
        NullVariables -ItemList 'Computer','ComputerList'
        If($ValidDCName-eq$true){
            $ADServerList=[System.Collections.ArrayList]@(0..$Counter)
            $Message=Set-DisplayMessage -Description ""
            NullVariables -ItemList 'DCArray'
            For($i=0;$i-lt$Counter;$i++){
                $DC=$DCList.Split(",")[$i]
                If($i-eq0){
                    $DCArray=[System.Collections.ArrayList]@($FocusDC,$DC)
                }Else{
                    $DCArray+=[System.Collections.ArrayList]@(,$DC)
                }
                $DC=$DC.Replace("'","")
                $NewDC=$DC.Split(".")[0]
                $FileName=$ExportFile.Replace($FocusDC.Split(".")[0],$NewDC)
                $Message=Set-DisplayMessage -Description "Retrieving list of domain computers from $NewDC.$SearchDomain and exporting list of domain computers to '$WorkingPath\$FileName'." -FontColor White -RightJustified $false
                If(Test-Path -Path $FileName){Remove-Item -Path $FileName}
                Get-ADComputer -Credential $PassCredentials -Server $DC -Filter $FilterBy -Property $AdHeader|Select-Object $AdHeader|Export-CSV $FileName -NoTypeInformation -Encoding UTF8
                $Message=Set-DisplayMessage -Description "Completed export of domain computers to '$FileName'." -FontColor Yellow -Background Black
                $ADServerList[$i]=Import-Csv $FileName
                $ADServerList[$i]=$FileName,$ADServerList[$i]
                For($j=0;$j-lt2;$j++){
                    $Message=Set-DisplayMessage -Description ""
                }
            }
            NullVariables -ItemList 'AdHeader','Counter','DC','DCList','DCServerName','FileName','i','j','Message','NewDC'
            $DnsHeader='HostName','RecordType','Type','TimeStamp','TimeToLive','RecordData'
            $Zones=@(Get-DnsServerZone -ComputerName $FocusDC)
            $Message=Set-DisplayMessage -Description "Retrieving list of Forward and Reserve Zones from $FocusDC and exporting list to '$WorkingPath'." -FontColor White -RightJustified $false
            ForEach($Zone In $Zones){
	            $ZoneExport="$($Zone.ZoneName)"
                If($ZoneExport.Substring(0,1)-eq"_"){
                }Else{
                    $ZoneExport="$WorkingPath\$($ZoneExport).csv"
                    If(Test-Path -Path $ZoneExport){Remove-Item -Path $ZoneExport}
                    If($ZoneExport-like"*$SearchDomain*"){
	                    $Results=$Zone|Get-DnsServerResourceRecord -ComputerName $FocusDC|Where-Object{$_.RecordType-eq"A"}
                        $Results|Select-Object $DnsHeader|Export-CSV $ZoneExport -NoTypeInformation -Encoding UTF8
                        $ZoneCount++
                    }ElseIf($ZoneExport-notlike"*$SearchDomain*"-and($ZoneExport-like"*11?.10*"-or$ZoneExport-like"*12?.10*")){
	                    $Results=$Zone|Get-DnsServerResourceRecord -ComputerName $FocusDC|Where-Object{$_.RecordType-eq"PTR"}
                        $Results|Select-Object $DnsHeader|Export-CSV $ZoneExport -NoTypeInformation -Encoding UTF8
                        $ZoneCount++
                    }
                }
            }
            NullVariables -ItemList 'Headers','Message','Results','Zone','ZoneExport','Zones'
            $Message=Set-DisplayMessage -Description "Completed exporting [$ZoneCount] lists of Forward and Reserve Zones for '$SearchDomain'." -FontColor Yellow -Background Black
            For($j=0;$j-lt2;$j++){
                $Message=Set-DisplayMessage -Description ""
            }
            NullVariables -ItemList 'j','Message','ZoneCount'
        }
        NullVariables -ItemList 'ValidDCName'
        Clear-Host
        $ComputerList=Import-Csv $ExportFile|Sort-Object Name
        ForEach($Computer In $ComputerList){
            NullVariables -ItemList 'Active','AddressList','ADHostName','Aliases','ForwardDNS','ResolvedIP','MatchIP','Message1','Message2','NetBIOS','OS','ResolvedDNS','Results','SubDomain'
            [Int]$DaysPast=0
            [Int]$DaysLogon=0
            [Boolean]$MissingDNS=$false
            [Boolean]$InvalidFQDN=$false
            [Boolean]$MissingDate=$false
            [Boolean]$InvalidIPAddress=$false
            [Boolean]$MissingIPAddress=$false
            $NetBIOS=$($Computer.Name).ToLower()
            $OS=$($Computer.OperatingSystem).ToLower()
            If(($OS-eq"Windows 8.1 Enterprise")-or($OS-eq"Windows 10 Enterprise")){
            }ElseIf($RootSystems-like"*$NetBIOS*"){
            }Else{
                <# Beginning to process the computers in the AD Export to see if they are active or stale. #>
                $ADHostName=$($Computer.Name).ToUpper()
                For($l=0;$l-lt2;$l++){
                    Switch($l){
                        "1"{$Message1="Beginning to process information for";$Message2="'$ADHostName'";Break}
                        Default{$Message1="";$Message2="";Break}
                    }
                    $Message=Set-DisplayMessage -Description $Message1 -StatusMessage $Message2 -FontColor White,Yellow -Background Black -RightJustified $null
                }
                NullVariables -ItemList 'l','Message','Message1','Message2'
                $DateChanged=(@($($Computer.whenChanged).Split(" "))[0])
                $DateCreated=(@($($Computer.whenCreated).Split(" "))[0])
                $DateLastSet=(@($($Computer.PasswordLastSet).Split(" "))[0])
                $DateLogonDate=(@($($Computer.LastLogonDate).Split(" "))[0])
                If($($DateLogonDate).Length-lt1){
                    $DateLogonDate=$DateCreated
                    $MissingDate=$true
                }
                <# Checking the computer password age and last logon date to the domain. #>
                $Counter=0
                $Active=$false
                $DaysPast=Get-DateDiff -StartDate $ResetDate -EndDate $DateLastSet
                $DaysLogon=Get-DateDiff -StartDate $ResetDate -EndDate $DateLogonDate
                ForEach($CurrentDC In $DCArray){
                    If((($DaysPast-le30-and$DaysPast-ge0)-or($DaysLogon-le30-and$DaysLogon-ge0))-and($CurrentDC-eq$FocusDC)){
                        $Active=$true
                        $Message=Set-DisplayMessage -Description "$ADHostName changed it's password and/or logged into the '$SearchDomain' domain within 30 days" -FontColor Cyan -Background DarkBlue
                        Break
                    }Else{
                        ForEach($CN In $($ADServerList[$Counter])[1]){
                            If($CN.Name-eq$ADHostName){
                                $DaysPast=Get-DateDiff -StartDate $ResetDate -EndDate $DateLastSet
                                If($($CN.LastLogonDate).Lenght-lt1){
                                    $DaysLogon=Get-DateDiff -StartDate $ResetDate -EndDate $DateLogonDate
                                    If((0-lt$DaysPast)-or(0-lt$DaysLogon)){
                                        $Message=Set-DisplayMessage -Description "$ADHostName changed it's password and/or logged into the '$SearchDomain' domain within 30 days" -FontColor Yellow -Background DarkBlue
                                        $Active=$true
                                        Break
                                    }
                                }
                                Break
                            }
                        }
                        $Counter++
                    }
                }
                NullVariables -ItemList 'CN','Counter','CurrentDC','DaysLogon','DaysPast','DCArray'.'ADServerList'
                If($Active-eq$false){
                    $Message=Set-DisplayMessage -Description "$ADHostName last logon: '$($Computer.LastLogonDate)' and password was set on: '$($Computer.PasswordLastSet)'" -Background DarkRed
                    $ADHostName|%{Get-ADComputer -Filter {Name -eq $_}}|Remove-ADObject -WhatIf
                    $Results=Get-SystemNetDNS -ComputerName $Computer.Name
                    NullVariables -ItemList 'AddressList','LineItem','RecordData','SearchType','SearchValue','SubArray','ValueCheck'
                    If($Results.Found-eq$true){
                        If($Computer.IPv4Address.Length-gt1){
                            [IPAddress]$AddressList=$Computer.IPv4Address
                        }Else{
                            [IPAddress]$AddressList=$null
                        }
                        $Results=Get-ForwardDnsData -WorkLocation $WorkingPath -DNSServer $FocusDC -SystemName $Computer.Name -IPAddress $AddressList
                        NullVariables -ItemList 'Data','FileName','ForwardZoneInfo','Found','Record','RecordType','RRType','SubDomain','Zone','ZoneName','ZoneRecord','ZoneRecords','Zones'
                        If($Results.Found-eq$true){
                            $RRType=$Results.RRType
                            $ZoneName=$Results.ZoneName
                            $NetBIOS=$Results.HostName
                            $IPv4Address=$Results.AddressList.IPAddressToString
                            Remove-DnsServerResourceRecord -ZoneName "$ZoneName" -ComputerName $FocusDC -RRType "$RRType" -Name "$NetBIOS" -RecordData "$IPv4Address" -WhatIf
                            NullVariables -ItemList 'IPv4Address','NetBIOS','RRType','ZoneName'
                        }
                    }
                    If($Computer.IPv4Address.Length-gt1){
                        $Results=Get-ReverseDnsData -WorkLocation $WorkingPath -DNSServer $FocusDC -SystemName $Computer.Name -IPAddress $Computer.IPv4Address
                        NullVariables -ItemList 'Data','FileName','ReverseZoneInfo','Found','Record','RecordData','RecordType','RRType','Zone','ZoneName','ZoneRecord','ZoneRecords','Zones'
                        If($Results.Found-eq$true){
                            $RRType=$Results.RRType
                            $ZoneName=$Results.ZoneName
                            $Octate4=$Results.HostName
                            $RecordData=$Results.PtrDomainName
                            Remove-DnsServerResourceRecord -ZoneName "$ZoneName" -ComputerName $FocusDC -RRType "$RRType" -Name "$Octate4" -RecordData "$RecordData" -WhatIf
                            NullVariables -ItemList 'ReverseDNS','Octate4','RRType','ZoneName'
                        }
                    }
                }Else{
                    <# Retrieving the Forward Lookup information of each system from DNS. #>
                    $Results=Get-SystemNetDNS -ComputerName $Computer.Name
                    NullVariables -ItemList 'AddressList','LineItem','RecordData','SearchType','SearchValue','SubArray','ValueCheck'
                    If($Results.Found-eq$true){
                        $ForwardDNS=$Results.HostName
                        $Aliases=$Results.Aliases
                        [IPAddress]$AddressList=$Results.AddressList.IPAddressToString
                        $Results=Get-ForwardDnsData -WorkLocation $WorkingPath -DNSServer $FocusDC -SystemName $Computer.Name -IPAddress $($AddressList.IPAddressToString)
                        NullVariables -ItemList 'Data','FileName','ForwardZoneInfo','Found','Record','RecordType','SubArray','SubDomain','Zone','ZoneName','ZoneRecord','ZoneRecords','Zones'
                        If($Results.Found-eq$true){
                            $Message=Set-DisplayMessage -Description "The hostname '$($Results.HostName.ToLower())' has return the IP Address '$($Results.AddressList.IPAddressToString)' as it's Forward Lookup record." -FontColor Cyan -Background DarkBlue
                        }Else{
                            $Message=Set-DisplayMessage -Description "Didn't find the Forward Lookup record for '$($Results.HostName.ToLower())'." -FontColor Yellow -Background DarkRed
                        }
                    }Else{
                        <# Check the exported DNS Records for the system using available information. #>
                        $Message=Set-DisplayMessage -Description "Didn't find the Forward Lookup record for '$($Computer.Name.ToLower())'." -FontColor Cyan -Background DarkRed
                        If($Computer.IPv4Address.Length-gt1){
                            [IPAddress]$AddressList=$Computer.IPv4Address.IPAddressToString
                        }Else{
                            $Message=Set-DisplayMessage -Description "Didn't find the Reverse Lookup record for '$($Computer.Name.ToLower())'." -FontColor Cyan -Background DarkRed
                            $MissingIPAddress=$true
                            $AddressList=$null
                        }
                        $Results=Get-ForwardDnsData -WorkLocation $WorkingPath -DNSServer $FocusDC -SystemName $Computer.Name -IPAddress $AddressList
                        NullVariables -ItemList 'Data','FileName','ForwardZoneInfo','Found','Record','RecordType','SubArray','SubDomain','Zone','ZoneName','ZoneRecord','ZoneRecords','Zones'
                        If($Results.Found-eq$true){
                            [IPAddress]$AddressList=$Results.AddressList.IPAddressToString
                            If($($Results.AddressList.IPAddressToString).length-gt1){
                                $MatchIP=$false
                                $Results=Get-SystemNetDNS -IPAddress $AddressList.IPAddressToString
                                NullVariables -ItemList 'AddressList','LineItem','RecordData','SearchType','SearchValue','SubArray','ValueCheck'
                                If($Results.Found-eq$true){
                                    If($($Computer.Name).Substring(0,2)-eq"fs"){
                                        ForEach($CurrentIP In $($Results).AddressList.IPAddressToString){
                                            If($AddressList.IPAddressToString-eq$CurrentIP){$MatchIP=$true;Break}
                                        }
                                    }ElseIf($AddressList.IPAddressToString-eq$Results.AddressList.IPAddressToString){
                                        $Message=Set-DisplayMessage -Description "The hostname '$($Results.HostName.ToLower())' has return the IP Address '$($Results.AddressList.IPAddressToString)' as it's Forward Lookup record." -FontColor Cyan -Background DarkBlue
                                        $MatchIP=$true
                                    }
                                    If($MatchIP-eq$true){
                                        $ForwardDNS=$($Results).HostName.Split(".")[0]
                                        $Aliases=$Results.Aliases
                                    }
                                }
                            }
                        }Else{
                            $MissingIPAddress=$true
                            If($($Computer.DNSHostName).Split(".")[1]-ne$UserDomain){
                                $Results=$($Computer.DNSHostName.Split(".")[1]),$Computer.Name.ToLower()
                                $ForwardDNS="$($Results[1].SubString(0,4))$($Results[0])$($Results[1].Remove(0,4))"
                                $Results=Get-SystemNetDNS -ComputerName $ForwardDNS
                                NullVariables -ItemList 'AddressList','LineItem','RecordData','SearchType','SearchValue','SubArray','ValueCheck'
                                If($Results.Found-eq$true){
                                    $ForwardDNS=$Results.HostName
                                    $Aliases=$Results.Aliases
                                    [IPAddress]$AddressList=$Results.AddressList.IPAddressToString
                                    $Message=Set-DisplayMessage -Description "The hostname '$($Results.HostName.ToLower())' has return the IP Address '$($Results.AddressList.IPAddressToString)' as it's Forward Lookup record." -FontColor Cyan -Background DarkBlue
                                }Else{
                                    $Message=Set-DisplayMessage -Description "The hostname '$($ForwardDNS.ToLower())' isn't returning a Forward Lookup record." -FontColor Cyan -Background DarkRed
                                }
                            }

                        }
                    }
                    NullVariables -ItemList 'CurrentIP','MatchIP','Message','Results'
                    <# Retrieving the Reverse Lookup information of each system from DNS. #>
                    If($Computer.IPv4Address.Length-lt1){
                        [IPAddress]$ResolvedIP=$AddressList.IPAddressToString
                        $MissingIPAddress=$true
                    }Else{
                        <# Comparing the IP Address from DNS against the data from the AD Export. #>
                        If($Computer.IPv4Address-eq$AddressList.IPAddressToString){
                            [IPAddress]$ResolvedIP=$Computer.IPv4Address
                        }Else{
                            $InvalidIPAddress=$true
                            $Results=Get-SubDomain -NetBIOS $($Computer.Name).ToLower() -IPAddress $AddressList.IPAddressToString
                            NullVariables -ItemList 'Campus','Left','Right','SubDomain'
                            $SubDomain=$Results.SubDomain
                        }
                        <# Verify that system is configured for the correct Reverse Lookup Zone. #>
                    }
                    If($($ResolvedIP.IPAddressToString).length-gt1){
                        $Results=Get-SystemNetDNS -IPAddress $ResolvedIP
                        NullVariables -ItemList 'AddressList','LineItem','RecordData','SearchType','SearchValue','SubArray','ValueCheck'
                        If($Results.Found-eq$true){
                            $ReverseDNS=$Results.HostName
                            $Aliases=$Results.Aliases
                            [IPAddress]$AddressList=$Results.AddressList.IPAddressToString
                        }
                    }
                    If($Computer.DNSHostName.Length-lt1){
                        $ResolvedDNS=$ReverseDNS
                        $MissingDNS=$true
                    }Else{
                        <# Comparing the FQDN from DNS against the data from the AD Export. #>
                        If($Computer.DNSHostName-eq$ReverseDNS){
                            $ResolvedDNS=$Computer.DNSHostName
                        }Else{
                            $InvalidFQDN=$true
                            If($ForwardDNS.Length-lt1){$ForwardDNS=$Computer.Name.ToLower()}
                            $Results=Get-SubDomain -NetBIOS $ForwardDNS
                            NullVariables -ItemList 'Campus','Left','Right','SubDomain'
                            $SubDomain=$Results.SubDomain
                            $ResolvedDNS="$($Results.HostName).$SubDomain.$SearchDomain"
                        }
                        <# Verify that system is configured for the correct Forward Lookup Zone. #>
                    }
                    NullVariables -ItemList 'AddressList','Aliases','ForwardDNS','IPAddress','ResolvedDNS','ResolvedIP','ReverseDNS','SubDomain'
                    If(($MissingIPAddress-eq$true)-or($InvalidIPAddress-eq$true)){
#                        Add-DnsServerResourceRecordPtr -ComputerName "$FocusDC" -Name "$ResolvedIP" -ZoneName "$ZoneName" -AllowUpdateAny -TimeToLive 00:05:00 -AgeRecord -PtrDomainName "$ModifiedDNS" -WhatIf
                        $BadIPAddress++
                    }
                    If(($MissingDNS-eq$true)-or($InvalidFQDN-eq$true)){
#                        Add-DnsServerResourceRecordA -ComputerName "$FocusDC" -Name "$ResolvedIP" -ZoneName "$ZoneName" -AllowUpdateAny -IPv4Address "$ResolvedIP" -TimeToLive 00:05:00 -WhatIf
#                        Set-ADComputer -Identity $Computer.Name -DNSHostName "$ResolvedName" -WhatIf
                        $BadComputer++
                    }
                }
                NullVariables -ItemList 'ADHostName','Message'
                <# Separating the list into active and stale computers for a running count. #>
                If($Active-eq$true){
                    $ActiveConnection++
                }Else{
                    $StaleConnection++
                }
                If($MissingDate-eq$true){
                    $NotLoggedOn++
                }
                For($l=0;$l-lt3;$l++){
                    $Message=Set-DisplayMessage -Description "" -Background Black
                }
                NullVariables -ItemList 'Active','DateChanged','DateCreated','DateLastSet','DateLogonDate','DaysLogon','DaysPast','l','Message'
            }
        }
        NullVariables -ItemList 'Computer','ComputerList','NetBIOS','OS','RootSystems','Computer','ComputerList','DaysLogon','DaysPast','NetBIOS','OS','RootSystems'
    }Else{
        $Message=Set-DisplayMessage -Description "The AD-Export file is missing!" -StatusMessage "Not able to process file: '$ExportFile'" -FontColor Yellow -Background DarkRed
    }
    NullVariables -ItemList 'ExportFile','Message'
    $Zones=@(Get-DnsServerZone -ComputerName $FocusDC)
    $Message=Set-DisplayMessage -Description "Removing temporary files that were created on '$WorkingPath' for each DNS Forward and Reserve Zones from '$FocusDC'." -FontColor White -RightJustified $false
    ForEach($Zone In $Zones){
	    $ZoneExport="$($Zone.ZoneName)"
        $ZoneExport="$WorkingPath\$($ZoneExport).csv"
        If(Test-Path -Path $ZoneExport){Remove-Item -Path $ZoneExport}
    }
    NullVariables -ItemList 'FocusDC','Message','WorkingPath','Zone','ZoneExport','Zones'
#    Clear-Host;Clear-History
}
$Message=Set-DisplayMessage -Description ""
$FinishTime=(Get-Date).toString('yyyy/M/d H:mm:ss')
$FinishTime=[DateTime]::ParseExact($FinishTime,'yyyy/M/d H:mm:ss',$null)
$EndTime=Get-TimeDiff -StartDate $StartTime -EndDate $FinishTime
$Message="Total time to process: [{0:c}|(H:mm:ss)]" -f $EndTime
[Int]$TotalConnections=$ActiveConnection+$StaleConnection
$Message+="; Active systems: [$ActiveConnection]"
$Message+="; Systems to be removed from AD: [$StaleConnection]"
$Message+="; Systems that haven't been logged into [$NotLoggedOn]"
$Message+="; System that failed to respond to ping: [$BadIPAddress]"
$Message+="; Systems not in DNS: [$BadComputer]"
$Message+="; Total systems processed: [$TotalConnections]"
$Message=Set-DisplayMessage -Description $Message -RightJustified $false
$Message=Set-DisplayMessage -Description ""
Set-Location -Path "$env:SystemRoot\System32"