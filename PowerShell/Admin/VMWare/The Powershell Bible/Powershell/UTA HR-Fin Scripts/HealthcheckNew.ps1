####################################
# VMware VirtualCenter server name #
####################################
$vcserver="vc-manager-ardc.shared.utsystem.edu"
$vcuser = "shared\dgrays-uta"
$vcpass = ""

##################
# Add VI-toolkit #
##################
Add-PSsnapin VMware.VimAutomation.Core
# Initialize-VIToolkitEnvironment.ps1
connect-VIServer -server $vcserver -user $vcuser -password $vcpass

#############
# Variables #
#############

$currentTime = Get-Date -format yyyyMMddHHmm
$filelocation="c:\pwscripts\healthcheck\Healthcheck-" + $currentTime + ".htm"
$vcversion = get-view serviceinstance
$snap = get-vm | get-snapshot
$date=get-date
$dc = Get-Datacenter
##################
# Mail variables #
##################
$enablemail="no"
$smtpServer = "mail.someguy.edu" 
$mailfrom = "VMware Healtcheck <powershell@someguy.edu>"
$mailto = "someguy@someplace.edu"

#############################
# Add Text to the HTML file #
#############################
ConvertTo-Html –title "VMware Health Check " –body "<H1>VMware Health script</H1>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File $filelocation
ConvertTo-Html –title "VMware Health Check " –body "<H4>Date and time</H4>",$date -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File -Append $filelocation
ConvertTo-Html –title "VMware Health Check " –body "<H2>VMware Datacenter</H2>",$dc.name -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File -Append $filelocation

######################
# VMware VC version  #
######################
$vcversion.content.about | select Version, Build, FullName | ConvertTo-Html –title "VMware VirtualCenter version" –body "<H2>VMware VC version.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" |Out-File -Append $filelocation


################
# Cluster Loop #
################
$clusters = get-cluster
foreach ($c in $clusters) {
    
    #####################
    # Cluster Variables #
    #####################
    $stat = Get-Stat -Entity $c.name -stat cpu.usage.average,mem.usage.average -IntervalSecs 10 -MaxSamples 1
    $esx = Get-Cluster $c.name | Get-VMHost
    $ds = $esx | Get-Datastore 
    $vmList = Get-Cluster $c.name | Get-VM
    
    ##############################
    # VMware Cluster Utilization #
    ##############################
    ConvertTo-Html –title "VMware Cluster" –body "<H2>VMware Cluster</H2>",$c.name -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File -Append $filelocation
    $stat | Select MetricID, Value, Unit | ConvertTo-Html -title "VMware Cluster Utilization" –body "<H3>VMware Cluster Utilization.</H3>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File -Append $filelocation
    
    #######################
    # VMware ESX hardware #
    #######################
    $esx | Get-View | ForEach-Object { $_.Summary.Hardware } | Select-object Vendor, Model, MemorySize, CpuModel, CpuMhz, NumCpuPkgs, NumCpuCores, NumCpuThreads, NumNics, NumHBAs | ConvertTo-Html –title "VMware ESX server Hardware configuration" –body "<H3>VMware ESX server Hardware configuration.</H3>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File -Append $filelocation

    #######################
    # VMware ESX versions #
    #######################
    $esx | % { $server = $_ |get-view; $server.Config.Product | select { $server.Name }, Version, Build, FullName }| ConvertTo-Html –title "VMware ESX server versions" –body "<H3>VMware ESX server versions and builds.</H3>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File -Append $filelocation

    #########################
    # Datastore information #
    #########################
    function UsedSpace
    {
    	param($ds)
    	[math]::Round(($ds.CapacityMB - $ds.FreeSpaceMB)/1024,2)
    }

    function FreeSpace
    {
    	param($ds)
    	[math]::Round($ds.FreeSpaceMB/1024,2)
    }

    function PercFree
    {
    	param($ds)
    	[math]::Round((100 * $ds.FreeSpaceMB / $ds.CapacityMB),0)
    }

    $Datastores = Get-Datastore
    $myCol = @()
    ForEach ($Datastore in $Datastores)
    {
	   $myObj = "" | Select-Object Datastore, UsedGB, FreeGB, PercFree
	   $myObj.Datastore = $Datastore.Name
	   $myObj.UsedGB = UsedSpace $Datastore
	   $myObj.FreeGB = FreeSpace $Datastore
	   $myObj.PercFree = PercFree $Datastore
	   $myCol += $myObj
    }
    $myCol | Sort-Object PercFree | ConvertTo-Html –title "Datastore space " –body "<H2>Datastore space available.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File -Append $filelocation

    ##################
    # VM information #
    ##################
    $Report = @()
 
    $vmList | % {
    $vm = Get-View $_.ID
        $vms = "" | Select-Object VMName, Hostname, IPAddress, VMState, TotalCPU, TotalMemory, MemoryUsage, TotalNics, ToolsStatus, ToolsVersion, MemoryLimit, MemoryReservation, CPUreservation, CPUlimit
        $vms.VMName = $vm.Name
        $vms.HostName = $vm.guest.hostname
        $vms.IPAddress = $vm.guest.ipAddress
        $vms.VMState = $vm.summary.runtime.powerState
        $vms.TotalCPU = $vm.summary.config.numcpu
        $vms.TotalMemory = $vm.summary.config.memorysizemb
        $vms.MemoryUsage = $vm.summary.quickStats.guestMemoryUsage
        $vms.TotalNics = $vm.summary.config.numEthernetCards
        $vms.ToolsStatus = $vm.guest.toolsstatus
        $vms.ToolsVersion = $vm.config.tools.toolsversion
        $vms.MemoryLimit = $vm.resourceconfig.memoryallocation.limit
        $vms.MemoryReservation = $vm.resourceconfig.memoryallocation.reservation
        $vms.CPUreservation = $vm.resourceconfig.cpuallocation.reservation
        $vms.CPUlimit = $vm.resourceconfig.cpuallocation.limit
        $Report += $vms
    }
    $Report | ConvertTo-Html –title "Virtual Machine information" –body "<H2>Virtual Machine information.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File -Append $filelocation
    
    #############
    # Snapshots # 
    #############
    $snap | select vm, name,created,description | ConvertTo-Html –title "Snaphots active" –body "<H2>Snapshots active.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />"| Out-File -Append $filelocation

    #################################
    # VMware CDROM connected to VMs # 
    #################################
    $vmList | where { $_ | get-cddrive | where { $_.ConnectionState.Connected -eq "true" } } | Select Name | ConvertTo-Html –title "CDROMs connected" –body "<H2>CDROMs connected.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />"|Out-File -Append $filelocation

    #########################################
    # VMware floppy drives connected to VMs #
    #########################################
    $vmList | where { $_ | get-floppydrive | where { $_.ConnectionState.Connected -eq "true" } } | select Name |ConvertTo-Html –title "Floppy drives connected" –body "<H2>Floppy drives connected.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" |Out-File -Append $filelocation

####################
# End Cluster Loop #
####################
}
    
######################
# E-mail HTML output #
######################
if ($enablemail -match "yes") 
{ 
$msg = new-object Net.Mail.MailMessage
$att = new-object Net.Mail.Attachment($filelocation)
$smtp = new-object Net.Mail.SmtpClient($smtpServer) 
$msg.From = $mailfrom
$msg.To.Add($mailto) 
$msg.Subject = “VMware Healthscript”
$msg.Body = “VMware healthscript”
$msg.Attachments.Add($att) 
$smtp.Send($msg)
}

##############################
# Disconnect session from VC #
##############################

disconnect-viserver -confirm:$false

##########################
# End Of Healthcheck.ps1 #
##########################