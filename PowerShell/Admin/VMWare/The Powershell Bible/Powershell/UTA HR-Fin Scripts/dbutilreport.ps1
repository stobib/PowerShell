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


#Function to Check Connectivity with VIServer
Function CheckVIConnectivity{
#If connected, show which ones
	if ($defaultVIServers) {
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

$gcred = Get-Credential -Message "For Guest"
#$hcred = Get-Credential -Message "For Host"

$basescript = @"
echo System information for SYSTEMNAME.
echo ""
echo ""
echo "GETTING KERNEL CONFIG INFORMATION"
echo ""
echo ""
cat /etc/sysctl.conf
echo ""
echo ""
echo "GETTING CPU INFORMATION"
echo ""
echo ""
cat /proc/cpuinfo
echo ""
echo ""
echo "GETTING MEMORY INFORMATION"
echo ""
echo ""
cat /proc/meminfo
echo ""
echo ""
echo "GETTING SWAP INFORMATION"
echo ""
echo ""
cat /proc/swaps
echo ""
echo ""
echo "GETTING FSTAB INFORMATION"
echo ""
echo ""
cat /etc/fstab
echo ""
echo ""
echo "GETTING DISK INFORMATION"
echo ""
echo ""
df -h
"@


$computers = Get-VM -Name *db1* 
$computers += Get-VM -Name *db2*


Foreach($computer in $computers){
$script = $basescript.Replace("SYSTEMNAME",$computer)

$output = Invoke-VMScript -VM $computer -OutVariable $myOutput -ScriptText $script -GuestCredential $gcred  -ScriptType Bash 
Out-File -FilePath 'C:\Users\dgrays\Documents\The Powershell Bible\Powershell\UTA HR-Fin Scripts\dbutilreport.txt'-Append -InputObject $output.ScriptOutput

}



#Write-Host $outputArray.ScriptOutput
