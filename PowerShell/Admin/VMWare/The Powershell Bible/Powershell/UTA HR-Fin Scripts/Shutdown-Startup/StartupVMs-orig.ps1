<#
#################################################################################
# Power on VMs (StartupVMs.ps1)
#
# Version 1.1 - 22nd November 2012
# Removed loop for checking on connected hypervisors
# 
# .SYNOPSIS
#
# This script does have a 'partner' script that powers the VMs off.
#
# Created By: Graham F French 2012 (@NakedCloudGuy) 
# Taken from script by Mike Preston, 2012 - With a whole lot of help from Eric Wright 
#                                  (@discoposse)
#
# Variables:  $mysecret - a secret word to actually make the script run, stops the script from running when double click DISASTER
#             $StartUpTier1Filename - A numbered filename which allows tiered startups within the vCenter
#			  $waitshutdown - Sleep between each iteration of a loop, in seconds.
#			  $scriptDir - Front part of the relative script path.
#
# Usage: ./StartUpvms.ps1 "keyword"
#        Intended to be ran in the command section of the APC Powerchute Network
#        Shutdown program before the shutdown sequence has started.
#
#################################################################################

  ******************************
  ** Holding Area for Scripts **
  ******************************
	
#>

# Sets up the expectation of a secret keyword to be added when running the script. Stops accidents when double clicking!!
#param($keyword)

# Adds the base cmdlets if needed
$SnapinLoaded = get-pssnapin | Where-Object {$_.name -like "*VMware*"}
if (!$SnapinLoaded) {
	Add-PSSnapin VMware.VimAutomation.Core
}

#some variables
#Tiers Filenames
$StartupTier1Filename = ".\StartupTier1VMs.csv"
$StartupTier2Filename = ".\StartupTier2VMs.csv"
$StartupTier3Filename = ".\StartupTier3VMs.csv"
$StartupTier4Filename = ".\StartupTier4VMs.csv"
$StartupTier5Filename = ".\StartupTier5VMs.csv"
#Others
$ysecret = "kerfuffle"

#Wait time between loops of shutting down VMs, in seconds.
$waitstartup = 4

#Variable to stitch the relative file path together
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

#Variable for Logfile
$date = get-date -format yyyy_MM_dd-HH-mm-ss 
$LogFileName = "LogFileOutput-$date.txt"
$LogFileOutput = (join-Path $scriptDir ./logs/$LogFileName)

 
# # This is the keyword checker
# if ($keyword -ne $mysecret) 
# {
# 	Write-Host "You haven't passed the proper detonation sequence...ABORTING THE SCRIPT" -ForegroundColor red
# 	exit
# }

#Function to write to screen and log file
Function WriteLog ($LogText) {

#Write to screen first
Write-Host "$LogText"

#Then write the same text to the log file, including the date stamp to the start of the entry in the logfile
$tempDate = get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Output "$tempDate $LogText" | Out-File $LogFileOutput -append 

}

WriteLog ("**********************************************")
WriteLog ("Power on VMs PowerShell")
WriteLog ("Logging output from StartupVMs.PS1")
WriteLog ("**********************************************")
WriteLog
WriteLog

#Main Function to shutdown Servers
function StartupRoutine($ChosenOption){

#Call function to see if we are connected to any host servers
CheckVIConnectivity

#And now, let's start powering off some guests....
#ForEach ( $guest in $inputfile ) 
foreach ( $guest in $ChosenOption ) 
{
	# Check to see if the VM exists, if not then put error onto screen
	# and then continue with loop
	$MyVM = Get-VM -Name $guest -ErrorAction SilentlyContinue
	if($MyVM -eq $null){
		WriteLog
		WriteLog '****************************************'
		WriteLog '****************************************'
		WriteLog "$guest Virtual Machine doesn't exist, please check your list of VMs!" -Foregroundcolor Red
		WriteLog '****************************************'
		WriteLog '****************************************'
		WriteLog
	}
	else {

		# Check to see if the VM is powered of
		# If not, it will continue the loop

		$PowerState = get-vm $guest
		$PowerState = $PowerState.PowerState
		WriteLog "$guest is $PowerState"
		if ($PowerState -eq "PoweredOff") {
			WriteLog
			WriteLog '****************************************'
			WriteLog '****************************************'
			WriteLog "$guest is switched off." -ForegroundColor Green
			WriteLog
			WriteLog
			WriteLog "Processing $guest ...." -ForegroundColor Green
			#WriteLog "Checking for VMware tools install" -Foregroundcolor Green
			WriteLog
			WriteLog
			WriteLog '****************************************'
			WriteLog '****************************************'
			WriteLog

			# Get the version of VMware Tools
			$guestinfo = (Get-VM $guest | Get-View).Guest.ToolsVersion 
			WriteLog "$guest is running VMware Tools Version $guestinfo"
			WriteLog
			WriteLog "Powering On $guest"
			WriteLog
			
			#PowerOn Guest
			Start-VM -VM $guest 
		}
		else {
			WriteLog
			WriteLog "$guest Virtual Machine is already powered on!"
			WriteLog
		}
	}
}

}

#Check to see if there are any hypervisor hosts connected
Function CheckVIConnectivity{
	#If connected, show which ones
	if ($defaultVIServers) {	
			# Asks the user if they want to continue or exit. Depending on the number of servers connected at this stage
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
			Else 
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
			#0 Show OK button. 
			#1 Show OK and Cancel buttons. 
			#2 Show Abort, Retry, and Ignore buttons. 
			#3 Show Yes, No, and Cancel buttons. 
			#4 Show Yes and No buttons. 
			#5 Show Retry and Cancel buttons. 
		}
		Else{
		#If not connected to any hosts, exit the script
		WriteLog
		WriteLog "You are not connected to any servers!" -ForegroundColor Red
		WriteLog "Please try again later, now exiting." -ForegroundColor Red
		WriteLog
		exit
		}
}

Write-Host
Write-Host
Write-Host
Write-Host '****************************************' -ForegroundColor Green
Write-Host '****************************************' -ForegroundColor Green
Write-Host
Write-Host "This script will Start Up your VMs!!" -ForegroundColor Green
Write-Host
Write-Host "Enter 1 to Start Up Tier 1 VMs"
Write-Host
Write-Host "Enter 2 to Start Up Tier 2 VMs"
Write-Host
Write-Host "Enter 3 to Start Up Tier 3 VMs"
Write-Host
Write-Host "Enter 4 to Start Up Tier 4 VMs"
Write-Host
Write-Host "Enter any other key to exit!" -ForegroundColor Magenta
Write-Host
Write-Host '****************************************' -ForegroundColor Green
Write-Host '****************************************' -ForegroundColor Green
Write-Host
Write-Host

#Get input choice from User
$RunType = Read-Host "What is your number choice??"

Write-Host
Write-Host

if ($RunType -eq "1") {

	#Create the input file, which lists the vm's by stitching together the current directory of the script 
	#and the name of the filename with the list of vm's. Call the StartupVM's routine with the correct filename
	WriteLog "You have chosen to Startup Tier 1 VMs"
	$inputfile = get-content (Join-Path $scriptDir $StartupTier1Filename)
	StartupRoutine ($inputfile)
}
elseif ($RunType -eq "2"){

	#Create the input file, which lists the vm's by stitching together the current directory of the script 
	#and the name of the filename with the list of vm's. Call the StartupVM's routine with the correct filename
	WriteLog "You have chosen to Startup Tier 2 VMs"
	$inputfile = get-content (Join-Path $scriptDir $StartupTier2Filename)
	StartupRoutine ($inputfile)
}
elseif ($RunType -eq "3"){
	#Create the input file, which lists the vm's by stitching together the current directory of the script 
	#and the name of the filename with the list of vm's. Call the StartupVM's routine with the correct filename
	WriteLog "You have chosen to Startup Tier 3 VMs"
	$inputfile = get-content (Join-Path $scriptDir $StartupTier3Filename)
	StartupRoutine ($inputfile)
} 
elseif ($RunType -eq "4"){
	#Create the input file, which lists the vm's by stitching together the current directory of the script 
	#and the name of the filename with the list of vm's. Call the StartupVM's routine with the correct filename
	WriteLog "You have chosen to Startup Tier 4 VMs"
	$inputfile = get-content (Join-Path $scriptDir $StartupTier4Filename)
	StartupRoutine ($inputfile)
}
elseif ($RunType -eq "5"){
	#Create the input file, which lists the vm's by stitching together the current directory of the script 
	#and the name of the filename with the list of vm's. Call the StartupVM's routine with the correct filename
	WriteLog "You have chosen to Startup Tier 5 VMs"
	$inputfile = get-content (Join-Path $scriptDir $StartupTier5Filename)
	StartupRoutine ($inputfile)
}
else {
	WriteLog
	WriteLog
	WriteLog "You have not chosen to continue running, therefore exiting!" -ForegroundColor Yellow
	WriteLog
	WriteLog
	exit
}

###get VMs that are still powered on.... :-)
##Write-Host ""
##Write-Host "Retrieving a list of powered on guests...." -Foregroundcolor Green
##Write-Host ""
##$poweredonguests = Get-VM | where-object {$_.PowerState -eq "PoweredOn" }

