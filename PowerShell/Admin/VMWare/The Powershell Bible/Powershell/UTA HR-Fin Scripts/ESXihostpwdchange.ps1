

#Load VMWare Snapin if it hasn't been loaded
$ModuleLoaded = Get-Module | Where-Object {$_.name -like "*VMware*"}
if (!$ModuleLoaded) {
	Get-Module –ListAvailable VM* | Import-Module
    Write-Host "VMware Module has been loaded!"
}
else
{
    Write-Host "VMware Module was already loaded!"
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

#Gets a list of hosts to change passwords for, make sure there is no break after the last host
$filepath = Read-OpenFileDialog -WindowTitle "Select Text File" -InitialDirectory 'C:\' -Filter "Text files (*.txt)|*.txt"
if (![string]::IsNullOrEmpty($filePath)) { Write-Host "You selected the file: $filePath" } 
else { "You did not select a file." }


$vihosts = Get-Content -Path $filepath


#Starts Error Report recording
$errReport =@()

#Current Hosts Root Password
$rootpswd = Read-Host -Prompt "Enter current password for hosts" -AsSecureString

#Secure Current Password translation for script usage
$rootPtr=[System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($rootpswd)
$rootPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($rootPtr)


#New Root Password
$newpass = Read-Host -Prompt "New root password" -AsSecureString

#Secure New Password translation for script usage
$newpassPtr=[System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($newpass)
$newPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($newpassPtr)


#Starts the process and loops until the last host in the host.txt file is reached
foreach ($singleViserver in $vihosts){



	#Connects to each host from the hosts.txt list and also continues on any error to finish the list
	Connect-VIServer $singleViserver -User root -Password $rootPassword -ErrorAction SilentlyContinue -ErrorVariable err
	
	
	$errReport += $err

    
	if($err.Count -eq 0){
	#Sets the root password
	Set-VMHostAccount -UserAccount root -Password $newPassword
	}
	
	#Disconnects from each server and suppresses the confirmation
	Disconnect-VIServer -Confirm:$False
	$errReport += $err
	$err = ""
}

#Outputs the error report to a CSV file, if file is empty then no errors.
$errReport | Export-Csv ".\Pass-HostReport.csv" -NoTypeInformation

#Stops the transcript
#Stop-Transcript
