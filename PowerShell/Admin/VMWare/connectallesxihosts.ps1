# PowerCLI script to add ESXi hosts to vCenter Server
# Version 1.0
# Magnus Andersson – Sr Staff Solution Architect @Nutanix
#
#
# ---------------------------------------------------
# Edit the information below to match your environment
#
# Specify vCenter Server, vCenter Server username, vCenter Server user password, vCenter Server location which can be the Datacenter, a Folder or a Cluster (which I used).
$vCenter="vcmgr01a.inf.utshare.local"
$vCenterUser="mandersson@vcdx56.local"
$vCenterUserPassword="not-secret"
$vcenterlocation="npx005-01"
#
# Specify the ESXi host you want to add to vCenter Server and the user name and password to be used.
$esxihosts=("esxinut001.vcdx56.local","esxinut002.vcdx56.local","esxinut003.vcdx56.local","esxinut004.vcdx56.local")
$esxihostuser="root"
$esxihostpasswd="not-secret"
#
# You don't have to change anything below this line
# ---------------------------------------------------
#
#Connect to vCenter Server
write-host Connecting to vCenter Server $vcenter -foreground green
Connect-viserver $vCenter -user $vCenterUser -password $vCenterUserPassword -WarningAction 0 | out-null
#
write-host --------
write-host Start adding ESXi hosts to the vCenter Server $vCenter
write-host --------
#
# Add ESXi hosts
foreach ($esxihost in $esxihosts) {
Add-VMHost $esxihost -Location $vcenterlocation -User $esxihostuser -Password $esxihostpasswd
}
#
# Disconnect from vCenter Server
write-host "Disconnecting to vCenter Server $vcenter" -foreground green
disconnect-viserver -confirm:$false | out-null