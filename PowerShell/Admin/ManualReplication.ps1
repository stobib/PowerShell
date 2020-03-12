Clear-History;Clear-Host
Set-Variable -Name RGName -Value "Domain System Volume"
Set-Variable -Name LogOnServer -Value $env:LOGONSERVER
Set-Variable -Name DNSDomain -Value $env:USERDNSDOMAIN
# $DCList=((Get-ADForest).Domains|%{Get-ADDomainController -Filter * -Server $_}).HostName
$DomainControllers=($DNSDomain|%{Get-ADDomainController -Filter * -Server $_}).HostName
ForEach($DC In $DomainControllers){
    DFSRDiag SyncNow /Partner:$DC /rgname:$RGName /time:15
}

