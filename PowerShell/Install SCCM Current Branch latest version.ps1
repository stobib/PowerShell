Set-ExecutionPolicy -ExecutionPolicy ByPass
Set-ExecutionPolicy Unrestricted
Clear-History;Clear-Host
If(-NOT([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]“Administrator”)){
    Write-Warning “You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!”
    Break
}
$folderpath="E:\Sources\Scripts"
$SCCMSource="E:\Sources\SCCM_CD\2006"
Try{
    If(Test-Path -Path $SCCMSource){
        Write-Host "found the media for SCCM Current Branch (cd.latest version)"
    }Else{
        Write-Host "Could not find the media for SCCM Current Branch (cd.latest version)..."
        Break
    }
}Catch{
    Write-Host "Something went wrong with the installation of SCCM Current Branch (latest version), aborting."
    Break
}
Set-Variable -Name SCCM_ARDC_Server -Value "w19sccmmpa01.inf.utshare.local"
Set-Variable -Name SCCM_UDCC_Server -Value "w19sccmmpb01.inf.utshare.local"
Set-Variable -Name SCCM_ARDC_Share -Value "A01"
Set-Variable -Name SCCM_UDCC_Share -Value "B01"
Set-Variable -Name IP_Address -Value $null
Set-Variable -Name Octet_1 -Value $null
Set-Variable -Name Octet_2 -Value $null
Set-Variable -Name Octet_3 -Value $null
Set-Variable -Name Octet_4 -Value $null
$IP_Address=Get-NetIpAddress|Where-Object{$_.AddressFamily-eq"IPv4"}
ForEach($IPv4 In $IP_Address.IPAddress){
    $Parser=$IPv4.Split(".")
    For($O=0;$O-le3;$O++){
        Switch($O){
            0{$Octet_1=$Parser[$O];Break}
            1{$Octet_2=$Parser[$O];Break}
            2{$Octet_3=$Parser[$O];Break}
            3{$Octet_4=$Parser[$O];Break}
        }
    }
    If($Octet_1-eq10){
        If(($Octet_2-eq118)-or($Octet_2-eq119)){
            $SiteCode=$SCCM_ARDC_Share
            $SDKServer=$SCCM_ARDC_Server
            $SQLSSBPort="4022"
        }
        If(($Octet_2-eq126)-or($Octet_2-eq127)){
            $SiteCode=$SCCM_UDCC_Share
            $SDKServer=$SCCM_UDCC_Server
            $SQLSSBPort="4023"
        }
        Break
    }
}
$UserDnsDomain=$($env:USERDNSDOMAIN).ToLower()
$Sitename="$UserDnsDomain - Primary Site ($SiteCode)"
$Action="InstallPrimarySite"
$ProductID="BXH69-M62YX-QQD6R-3GPWX-8WMFY"
$SMSInstallDir="E:\Program Files\Microsoft Configuration Manager"
$RoleCommunicationProtocol="HTTPorHTTPS"
$ClientsUsePKICertificate="0"
$PrerequisiteComp="1"
$PrerequisitePath="E:\sources\Downloads"
$ManagementPoint="$SDKServer"
$ManagementPointProtocol="HTTP"
$DistributionPoint="$SDKServer"
$DistributionPointProtocol="HTTP"
$DistributionPointInstallIIS="0"
$AdminConsole="1"
$JoinCEIP="0"
$SQLServerName=$SDKServer
$DatabaseName="CM_$SiteCode"
$CloudConnector="1"
$CloudConnectorServer="$SDKServer"
$UseProxy="0"
$ProxyName=""
$ProxyPort=""
$SysCenterId=""
$conffile=@"
[Identification]
Action="$Action"

[Options]
ProductID="$ProductID"
SiteCode="$SiteCode"
SiteName="$Sitename"
SMSInstallDir="$SMSInstallDir"
SDKServer="$SDKServer"
RoleCommunicationProtocol="$RoleCommunicationProtocol"
ClientsUsePKICertificate="$ClientsUsePKICertificate"
PrerequisiteComp="$PrerequisiteComp"
PrerequisitePath="$PrerequisitePath"
ManagementPoint="$ManagementPoint"
ManagementPointProtocol="$ManagementPointProtocol"
DistributionPoint="$DistributionPoint"
DistributionPointProtocol="$DistributionPointProtocol"
DistributionPointInstallIIS="$DistributionPointInstallIIS"
AdminConsole="$AdminConsole"
JoinCEIP="$JoinCEIP"

[SQLConfigOptions]
SQLServerName="$SQLServerName"
DatabaseName="$DatabaseName"
SQLSSBPort="$SQLSSBPort"

[CloudConnectorOptions]
CloudConnector="$CloudConnector"
CloudConnectorServer="$CloudConnectorServer"
UseProxy="$UseProxy"
ProxyName="$ProxyName"
ProxyPort="$ProxyPort"

[SystemCenterOptions]
SysCenterId="$SysCenterId"

[HierarchyExpansionOption]

"@
If(Test-Path -Path "$folderpath"){
    Write-Host "The folder '$folderpath' already exists, will not recreate it."
}Else{
    mkdir "$folderpath"
}
$ConfigFile=$SiteCode+"_ConfigMgr_AutoSave.ini"
If(Test-Path "$folderpath\$ConfigFile"){
    Write-Host "The file '$folderpath\$ConfigFile' already exists, removing..."
    Remove-Item -Path "$folderpath\$ConfigFile" -Force
}Else{
    Write-Host "Creating '$folderpath\$ConfigFile'..."
}
New-Item -Path "$folderpath\$ConfigFile" -ItemType File -Value $Conffile
Write-Host "about to install SCCM cd.latest version..." -nonewline
$filepath="$SCCMSource\SMSSETUP\bin\X64\Setup.exe"
$Parms=" /script C:\scripts\$ConfigFile"
$Prms=$Parms.Split(" ")
Try{
    & "$filepath" $Prms|Out-Null
}Catch{
    Write-Host "error!" -ForegroundColor red
    Break
}
Write-Host "done!" -ForegroundColor Green
Write-Host "Exiting script, goodbye."
Set-ExecutionPolicy Restricted
