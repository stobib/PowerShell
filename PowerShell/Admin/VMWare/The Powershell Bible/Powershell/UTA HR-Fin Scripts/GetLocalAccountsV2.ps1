
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




#Prompt for name of the User

$userExistChk = Read-InputBoxDialog -Message "Please enter the username who you would like to check exsistence of." -WindowTitle "Username to Check"


#Prompt for list of computers and put them into an array

$filepath = Read-OpenFileDialog -WindowTitle "Select Text File" -InitialDirectory 'C:\' -Filter "Text files (*.txt)|*.txt"
if (![string]::IsNullOrEmpty($filePath)) { Write-Host "You selected the file: $filePath" } 
else { "You did not select a file." }


$computers = Get-Content -Path $filepath


#Old functionality for a single computer
# $computer = Read-InputBoxDialog -Message "Please enter the Computer who you would like to examine." -WindowTitle "Computer to Check"


ForEach($computer in $computers){


$objComputer = [ADSI]("WinNT://$computer,computer")


$colUsers = ($objComputer.psbase.children |
    Where-Object {$_.psBase.schemaClassName -eq "User"} |
        Select-Object -expand Name)

$blnFound = $colUsers -contains "$userExistChk"

if ($blnFound)
    {"The user account $userExistChk on $computer exists."}
else
    {"The user account $userExistChk on $computer does not exist."}

}