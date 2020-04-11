Clear-History;Clear-Host
Import-Module ActiveDirectory
Import-Module ProcessCredentials
$Global:ScriptName="RemoteRegistry.ps1"
$Global:Domain=($env:USERDNSDOMAIN.ToLower())
$Global:DomainUser=(($env:USERNAME+"@"+$Domain).ToLower())
Set-Variable -Name OutputFile -Value ($env:TEMP+"\WindowsServers.txt")
Set-Variable -Name SystemDivide -Value "-------------------------------------------------------------------------------"
Get-ADComputer -Filter{OperatingSystem -like "Windows Server*"} -Properties Name,IPv4Address,OperatingSystem|Sort-Object Name|Select-Object DNSHostName,IPv4Address,OperatingSystem|Out-File $OutputFile
$ServerList=(Get-Content -Path $OutputFile)
Switch($DomainUser){
    {($_-like"sy100*")-or($_-like"sy600*")}{Break}
    Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
}
$SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain ($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=Get-Credential}
Clear-History;Clear-Host
ForEach($Hostname In $ServerList){
    $Source=("\\"+$Domain+"\cifs\Utilities\Services")
    $IPv4=$null
    $Loop=0
    If(($Hostname-like("*."+$Domain+"*"))-and($Hostname-notlike"*2008 R2*")){
        $Hostname=$Hostname.Replace(" ",",")
        $Name=($Hostname.Split(",")[0])
        Do{
            $Loop++
            $IPv4=($Hostname.Split(",")[$Loop])
        }
        Until((!$IPv4-eq"")-or($Loop-gt$Hostname.Length))
        If(($IPv4-like"10.118.*")-or($IPv4-like"10.126.*")){
            If(Test-Connection -ComputerName $Name -Quiet){
                Write-Host $SystemDivide
                Write-Host $Name
                $Sysinternals={PSexec.exe ("\\"+$Name) cmd.exe}
                $Destination=("\\"+$Name+"\C$\Scripts")
                RoboCopy $Source $Destination $ScriptName /R:0 /W:0
                If(Test-Path -Path ($Destination+"\"+$ScriptName)){
                    Try{
                        PSexec.exe ("\\"+$Name) cmd.exe /C "C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe -ExecutionPolicy Bypass -File C:\Scripts\RemoteRegistry.ps1"
                    }Catch{
                    }
                    Remove-Item ($Destination+"\"+$ScriptName)
                }
                Write-Host $SystemDivide
            }
        }
    }
}
Remove-Item $OutputFile -Force -Verbose