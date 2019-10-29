




$SnapinLoaded = get-pssnapin | Where-Object {$_.name -like "*VMware*"}
if (!$SnapinLoaded) {
	Add-PSSnapin VMware.VimAutomation.Core
    Write-Host "VMware Snapin has been loaded!"
}
else
{
    Write-Host "VMware Snapin was already loaded!"
}

# Show input box popup and return the value entered by the user.
function Read-InputBoxDialog([string]$Message, [string]$WindowTitle, [string]$DefaultText)
{
    Add-Type -AssemblyName Microsoft.VisualBasic
    return [Microsoft.VisualBasic.Interaction]::InputBox($Message, $WindowTitle, $DefaultText)
}


# Show an Open File Dialog and return the file selected by the user.
function Read-OpenFileDialog([string]$WindowTitle, [string]$InitialDirectory, [string]$Filter = "All files (*.*)|*.*", [switch]$AllowMultiSelect)
{  
    Add-Type -AssemblyName System.Windows.Forms
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = $WindowTitle
    if (![string]::IsNullOrEmpty($InitialDirectory)) { $openFileDialog.InitialDirectory = $InitialDirectory }
    $openFileDialog.Filter = $Filter
    if ($AllowMultiSelect) { $openFileDialog.MultiSelect = $true }
    $openFileDialog.ShowHelp = $true    # Without this line the ShowDialog() function may hang depending on system configuration and running from console vs. ISE.
    $openFileDialog.ShowDialog() > $null
    if ($AllowMultiSelect) { return $openFileDialog.Filenames } else { return $openFileDialog.Filename }
}

# Asks the user if they want to continue or exit. 
Function AreYouSure
{
	# Creates a windows dialogue box
	$a = new-object -comobject wscript.shell 
	$intAnswer = $a.popup("Do you want to continue to run this script?",0,"Continue Running Script",4) 
	If ($intAnswer -eq 6) 
	{ 
	    $a.popup("You have chosen to continue running the script! :-)",0,"Continuing Script :-)") 
		#Write decision to the log
		Write-Host ""
		Write-Host "Admin has chosen to continue running the script! :-)"
		Write-Host ""
	} 
	else 
	{ 
	    $a.popup("You have chosen to exit the script! :-(",0,"Now Exiting! :-(") 
		#Write decision to the log
		Write-Host ""
		Write-Host "Admin has chosen to exit the script! :-("
		Write-Host ""
		exit
	} 
	  
	#Button Types  
	# 
	#Value  Description   
	#0 		Show OK button. 
	#1 		Show OK and Cancel buttons. 
	#2 		Show Abort, Retry, and Ignore buttons. 
	#3 		Show Yes, No, and Cancel buttons. 
	#4 		Show Yes and No buttons. 
	#5		Show Retry and Cancel buttons. 
}

#Function to Check Connectivity with VIServer
Function CheckVIConnectivity{
#If connected, show which ones
	if ($defaultVIServers) {
	# Asks the user if they want to continue or exit. 
	AreYouSure	
	}
	Else{
	#If not connected to any hosts, connect to a VCenter
	Write-Host "Prompting for user input"
    $userVIServer = Read-InputBoxDialog -Message "Please enter a valid VCenter Server Hostname or IP" -WindowTitle "VCenter Hostname"
    Connect-VIServer -Server $userVIServer
	Write-Host "Now Connected." -ForegroundColor Red

	}
}



#Capacity Check functions from the internet

function Get-ClusterCapacityCheck {
<#
.SYNOPSIS
Retrieves basic capacity info for VMware clusters

.DESCRIPTION
Retrieves basic capacity info for VMware clusters

.PARAMETER  ClusterName
Name of the Cluster to test the services for

.EXAMPLE
PS C:\> Get-ClusterCapacityCheck -ClusterName Cluster01

.EXAMPLE
PS C:\> Get-Cluster | Get-ClusterCapacityCheck

.NOTES
Author: Jonathan Medd
Date: 18/01/2012
#>

[CmdletBinding()]
param(
[Parameter(Position=0,Mandatory=$true,HelpMessage="Name of the cluster to test",
ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$true)]
[System.String]
$ClusterName
)

begin {
$Finish = (Get-Date -Hour 0 -Minute 0 -Second 0)
$Start = $Finish.AddDays(-1).AddSeconds(1)

New-VIProperty -Name FreeSpaceGB -ObjectType Datastore -Value {
param($ds)
[Math]::Round($ds.FreeSpaceMb/1KB,0)
} -Force

}

process {


$Cluster = Get-Cluster $ClusterName

$ClusterCPUCores = $Cluster.ExtensionData.Summary.NumCpuCores
$ClusterEffectiveMemoryGB = [math]::round(($Cluster.ExtensionData.Summary.EffectiveMemory / 1KB),0)

$ClusterVMs = $Cluster | Get-VM

$ClusterAllocatedvCPUs = ($ClusterVMs | Measure-Object -Property NumCPu -Sum).Sum
$ClusterAllocatedMemoryGB = [math]::round(($ClusterVMs | Measure-Object -Property MemoryMB -Sum).Sum / 1KB)

$ClustervCPUpCPURatio = [math]::round($ClusterAllocatedvCPUs / $ClusterCPUCores,2)
$ClusterActiveMemoryPercentage = [math]::round(($Cluster | Get-Stat -Stat mem.usage.average -Start $Start -Finish $Finish | Measure-Object -Property Value -Average).Average,0)

$VMHost = $Cluster | Get-VMHost | Select-Object -Last 1
$ClusterFreeDiskspaceGB = ($VMHost | Get-Datastore | Where-Object {$_.Extensiondata.Summary.MultipleHostAccess -eq $True} | Measure-Object -Property FreeSpaceGB -Sum).Sum

New-Object -TypeName PSObject -Property @{
Cluster = $Cluster.Name
ClusterCPUCores = $ClusterCPUCores
ClusterAllocatedvCPUs = $ClusterAllocatedvCPUs
ClustervCPUpCPURatio = $ClustervCPUpCPURatio
ClusterEffectiveMemoryGB = $ClusterEffectiveMemoryGB
ClusterAllocatedMemoryGB = $ClusterAllocatedMemoryGB
ClusterActiveMemoryPercentage = $ClusterActiveMemoryPercentage
ClusterFreeDiskspaceGB = $ClusterFreeDiskspaceGB
}
}
}






CheckVIConnectivity

$date = get-date -format yyyy_MM_dd-HH-mm-ss 

$ClusterName=Read-InputBoxDialog -Message "Name of the Cluster that you would like to check." -WindowTitle "Cluster Name"

Get-ClusterCapacityCheck -ClusterName $ClusterName

