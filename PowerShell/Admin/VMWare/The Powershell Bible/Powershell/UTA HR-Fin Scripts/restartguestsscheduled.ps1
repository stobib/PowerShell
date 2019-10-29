

# Add the vmware snapin for powershell
Add-PSSnapin VMware.VimAutomation.Core

# Set some variables.
$datestart = (get-date -uformat %Y-%m-%d)

# Name a logfile to capture results.
$logfile = "VMReboot_" + $datestart + ".txt"

# Put the date in the logfile.
echo  "New Log ($datestart) - ($logfile)" >> $logfile

# Your vcenter server and credentials
$vcenter = "vc-manager-ardc.shared.utsystem.edu"
$username = "shared\dgrays-uta"
$password = "S@lsa-87"

# Establish Connection
connect-viserver -server $vcenter -user $username -password $password
echo  "Connected - ($vcenter)" >> $logfile

#Path to List of VM's to reboot

$filepath = "C:\Users\dgrays-uta\Desktop\Automated Reboot\rebootvms.txt"

$vmlist = Get-Content -Path $filepath

# get list vm's to reboot.  Please CUSTOMIZE THIS before you run it.
#$vmdesktops = Get-VM vm-*
$vmdesktops = $vmlist

# Add (+=) more vm's to reboot.
#$vmdesktops += Get-VM vm7-*


# add dedsktop list to logfile
#echo  "Desktops - ($vmdesktops)" >> $logfile


foreach ($vm in $vmdesktops)

{
   
     $nowDate = Get-Date
    echo "Restart-VMGuest ($vm) at ($nowDate)" >> $logfile
     # Reboot VM using vmtools
#    Restart-VMGuest $vm
    # space out the reboots by 6 minuites or 360 seconds.
    # ping -n 360 localhost

}


