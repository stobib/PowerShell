

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



#$credenitals = Get-Credential

$user = Read-InputBoxDialog -Message "Please enter the username whose password you would like to change" -WindowTitle "Username to Change"
$SecurePassword = Read-Host -Prompt "Enter password for user" -AsSecureString



#$filepath = Read-OpenFileDialog -WindowTitle "Select Text File" -InitialDirectory 'C:\' -Filter "Text files (*.txt)|*.txt"
#if (![string]::IsNullOrEmpty($filePath)) { Write-Host "You selected the file: $filePath" } 
#else { "You did not select a file." }


$computers = Get-Content -Path $filepath


# Manual User change commands
#$computers = Get-Content -path C:\fso\computers.txt

$computer = "utaprps1"
#$user = "dgrays-uta"
#$password = "GangamStyle2"

# Determine if local user account exists in systems

# Change User Password in Systems
#Foreach($computer in $computers)
#{
 $user = [adsi]"WinNT://$computer/$user,user"
 $user.SetPassword($SecurePassword)
 $user.SetInfo()
#}