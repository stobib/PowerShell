Clear-History;Clear-Host
Set-Variable -Name DrvLtr -Value "E:"
Set-Variable -Name TargetPath -Value ($DrvLtr+"\Windows\NETLOGON\debug")
Set-Variable -Name DNSDomain -Value $env:USERDNSDOMAIN
$DomainControllers=($DNSDomain|%{Get-ADDomainController -Filter * -Server $_})
ForEach($DC In $DomainControllers){
    If($DC.IsReadOnly-eq$false){
        $CurrentDesPath=($TargetPath+"\"+$DC.Name)
        $SrcNetLogonPath=("\\"+$DC.HostName+"\Admin$\debug")
        Robocopy $SrcNetLogonPath $CurrentDesPath "netlogon.log"
    }
}