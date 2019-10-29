
#Load VMWare Snapin if it hasn't been loaded
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

Function CheckVIConnectivity{
#If connected, show which ones
	if ($defaultVIServers) {
    Write-Host $defaultVIServers
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

CheckVIConnectivity

Get-VM | Select Name, @{N="Cluster";E={Get-Cluster -VM $_}}, `
@{N="ESX Host";E={Get-VMHost -VM $_}}, `
@{N="Datastore";E={Get-Datastore -VM $_}} | `
Export-CSV -path “C:\Users\pshah\Documents\PowerShell Stuff\VM_CLuster_Host_Datastore.csv”
   