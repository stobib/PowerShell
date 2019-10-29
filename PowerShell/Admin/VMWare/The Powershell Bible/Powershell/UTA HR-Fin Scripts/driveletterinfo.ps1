

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




#Gets a list of hosts to find drive information for, make sure there is no break after the last host
$filepath = Read-OpenFileDialog -WindowTitle "Select Text File with hostnames" -InitialDirectory 'C:\' -Filter "Text files (*.txt)|*.txt"
if (![string]::IsNullOrEmpty($filePath)) { Write-Host "You selected the file: $filePath" } 
else { "You did not select a file." }


$hosts = Get-Content -Path $filepath

echo $filepath



#Get Windows servers creds and store in $gcreds

$gcred = Get-Credential -Message "For Windows Guest"

#Constructing an out-array for data export
$OutArray = @()

#Starts the process and loops until the last host in the host.txt file is reached
foreach ($winserver in $hosts){

#Constructing object
$driveobj = "" | Select "FQDN","DriveLetters"

$driveinfo = GET-WMIOBJECT –query “SELECT * from win32_logicaldisk where DriveType = 3” -ComputerName $winserver -Credential $gcred
$driveletters = $driveinfo.DeviceID


#Fill object
$driveobj.FQDN = $winserver

    foreach ($driveletter in $driveletters){
    $driveobj.DriveLetters += $driveletter
    }

#Add object to out-array

$OutArray += $driveobj

#Wipe object for safety
$driveobj = $null

}

$date = get-date -format yyyy_MM_dd-HH-mm-ss 

#Puts file in base of your home folder

$OutArray |Export-Csv "driveletters - $date.csv"