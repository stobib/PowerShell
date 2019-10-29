<#
# Configure ADDS, 2016/12/1 Niall Brady
# Windows PowerShell script for AD DS Deployment
#>

$DomainName = "windowsnoob.lab.local"
$DomainNetbiosName = "WINDOWSNOOB"
$SafeModeAdministratorPassword = convertto-securestring "P@ssw0rd" -asplaintext -force

Install-windowsfeature -name AD-Domain-Services –IncludeManagementTools
Import-Module ADDSDeployment
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "WinThreshold" `
-DomainName $DomainName `
-DomainNetbiosName $DomainNetbiosName `
-ForestMode "WinThreshold" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\Windows\SYSVOL" `
-SafeModeAdministratorPassword $SafeModeAdministratorPassword `
-Force:$true
