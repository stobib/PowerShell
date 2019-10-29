<# modified via a script from https://trevorsullivan.net/2011/05/04/powershell-creating-the-system-management-container/
#  niall brady 2016/12/5
#>

# Get the distinguished name of the Active Directory domain
$DomainDn = ([adsi]"").distinguishedName
# Build distinguished name path of the System container
$SystemDn = "CN=System," + $DomainDn
# Retrieve a reference to the System container using the path we just built
$SysContainer = [adsi]"LDAP://$SystemDn"
$SystemManagementContainer = "ad:CN=System Management,CN=System,$DomainDn" 

 If (!(Test-Path $SystemManagementContainer)) { 
 # Create a new object inside the System container called System Management, of type "container"
  write-host "Creating System Management container..."
  $SysMgmtContainer = $SysContainer.Create("Container", "CN=System Management")

# Commit the new object to the Active Directory database
$SysMgmtContainer.SetInfo()}
else{
write-host "System Management container already exists..."}
write-host "All done."
