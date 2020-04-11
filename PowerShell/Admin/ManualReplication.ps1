Clear-History;Clear-Host
Set-Variable -Name RGName -Value "Domain System Volume"
Set-Variable -Name LogOnServer -Value $env:LOGONSERVER
Set-Variable -Name DNSDomain -Value $env:USERDNSDOMAIN
$DomainControllers=($DNSDomain|%{Get-ADDomainController -Filter * -Server $_})
ForEach($DC In $DomainControllers){
    If(!($DC.Name-eq($env:COMPUTERNAME).ToLower())){
        $DC.HostName
    # DFSRDiag SyncNow /Partner:$DC.HostName /rgname:$RGName /time:15
    }
}
