<# modified via a script from https://gallery.technet.microsoft.com/Create-System-Management-0d6b7909
#  niall brady 2016/12/5
#>

#Import AD module if not already loaded
Import-Module -Name ActiveDirectory
# Derive domain name
$namingContext = (Get-ADRootDSE).defaultNamingContext
$ConfigMgrSrv = $env:COMPUTERNAME
# Define path for System Management Container
$sccmContainer = "CN=System Management,CN=System,$namingContext"
# Get SID of SCCM Server
$configMgrSid = [System.Security.Principal.IdentityReference] (Get-ADComputer $ConfigMgrSrv).SID
# Get current ACL set for System Management Container
$cnACL = Get-Acl -Path "ad:$sccmContainer"
# Sepcify Permission to Full Control
$adPermissions = [System.DirectoryServices.ActiveDirectoryRights] 'GenericAll'
# Specify Permission type to allow access
$permissionType = [System.Security.AccessControl.AccessControlType] 'Allow'
# Set Inheritance for the Container to "This object and all child objects"
$inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] 'All'
# Set System Management container Access Control Entry
$cnACE = New-Object -TypeName System.DirectoryServices.ActiveDirectoryAccessRule -ArgumentList $configMgrSid, $adPermissions, $permissionType , $inheritanceType
# Add Access Control Entry to existing ACL
$cnACL.AddAccessRule($cnACE) 
# Finally Set ACL on System Management Container
Set-Acl -AclObject $cnACL -Path "AD:$sccmContainer"
write-host "Permissions delegated."