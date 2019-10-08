Clear-Host;Clear-History
Import-Module ProcessCredentials
$Global:ResetHost=@()
$Global:SecureCredentials=$null
$Global:Domain=("utshare.local")
$Global:DNSServer=("dcb01."+$Domain).ToLower()
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
Function ChangesDNSRecords{Param([Parameter(Mandatory=$True)]$Hostname,[IPAddress][Parameter(Mandatory=$True)]$IPAddress)
    $AddressList=([System.Net.Dns]::GetHostEntry($Hostname).AddressList)
    $NetBIOS=$Hostname.ToString().Split(".")[0]
    $Zone=($Hostname.ToString().Split(".")[1]+"."+$Domain)
    $Ptr=($IPAddress.IPAddressToString).Split(".")[3]
    $Subptr=($IPAddress.IPAddressToString).Split(".")[2]
#    $ZonePtr=($Subptr+".118.10.in-addr.arpa")
    $ZonePtr=($Subptr+".126.10.in-addr.arpa")
    Try{
        Remove-DnsServerResourceRecord -ComputerName $DNSServer -ZoneName $Zone -RRType A -Name $NetBIOS -RecordData $AddressList.IPAddressToString -Force
        Add-DnsServerResourceRecordA -ComputerName $DNSServer -Name $NetBIOS -ZoneName $Zone -AllowUpdateAny -IPv4Address $IPAddress -TimeToLive 01:00:00
        Add-DnsServerResourceRecordPtr -ComputerName $DNSServer -Name $Ptr -ZoneName $ZonePtr -AllowUpdateAny -TimeToLive 01:00:00 -PtrDomainName $Hostname
    }Catch{
    }
}
Switch($DomainUser){
    {($_-like"sy10*")-or($_-like"sy60*")}{Break}
    Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
}
$SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain ($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=get-credential}
If(Test-Path -Path $InputFile){
    ForEach($ServerInfo In [System.IO.File]::ReadLines($InputFile)){
        $FQDN=$ServerInfo.Split(",")[0]
#        $IPv4=($ServerInfo.Split(",")[1].Replace("126","118"))
        $IPv4=($ServerInfo.Split(",")[1].Replace("118","126"))
        ChangesDNSRecords -Hostname $FQDN -IPAddress $IPv4
    }
}
Set-Location ($env:SystemRoot+"\System32")