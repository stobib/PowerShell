<# 
.NAME
    LARD - LAPS Admin Remote Desktop 
.SYNOPSIS
    facilitates LAPS RDP connections with GUI and credential lookup. Basically, if you have rights to 
    look up the password in AD, then the LARD button turns green. If you don't have rights, it turns 
    red. If green, you can click it to open up an RDS connection to that endpoint.
.SpecialThanks 
    to Jaap Brasser http://www.jaapbrasser.com - the RDP session code was taken from his Connect-Mstsc.ps1
    script at https://gallery.technet.microsoft.com/scriptcenter/Connect-Mstsc-Open-RDP-2064b10b
#>

#####################
#  USER Variables   #
#####################

#Gets you your browse list for computers:
$Global:WhereToLookForAllComputers = @('DC=contoso,DC=local')

#Use this account for your local administrator 
#(usually 'Administrator', but LAPS might update a different local account)
$Global:LocalAdminUsername = 'Administrator'

#If you use 'true' for this var, it will make sure that LAPS is working 
#on the endpoint, but it does take more time
$Global:ValidateLAPSCredentials = 'False' 

###################
#  SCRIPT SETUP   #
###################

Import-Module activedirectory
$Global:ADStoredPassword = $null

#####################
#  Functions        #
#####################

Function FormLoad{
    $lblLoggedOnAs.text = "Please wait while I look for computers..."
    $displayList = $null
    foreach ($ADlocation in $Global:WhereToLookForAllComputers ){
    If ($ADlocation -eq 'DC=contoso,DC=local'){
        $Global:cbxServer.text = "Please add OU(s) to line 18"
        }
    else
        {
        $computerlist = Get-ADComputer -filter * -SearchBase $ADlocation -Properties * | sort-object -property name  
        $displayList += $computerlist 
        foreach ($item in $displayList){[void]$Global:cbxServer.items.add($item.name)}
        $lblLoggedOnAs.text = "Connecting Username: $Global:LocalAdminUsername"
        }
        
    }#END foreach adlocation
}#END FUNCTION

function Test-LACredential {
    Param
    (
        [string]$ComputerName
    )
    $cbxServer.text = "checking password for $ComputerName"
    # checking password for $ComputerName
    $Global:ADStoredPassword = $null
    $ComputerInfo = Get-ADComputer $ComputerName -Properties ms-MCS-AdmPwd
    $Global:ADStoredPassword = $ComputerInfo.'ms-MCS-AdmPwd'
    #Write-Host "Testing $ComputerInfo "
    #Write-Host $Global:ADStoredPassword 
    #done checking password
    if (!$Global:ADStoredPassword) {
        #No LAPS password stored in AD, or you don't have rights!
        $Global:btnLocalAdminRDP.BackColor = "#e5bbc0"
        $Global:btnLocalAdminRDP.enabled = $false
        $Global:btnLocalAdminRDP.text = "No LAPS PW!"
        Write-Host "No LAPS PW"  -foregroundcolor RED
    } else {
        #Found password - not testing to see if it really works
        $Global:btnLocalAdminRDP.BackColor = "#dbe6d1"
        $Global:btnLocalAdminRDP.enabled = $true
        $Global:btnLocalAdminRDP.text = "LARD!!"
        Write-Host "Good to go!" -foregroundcolor Green

        #Found password - now testing the password 
        if ($Global:ValidateLAPSCredentials -eq 'True' ){
            Add-Type -AssemblyName System.DirectoryServices.AccountManagement
            $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$ComputerName)
            $DS.ValidateCredentials($Global:LocalAdminUsername, $Global:ADStoredPassword)
            $ok =$?
            if ($ok -eq 'True') {
                #Conclusion: The password test worked
                $Global:btnLocalAdminRDP.BackColor = "#dbe6d1"
                $Global:btnLocalAdminRDP.enabled = $true
                $Global:btnLocalAdminRDP.text = "LARD!!"
                Write-Host "Good to go!" -foregroundcolor Green
		    }
		    else
		    {
			    #Conclusion: The password test failed
                $Global:btnLocalAdminRDP.BackColor = "#e5bbc0"
                $Global:btnLocalAdminRDP.enabled = $false
                $Global:btnLocalAdminRDP.text = "PW Test Fail"
                Write-Host "PW Test Fail" -foregroundcolor RED
            }
        }#END if $Global:ValidateLAPSCredentials 
    }
}#END FUNCTION

function SelectionChangeCommitted {
    $computerselection = $Global:cbxServer.GetItemText($Global:cbxServer.SelectedItem)
    #Check to make sure you can get there
    Test-LACredential $computerselection
}#END FUNCTION

function DropDown{
    $Global:ADStoredPassword = $null

    #Turn the LARD button to gray
    $Global:btnLocalAdminRDP.BackColor = "#e1e1e1"
    $Global:btnLocalAdminRDP.enabled = $false
    $Global:btnLocalAdminRDP.text           = "......"
}#END FUNCTION

function LocalAdminRDPClick {
    Param
    (
        [string]$ComputerName
    )
    #Get username (from variable) and password (from form)
    $ComputerCmdkey = $Global:cbxServer.GetItemText($Global:cbxServer.SelectedItem)
    $User=$ComputerCmdkey + "\" + $Global:LocalAdminUsername
    
    #connecting to $ComputerCmdkey with $User credentials
    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $Process = New-Object System.Diagnostics.Process
            
    # Remove the port number for CmdKey otherwise credentials are not entered correctly
    $ComputerCmdkey = $Global:cbxServer.GetItemText($Global:cbxServer.SelectedItem)
    write-host $ComputerCmdkey
    write-host $User
    $ProcessInfo.FileName    = "$($env:SystemRoot)\system32\cmdkey.exe"
    $ProcessInfo.Arguments   = "/generic:TERMSRV/$ComputerCmdkey /user:$User /pass:$($Global:ADStoredPassword)"
    $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $Process.StartInfo = $ProcessInfo
    [void]$Process.Start()
    
    $ProcessInfo.FileName    = "$($env:SystemRoot)\system32\mstsc.exe"
    $ProcessInfo.Arguments   = "$MstscArguments /v $ComputerCmdkey"
    $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
    $Process.StartInfo       = $ProcessInfo
    [void]$Process.Start()
    $null = $Process.WaitForExit()
}#END FUNCTION

#####################
#  FORM LOGIC       #
#####################

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

#region begin GUI{ 

$frmLAPSRDP                      = New-Object system.Windows.Forms.Form
$frmLAPSRDP.ClientSize           = '600,100'
$frmLAPSRDP.text                 = "LARD - LAPS Admin Remote Desktop by Dan"
$frmLAPSRDP.TopMost              = $false

$lblLoggedOnAs                   = New-Object system.Windows.Forms.Label
$lblLoggedOnAs.text              = "Looking up LAPS passwords..." 
$lblLoggedOnAs.AutoSize          = $true
$lblLoggedOnAs.width             = 25
$lblLoggedOnAs.height            = 10
$lblLoggedOnAs.location          = New-Object System.Drawing.Point(30,20)
$lblLoggedOnAs.Font              = 'Microsoft Sans Serif,10'

$Global:btnLocalAdminRDP                = New-Object system.Windows.Forms.Button
$Global:btnLocalAdminRDP.text           = "......"
$Global:btnLocalAdminRDP.width          = 134
$Global:btnLocalAdminRDP.height         = 30
$Global:btnLocalAdminRDP.location       = New-Object System.Drawing.Point(400,60)
$Global:btnLocalAdminRDP.Font           = 'Microsoft Sans Serif,10'

$Global:cbxServer                       = New-Object system.Windows.Forms.ComboBox
$Global:cbxServer.text                  = "Pick a computer to LARD to"
$Global:cbxServer.width                 = 309
$Global:cbxServer.height                = 40
$Global:cbxServer.location              = New-Object System.Drawing.Point(30,60)
$Global:cbxServer.Font                  = 'Microsoft Sans Serif,12'

$frmLAPSRDP.controls.AddRange(@($lblLoggedOnAs,$Global:btnLocalAdminRDP,$Global:cbxServer))

#region gui events {
$Global:btnLocalAdminRDP.Add_Click({ LocalAdminRDPClick })
$frmLAPSRDP.Add_Load({ FormLoad })
$Global:cbxServer.Add_SelectionChangeCommitted({ SelectionChangeCommitted })
$Global:cbxServer.Add_DropDown({ DropDown })
#endregion events }

#endregion GUI }


#Write your logic code here

[void]$frmLAPSRDP.ShowDialog()

#END