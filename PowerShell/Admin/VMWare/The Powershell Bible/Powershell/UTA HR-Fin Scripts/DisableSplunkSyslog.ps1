#Load VMWare PowerCLI Snapin

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


#Actual Script
#Check For VI Server Connectivity

CheckVIConnectivity


$filepath = Read-OpenFileDialog -WindowTitle "Select Text File" -InitialDirectory 'C:\' -Filter "Text files (*.txt)|*.txt"
if (![string]::IsNullOrEmpty($filePath)) { Write-Host "You selected the file: $filePath" } 
else { "You did not select a file." }


$computers = Get-Content -Path $filepath



ForEach($computer in $computers){

    #Get Host and Disable Syslog on Host Firewall
    $ESXiHost = Get-VMHost -Name $computer
    $syslogFirewall = Get-VMHostFirewallException -VMHost $ESXiHost -Name Syslog

        #-----Checks to see if Syslog Firewall rule isn't already enabled
    if ($syslogFirewall.Enabled -eq $true){
    $syslogFirewall | Set-VMHostFirewallException -Enabled $false
    }

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

}



















