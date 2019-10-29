Import-Module ActiveDirectory

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




#Gets a file with information to create users
$filepath = Read-OpenFileDialog -WindowTitle "Select Text File with Users" -InitialDirectory 'C:\' -Filter "Text files (*.txt)|*.txt"
if (![string]::IsNullOrEmpty($filePath)) { Write-Host "You selected the file: $filePath" } 
else { "You did not select a file." }

$newadusers = Import-Csv -Delimiter "," -Path $filepath

foreach($newuser in $newadusers){

    $Displayname = $newuser.Firstname + " " + $newuser.Lastname            
    $NewuserFirstname = $newuser.Firstname            
    $NewuserLastname = $newuser.Lastname            
    $Username = $newuser.Username            
    $SAM = $newuser.Username            
    $UPN = $newuser.Username + "@" + "hr-fin-server.shared.utsystem.edu"
    $AltSec = $newuser.Altsec            
    $Email = $newuser.Email
    $Description = $newuser.Description            
    $Password = ConvertTo-SecureString $newuser.Password -AsPlainText -Force         


    New-ADUser -SamAccountName $SAM -UserPrincipalName $UPN -Name $Username -GivenName $NewuserFirstname -Surname $NewuserLastname -DisplayName $Displayname -Email $Email -Path 'OU=AllUsers,DC=hr-fin-server,DC=shared,DC=utsystem,DC=edu' -AccountPassword $Password -Enabled $true -OtherAttributes @{'altSecurityIdentities'=$AltSec}
    Add-ADGroupMember -Identity "zhrdevpswn1 Remote Desktop Users" -Members $SAM
    Add-ADGroupMember -Identity "zfidevpswn1 Remote Desktop Users" -Members $SAM
    Add-ADGroupMember -Identity "zapdevpswn1 Remote Desktop Users" -Members $SAM
    Add-ADGroupMember -Identity "Database Admins" -Members $SAM
    Add-ADGroupMember -Identity "Domain Admins" -Members $SAM 


}

