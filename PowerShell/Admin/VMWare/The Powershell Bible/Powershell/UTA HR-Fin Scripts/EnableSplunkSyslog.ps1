
$SnapinLoaded = get-pssnapin | Where-Object {$_.name -like "*VMware*"}
if (!$SnapinLoaded) {
	Add-PSSnapin VMware.VimAutomation.Core
    Write-Host "VMware Snapin has been loaded!"
}
else
{
    Write-Host "VMware Snapin was already loaded!"
}


#Variable to stitch the relative file path together
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

#Variables for Logfile
$date = get-date -format yyyy_MM_dd-HH-mm-ss 
$LogFileName = "EnableSplunkSyslog-$date.txt"
$LogFileOutput = (join-Path $scriptDir ./logs/$LogFileName)


#Function to write to screen and log file
Function WriteLog ($LogText) {

#Write to screen first
Write-Host "$LogText"

#Then write the same text to the log file, including the date stamp to the start of the entry in the logfile
$tempDate = get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Output "$tempDate $LogText" | Out-File $LogFileOutput -append 
}

# Show input box popup and return the value entered by the user.
function Read-InputBoxDialog([string]$Message, [string]$WindowTitle, [string]$DefaultText)
{
    Add-Type -AssemblyName Microsoft.VisualBasic
    return [Microsoft.VisualBasic.Interaction]::InputBox($Message, $WindowTitle, $DefaultText)
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
	WriteLog "Prompting for user input"
    $userVIServer = Read-InputBoxDialog -Message "Please enter a valid VCenter Server Hostname or IP" -WindowTitle "VCenter Hostname"
    Connect-VIServer -Server $userVIServer
	WriteLog "Now Connected, Please Run Again." -ForegroundColor Red
	WriteLog
	exit
	}
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
		WriteLog
		WriteLog "Admin has chosen to continue running the script! :-)"
		WriteLog
	} 
	else 
	{ 
	    $a.popup("You have chosen to exit the script! :-(",0,"Now Exiting! :-(") 
		#Write decision to the log
		WriteLog
		WriteLog "Admin has chosen to exit the script! :-("
		WriteLog
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

#Actual Script
#Check For VI Server Connectivity

CheckVIConnectivity

#Prompt for host name
$hostNamePrompt = Read-InputBoxDialog -Message "Please enter a Hostname of an ESXi Host" -WindowTitle "ESXi Hostname"

#Get Host and Enable Syslog on Host Firewall
$ESXiHost = Get-VMHost -Name $hostNamePrompt
$syslogFirewall = Get-VMHostFirewallException -VMHost $ESXiHost -Name Syslog
#-----Checks to see if Syslog Firewall rule isn't already enabled
if ($syslogFirewall.Enabled -eq $false){
$syslogFirewall | Set-VMHostFirewallException -Enabled $true
}


#Prompt for Syslog Server to forward to

$syslogServer = Read-InputBoxDialog -Message "Please enter a syslog server to forward to" -WindowTitle "Syslog server" -DefaultText "tcp://splunklog-1.support.shared.utsystem.edu:514"

Write-Host $syslogServer
#Set Syslog Forwarding to Server

#-----Updates the front end(Vsphere) option values(mainly cosmetic)
$syslogAdvSet = Get-AdvancedSetting -Entity $ESXiHost -Name Syslog.global.logHost
$syslogAdvSet | Set-AdvancedSetting -Value $syslogServer -Confirm:$false

#-----Ensures actual host remote syslog server value is set
Set-VMHostSysLogServer -VMHost $ESXiHost -SysLogServer $syslogServer -Confirm:$false

#Reload Syslog and refresh Firewall

# --- Restart the Firewall service via ESXCli

Write-Host "Restarting the Firewall service for $ESXiHost"
$ESXCliFW = Get-EsxCli -VMHost $ESXiHost
$RefreshFirewall = $ESXCliFW.Network.Firewall.Refresh()

if ($RefreshFirewall -eq "true"){
Write-Host "Firewall service for $ESXiHost was successfully restarted"
}
else {
Write-Host "There was an issue restarting the Syslog service for $ESXiHost"
}


# --- Restart the Syslog service via ESXCli

Write-Host "Restarting the Syslog service for $ESXiHost"
$ESXCliSS = Get-EsxCli -VMHost $ESXiHost
$RefreshSyslog = $ESXCliSS.System.Syslog.Reload()

if ($RefreshSyslog -eq "true"){
Write-Host "Syslog service for $ESXiHost was successfully restarted"
}
 else {
Write-Host "There was an issue restarting the Syslog service for $ESXiHost"
}



