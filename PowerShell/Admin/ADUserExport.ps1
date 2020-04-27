Clear-History;Clear-Host
Import-Module ActiveDirectory
Import-Module ProcessCredentials
$CurrentLocation=Get-Location
$Global:DomainUser=($env:USERNAME.ToLower())
$Global:Domain=($env:USERDNSDOMAIN.ToLower())
$ScriptPath=$MyInvocation.MyCommand.Definition
$ScriptName=$MyInvocation.MyCommand.Name
Set-Location ($ScriptPath.Replace($ScriptName,""))
$path=Split-Path -parent (".\Report\ExportADUsers")
If(!(Test-Path -Path $path)){mkdir -Path $path}
$LogDate=Get-Date -f yyyyMMddhhmm
$csvfile=($path+"\ALLADUsers_$logDate.csv")
$SearchBase="OU=AllUsers,DC=utshare,DC=local"
Switch($DomainUser){
    {($_-like"sy100*")-or($_-like"sy600*")}{Break}
    Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
}
$SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=Get-Credential}
$ADServer=("dca01."+$env:USERDNSDOMAIN.ToLower())
$AllADUsers=Get-ADUser -server $ADServer -Credential $SecureCredentials -searchbase $SearchBase -Filter * -Properties *|
Where-Object{($_.sAMAccountName-notlike'*svc*')-and($_.Description-notlike'*service account*')}
$AllADUsers|Select-Object @{Label="First Name";Expression={$_.GivenName}},
@{Label="Last Name";Expression={$_.Surname}},
@{Label="Display Name";Expression={$_.DisplayName}},
@{Label="Logon Name";Expression={$_.sAMAccountName}},
@{Label="Description";Expression={$_.Description}},
@{Label="Email";Expression={$_.Mail}},
@{Label="EPPN";Expression={$_.altSecurityIdentities}},
@{Label="Last Logon";Expression={$_.lastLogon}},
@{Label="Logon Count";Expression={$_.logonCount}},
@{Label="Password Last Set";Expression={$_.pwdLastSet}},
@{Label="When Created";Expression={$_.whenCreated}},
@{Label="When Expires";Expression={$_.accountExpires}},
@{Label="Home Folder";Expression={$_.homeDirectory}},
@{Label="Account Status";Expression={if(($_.Enabled-eq'TRUE')){'Enabled'}Else{'Disabled'}}},
@{Label="Last LogOn Date";Expression={$_.lastlogondate}}|Export-Csv -Path $csvfile -NoTypeInformation
Set-Location $CurrentLocation