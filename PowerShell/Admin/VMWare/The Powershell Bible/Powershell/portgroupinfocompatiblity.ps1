#Add-PSSnapin VMware.VimAutomation.Core
#Connect-VIServer -Server 172.26.116.82 -Protocol https -User sa_dev_tidal -Password Aec@dallas

$dvPortgroup = Get-Virtualportgroup -VirtualSwitch aecdevvs01  -Name dvpg_NO_NETWORK_ACCESS
$dvPortgroupInfo = New-Object PSObject -Property @{            
    Name = $dvPortgroup.Name
    Key = $dvPortgroup.Key
    VlanId = $dvPortgroup.ExtensionData.Config.DefaultPortConfig.Vlan.VlanId
    Portbinding = $dvPortgroup.Portbinding
    NumPorts = $dvPortgroup.NumPorts
    PortsFree = ($dvPortgroup.ExtensionData.PortKeys.count - $dvPortgroup.ExtensionData.vm.count)
}  
$dvPortgroupInfo | ft -AutoSize

$numPorts = $dvPortgroupInfo.NumPorts
$portsFree = $dvPortgroupInfo.PortsFree
$numPorts
$portsFree