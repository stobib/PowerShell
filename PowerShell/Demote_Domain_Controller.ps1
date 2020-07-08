#
# Windows PowerShell script for AD DS Deployment
#

Import-Module ADDSDeployment
Uninstall-ADDSDomainController -DemoteOperationMasterRole:$true -DnsDelegationRemovalCredential (Get-Credential) -RemoveDnsDelegation:$true -Force:$true
