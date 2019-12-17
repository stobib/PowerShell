Clear-Host;Clear-History
Import-Module ProcessCredentials
Import-Module Posh-SSH
$Global:Domain=("utshare.local")
$Global:DomainUser=(($env:USERNAME+"@"+$Domain).ToLower())
Switch($DomainUser){
    {($_-like"sy10*")-or($_-like"sy60*")}{Break}
    Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
}
$SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain ($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=get-credential}
$secpas=$SecureCredentials.Password
$ServerList=@("arcsdevibz01.dev.utshare.local")
$Command=("ls -al /home/"+($DomainUser).Split("@")[0])
Foreach($FQDN In $ServerList){
    $Results=$null
    $SessionID=New-SSHSession -ComputerName $FQDN -Credential $SecureCredentials
    $Results=Invoke-SSHCommand -Index $SessionID.sessionid -Command $Command
    If($Results.ExitStatus-eq0){
        Write-Host("`tSuccessfully connected to "+$FQDN+" using [Posh-SSH].")
    }ElseIf($Results.ExitStatus-eq2){
        $stream = $SessionID.Session.CreateShellStream("PS-SSH", 0, 0, 0, 0, 100)
        $SSHusersName = ($DomainUser).Split("@")[0].Trim()
        $Command=("chown "+$SSHusersName+" /home/"+$SSHusersName+"/ -R")
        $results = Invoke-SSHStreamExpectSecureAction -ShellStream $stream -Command ("sudo su -") -ExpectString "[sudo] password for $($SSHusersName):" -SecureAction $secpas
        $Results=Invoke-SSHCommandStream -SSHSession $SessionID -Command $Command
        Write-Host $Results
    }Else{
        Write-Host $Results
    }
    $SessionID.Disconnect()
}