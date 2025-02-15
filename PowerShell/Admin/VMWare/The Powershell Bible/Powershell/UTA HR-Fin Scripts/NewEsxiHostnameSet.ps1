

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



#Starts a transcript of the script output
#Start-Transcript -path "C:\pwscriptoutputs\logs\hostpwchangelog.txt"

#Gets a list of hosts to change fqdn for, make sure there is no break after the last host
$filepath = Read-OpenFileDialog -WindowTitle "Select Text File" -InitialDirectory 'C:\' -Filter "Text files (*.txt)|*.txt"
if (![string]::IsNullOrEmpty($filePath)) { Write-Host "You selected the file: $filePath" } 
else { "You did not select a file." }


$vihosts = Get-Content -Path $filepath


#Starts Error Report recording
$errReport =@()

#Current Hosts Root Password
$rootpswd = Read-Host -Prompt "Enter password for hosts" -AsSecureString

#Secure Current Password translation for script usage
$rootPtr=[System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($rootpswd)
$rootPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($rootPtr)



#Starts the process and loops until the last host in the host.txt file is reached
foreach ($singleViserver in $vihosts){



	#Connects to each host from the hosts.txt list and also continues on any error to finish the list
	Connect-VIServer $singleViserver -User root -Password $rootPassword -ErrorAction SilentlyContinue -ErrorVariable err
	
    $esxcli = Get-EsxCli -vmhost $singleViserver
    
    $domain = "support.shared.utsystem.edu"
    $fqdn = $singleViserver
    $hostname = $singleViserver.Substring(0,9)
    
    write-host $domain 
    write-host $fqdn 
    write-host $hostname
    
    $esxcli.system.hostname.set($null,$fqdn,$null)
	
	
	
	#Disconnects from each server and suppresses the confirmation
	Disconnect-VIServer -Confirm:$False
}


