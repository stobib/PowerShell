Clear-Host;Clear-History
Import-Module ProcessCredentials
$Global:CurrentVersion=("5.00.8853.1000")
$Global:SCCMClientLocation=$null
$Script:RemoteTemp=$null
$Global:MPA="A01"
$Global:MPB="B01"
$Global:LogAge="30"
$Global:Message=$null
$Global:SiteCode=$null
$Global:ReturnCode=$null
$Global:LogCleaned=$false
$Global:InstallClient=$false
$Global:ClientLogFileName=$null
$Global:Domain=("utshare.local")
$Global:DomainUser=(($env:USERNAME+"@"+$Domain).ToLower())
$ScriptPath=$MyInvocation.MyCommand.Definition
$ScriptName=$MyInvocation.MyCommand.Name
$ErrorActionPreference='SilentlyContinue'
Set-Location ($ScriptPath.Replace($ScriptName,""))
Set-Variable -Name CCMPath -Value ($env:SystemRoot+"\CCM")
Set-Variable -Name System32 -Value ($env:SystemRoot+"\System32")
Set-Variable -Name LogFolder -Value ($ScriptName.Replace(".ps1",""))
Set-Variable -Name LogFolderPath -Value ($env:USERPROFILE+"\Desktop\"+$LogFolder)
Set-Variable -Name LogName -Value ($LogFolder+".log")
$Global:LogFile=($LogFolderPath+"\"+$LogName)
Set-Variable -Name InputName -Value ($ScriptName.Replace("ps1","txt"))
Set-Variable -Name InputFile -Value ($LogFolderPath+"\"+$InputName)
Set-Variable -Name SystemListName -Value ("ServerList.txt")
Set-Variable -Name SystemListFile -Value ($LogFolderPath+"\"+$SystemListName)
Set-Variable -Name NotRunningName -Value ("SMS_Not_Running.log")
Set-Variable -Name NotRunningFile -Value ($LogFolderPath+"\"+$NotRunningName)
Set-Variable -Name NotInstalledName -Value ("SMS_Not_Installed.log")
Set-Variable -Name NotInstalledFile -Value ($LogFolderPath+"\"+$NotInstalledName)
Set-Variable -Name OfflineName -Value ("Systems_Offline.log")
Set-Variable -Name OfflineFile -Value ($LogFolderPath+"\"+$OfflineName)
# Logs the status of the script in a CMtrace format #
Function Add-LogEntry($LogMessage, $Messagetype){
    # Date and time is set to the CMTrace standard
    # The Number after the log message in each function corisponts to the message type
    # 1 is info
    # 2 is a warning
    # 3 is a error
    Get-LogFileSize -LogFile $ClientLogFileName
    If($LogCleaned-eq$true){
        New-LogFile -LogFile $ClientLogFileName
    }
    Add-Content $ClientLogFileName "<![LOG[$LogMessage]LOG]!><time=`"$((Get-Date -format HH:mm:ss)+".000+300")`" date=`"$(Get-Date -format MM-dd-yyyy)`" component=`"$ScriptName`" context=`"`" type=`"$Messagetype`" thread=`"`" file=`"powershell.exe`">"  -Errorvariable script:NewLogError
}
# Closes the log file and exits the script #
Function Exit-Script(){
    Remove-Item env:SEE_MASK_NOZONECHECKS
    Add-LogEntry("Closing the log file for $ScriptName.")"1"
    Add-LogEntry("********************************************************************************************************************")"1"
    Exit $ReturnCode    
}
# check if cycles are working #
Function Get-ClientActionsStatus{
	If($InstallClient-ne$true){
		Add-LogEntry("---------------------------")"1"
		$MachinePolicyRetrievalEvaluation="{00000000-0000-0000-0000-000000000021}"
		$SoftwareUpdatesDeployment="{00000000-0000-0000-0000-000000000108}"
		$ApplicationDeployment="{00000000-0000-0000-0000-000000000121}"
		If(Get-WmiObject win32_Product|Where-Object Name -EQ "Configuration Manager Client"){
			$machine_status=Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule $MachinePolicyRetrievalEvaluation
			If($machine_status){
				Add-LogEntry("Machine Policy Retrieval Evaluation Action is working correctly")"1" 
			}
			If(!($machine_status)){
				Add-LogEntry("WARNING: Machine Policy Retrieval Evaluation Action is not working correctly")"2"
				Add-LogEntry("This will be resolved by reinstalling the SCCM Client")
				$InstallClient=$true
			}
			$SoftwareUpdate_status=Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule $SoftwareUpdatesDeployment
			If($SoftwareUpdate_status){
				Add-LogEntry("Software Update Deployment Action is working correctly")"1"
			}
			If(!($softwareUpdate_status)){
				Add-LogEntry("WARNING: Software Update Deployment Action is not working correctly")"2"
				Add-LogEntry("This will be resolved by reinstalling the SCCM Client")
				$InstallClient=$true
			}
			$ApplicationDeployment_Status=Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule $ApplicationDeployment
			If($ApplicationDeployment_Status){
				Add-LogEntry("Application Deployment Action is working correctly")
			}
			If(!($ApplicationDeployment_Status)){
				Add-LogEntry("WARNING: Application Deployment Action is not working correctly")"2"
				Add-LogEntry("This will be resolved by reinstalling the SCCM Client")
				$InstallClient=$true
			}
		}
	}
}
# Check if SCCM Client is installed #
Function Get-ClientInstalled{Param([Parameter(Mandatory=$True)]$HostName,[Parameter(Mandatory=$True)]$Credentials)
	Add-LogEntry("---------------------------")"1"
	Add-LogEntry("Checking if SCCM Client is installed")"1"
    $RemoteWmiObject=Get-WmiObject win32_Product -Impersonation 3 -Credential $Credentials -ComputerName $HostName|Where-Object Name -eq "Configuration Manager Client"
    $RemoteService=Get-Service -ComputerName $HostName -Name CcmExec -ErrorAction SilentlyContinue
	If(($RemoteWmiObject)-and($RemoteService)){
		Add-LogEntry("SCCM Client is installed")"1"
        Return ($RemoteWmiObject.Version+";"+$RemoteService.Status)
	}Else{
		Add-LogEntry("WARNING: SCCM Clinet is not installed")"2"
		Add-LogEntry("SCCM Client will be installed after other checks have been completed")"1"
		$InstallClient=$true
	}
}
# Check if dependent services are running and set them to correct startup type #
Function Get-DependentServices{
	If($InstallClient-ne$true){
		Add-LogEntry("---------------------------")"1"
		Add-LogEntry("Checking startup type of CcmExec service")"1"
		If((Get-Service "CcmExec").StartType-ne"Automatic"){
			Add-LogEntry("WARNING: CcmExec service needs to be set to Automatic")"2"
			Add-LogEntry("Attempting to change start type to Automatic")"1"
			Set-Service "CcmExec" -StartupType "Automatic"
			If((Get-Service "CcmExec").StartType-ne"Automatic"){
				Add-LogEntry("ERROR: Could not change start type")"3"
			}
			If((Get-Service "CcmExec").StartType-eq"Automatic"){
				Add-LogEntry("SUCCESS: CcmExec service start type was set to Automatic")"1"
			}
		}Else{
			Add-LogEntry("CcmExec service startup type is correct")"1"
		}
		Add-LogEntry("Checking status of Ccmexec service")"1"
		If((Get-Service -Name "ccmexec").Status-eq"Stopped"){
			Add-LogEntry("WARNING: CCMExec service stopped")"2"
			Add-LogEntry("Attempting to startng CCMExec service")"1"
			Start-Service -Name CcmExec
			start-Sleep -Seconds 10
			If((Get-Service -Name "ccmexec").Status-eq"Stopped"){
				Add-LogEntry("ERROR: Could not start CCMExec service")"3"
			}
			if((Get-Service -Name "ccmexec").Status-ne"Stopped"){
				Add-LogEntry("SUCCESS: started CcmExec service")
			}
		}Else{
			Add-LogEntry("Ccmexec service is running")"1"
		}		
	}
	Add-LogEntry("---------------------------")"1"
	Add-LogEntry("Checking startup type of BITS service")"1"
	If((Get-Service "BITS").StartType-ne"Automatic"){
		Add-LogEntry("WARNING: BITS service needs to be set to Automatic")"2"
		Add-LogEntry("Attempting to change startup type to Automatic")"1"
		Set-Service "BITS" -StartupType "Automatic"
		If((Get-Service "BITS").StartType-ne"Automatic"){
			Add-LogEntry("ERROR: Could not change startup type")"3"
		}
		If((Get-Service "BITS").StartType-eq"Automatic"){
			Add-LogEntry("SUCCESS: BITS service startup type was set to Automatic")
		}
	}Else{
		Add-LogEntry("BITS service startup is set correctly")"1"
	}
	Add-LogEntry("Checking status of BITS service")"1"
	If((Get-Service -Name "BITS").status-eq"Stopped"){
		Add-LogEntry("WARNING: BITS service Stopped")"2"
		Add-LogEntry("Attempting to start BITS service")"1"
		Start-Service -Name "BITS"
		start-Sleep -Seconds 10
		If((Get-Service -Name "BITS").status-eq"Stopped"){
			Add-LogEntry("ERROR: Could not start BITS service")"3"
		}
		If((Get-Service -Name "BITS").status-ne"Stopped"){
			Add-LogEntry("SUCCESS: started BITS service")"1"
		}
	}Else{
		Add-LogEntry("BITS service is started")"1"
	}
	Add-LogEntry("---------------------------")"1"
	Add-LogEntry("Checking startup type of wuauserv service")"1"
	If((Get-Service "wuauserv").StartType-ne"Manual"){
		Add-LogEntry("WARNING: Wuauserv service needs to be set to Manual")"2"
		Add-LogEntry("Attempting to change start type to Manual")"1"
		Set-Service "wuauserv" -StartupType "Manual"
		If((Get-Service "wuauserv").StartType-ne"Manual"){
			Add-LogEntry("ERROR: Could not change start type")"3"
		}
		If((Get-Service "wuauserv").StartType-eq"Manual"){
			Add-LogEntry("SUCCESS: wuauserv service start type was set to Manual")
		}
	}Else{
		Add-LogEntry("Wuauserv service startup type is correct")"1"
	}
	Add-LogEntry("---------------------------")"1"
	Add-LogEntry("Checking startup type of Winmgmt service")"1"
	If((Get-Service "Winmgmt").StartType-ne"Automatic"){
		Add-LogEntry("WARNING: Winmgmt service needs to be set to Automatic")"2"
		Add-LogEntry("Attempting to change start type to Automatic")"1"
		Set-Service "Winmgmt" -StartupType "Automatic"
		If((Get-Service "Winmgmt").StartType-ne"Automatic"){
			Add-LogEntry("ERROR: Could not change start type")"3"
		}
		If((Get-Service "Winmgmt").StartType-eq"Automatic"){
			Add-LogEntry("SUCCESS: Winmgmt service startup type set to Automatic")
		}
	}Else{
		Add-LogEntry("Winmgmt service startuptype correctly set")"1"
	}
	Add-LogEntry("Checking status of Winmgmt service")"1"
	If((Get-Service -Name "Winmgmt").status-eq"Stopped"){
		Add-LogEntry("WARNING: Winmgmt service Stopped")"2"
		Add-LogEntry("Attempting to start Winmgmt service")"1"
		Start-Service -Name "Winmgmt"
		start-Sleep -Seconds 10
		If((Get-Service -Name "Winmgmt").status-eq"Stopped"){
			Add-LogEntry("ERROR: Could not start Winmgmt service")"3"
		}
		If((Get-Service -Name "Winmgmt").status-ne"Stopped"){
			Add-LogEntry("SUCCESS: Winmgmt service started")"1"
		}
	}Else{
		Add-LogEntry("Winmgmt service is running")"1"
	}
	Add-LogEntry("---------------------------")"1"
	Add-LogEntry("Checking startup type of RemoteRegistry service")"1"
	If((Get-Service "RemoteRegistry").StartType-ne"Automatic"){
		Add-LogEntry("WARNING: RemoteRegistry service needs to be set to Automatic")"2"
		Add-LogEntry("Attempting to change startup type to Automatic")"1"
		Set-Service "RemoteRegistry" -StartupType "Automatic"
		If((Get-Service "RemoteRegistry").StartType-ne"Automatic"){
			Add-LogEntry("ERROR: Could not change start type")"3"
		}
		If((Get-Service "RemoteRegistry").StartType-eq"Automatic"){
			Add-LogEntry("SUCCESS: RemoteRegistry service start type set to Automatic")
		}
	}Else{
		Add-LogEntry("RemoteRegistry service startup type correctly set")"1"
	}
	Add-LogEntry("Checking status of RemoteRegistry service")"1"
	If((Get-Service -Name "RemoteRegistry").status-eq"Stopped"){
		Add-LogEntry("WARNING: RemoteRegistry service Stopped")"2"
		Add-LogEntry("Attempting to start RemoteRegistry service")"1"
		Start-Service -Name "RemoteRegistry"
		start-Sleep -Seconds 10
		If((Get-Service -Name "RemoteRegistry").status-eq"Stopped"){
			Add-LogEntry("ERROR: Could not start RemoteRegistry service")"3"
		}
		If((Get-Service -Name "RemoteRegistry").status-eq"Running"){
			Add-LogEntry("SUCCESS: started RemoteRegistry service")"1"
		}
	}Else{
		Add-LogEntry("RemoteRegistry service started")"1"
	}
}
# Clears log if its larger then 1MB or older then the specified amount of days # 
Function Get-LogFileSize{Param([Parameter(Mandatory=$True)]$LogFile)
    If(Test-Path -LiteralPath $LogFile){
	    $LogFileSize=(Get-Item -path $LogFile).Length
	    $LogFileAge=(Get-Item -Path $LogFile).CreationTime
	    $AcceptableDate=(Get-Date).AddDays(-"$LogAge")
	    If(($LogFileSize-ge999999)-or($LogFileAge-le$AcceptableDate)){
		    Remove-Item $LogFile -Force
		    $LogCleaned=$true
	    }
    }Else{
        $Messagetype=1
        $LogMessage="Beginning new log file."
        Add-Content $ClientLogFileName "<![LOG[$LogMessage]LOG]!><time=`"$((Get-Date -format HH:mm:ss)+".000+300")`" date=`"$(Get-Date -format MM-dd-yyyy)`" component=`"$ScriptName`" context=`"`" type=`"$Messagetype`" thread=`"`" file=`"powershell.exe`">"  -Errorvariable script:NewLogError
    }
}
# Counts number of items in computer temp folder #
Function Get-TempFiles{
	Add-LogEntry("---------------------------")"1"
	Add-LogEntry("Gathering Temp file count")
	Add-LogEntry("More than 60000 items can be problematic for the SCCM client")
	$TempCount=(Get-ChildItem ($env:SystemRoot+"\temp") -Recurse -Force -Verbose|Measure-Object).Count 
	If($TempCount-ge"60000"){
		Add-LogEntry("WARNING: $TempCount items found")"2"
		Add-LogEntry("Removing temp items")"1"
		Remove-Item ($env:SystemRoot+"\temp\*") -Recurse -Force -Verbose -ErrorAction SilentlyContinue
	}Else{
		Add-LogEntry("$TempCount items found")"1"
		Add-LogEntry("Nothing needs to be removed")
	}
}
# Checks if WMI is working correctly #
Function Get-WMIStatus{
	Add-LogEntry("---------------------------")"1"
	Add-LogEntry("Checking status of WMI")"1"
	If($InstallClient-eq$true){
		Add-LogEntry("SCCM Client set to be reinstalled, will not check SCCM WMI")"1"
		If((Get-WmiObject win32_ComputerSystem)-and(Get-WmiObject win32_OperatingSystem)-and(Get-WmiObject win32_Service)){
            $WMIStatus="Good"
        }
	}
	If($InstallClient-ne$true){
		If((Get-WmiObject win32_ComputerSystem)-and(Get-WmiObject win32_OperatingSystem)-and(Get-WmiObject win32_Service)-and(Get-WmiObject -Namespace root\ccm -Class sms_client)){
            $WMIStatus="Good"
        }
	}
	If($WMIStatus-eq"Good"){
		Add-LogEntry("WMI Seems to be working correctly")"1"
	}Else{
		Add-LogEntry("WARNING: One or more WMI classes are corrupted")"2"
		If($InstallClient-ne$true){
            Add-LogEntry("WARNING: SCCM Client will need to be reinstalled")"2"
        }
		Add-LogEntry("Attempting to repair WMI")"1"
		$DependentServices=Get-Service winmgmt -DependentServices|Where-Object Status -eq "Running"
		If((Get-Service CcmExec).Status-eq"Running"){
			Add-LogEntry("Attempting to stop CcmExec service")"1"
			Stop-Service "CcmExec" -Force -ErrorAction SilentlyContinue
			Start-Sleep -Seconds 10
			If((Get-Service CcmExec).Status-eq"Running"){
				Add-LogEntry("ERROR: Could not stop CcmExec service")"3"
				Add-LogEntry("It is not recommened to continue with WMI repair proccess, Stopping Script")"2"
				Exit-Script
			}
		}
		If((Get-Service Winmgmt).Status-eq"Running"){
			Add-LogEntry("Attempting to stop winmgmt service")"1"
			Stop-Service "winmgmt" -Force -ErrorAction SilentlyContinue
			Start-Sleep -Seconds 10
			If((Get-Service Winmgmt).Status-eq"Running"){
				Add-LogEntry("ERROR: Could not stop winmgmt service")"3"
				Add-LogEntry("It is not recommened to continue with WMI repair proccess, Stopping Script")"2"
				Exit-Script
			}
		}
		If((Get-Service wmiApSrv).Status-eq"Running"){
			Add-LogEntry("Attempting to stop wmiApSrv service")"1"
			Stop-Service "wmiApSrv" -Force -ErrorAction SilentlyContinue
			Start-Sleep -Seconds 10
			If((Get-Service wmiApSrv).Status-eq"Running"){
				Add-LogEntry("ERROR: Could not stop wmiApSrv service")"3"
				Add-LogEntry("It is not recommened to continue with WMI repair proccess, Stopping Script")"2"
				Exit-Script
			}
		}
		ForEach($Service In $DependentServices){
			If((Get-Service $Service).Status-eq"Running"){
				Add-LogEntry("Attempting to stop $Service service")"1"
				Stop-Service "$Service" -Force -ErrorAction
				Start-Sleep 10
				If((Get-Service $Service).Status-eq"Running"){
					Add-LogEntry("ERROR: Could not stop $Service service")"3"
					Add-LogEntry("It is not recommened to continue with WMI repair proccess, Stopping Script")"2"
					Exit-Script
				}
			}
		}
		Add-LogEntry("All Services stopped, Repairing WMI")"1"
		& ($ENV:SystemRoot+"\system32\wbem\winmgmt.exe") /resetrepository
		& ($ENV:SystemRoot+"\system32\wbem\winmgmt.exe") /salvagerepository
		Add-LogEntry("Completed running the repaire process")"1"
		Add-LogEntry("Attempting to restart services needed for WMI")"1"
		Add-LogEntry("Attempting to restart Winmgmt service")"1"
		Start-Service "Winmgmt"
		Start-Sleep -Seconds 5
		If((Get-Service Winmgmt).Status-eq"Stopped"){
			Add-LogEntry("ERROR: Could not restart winmgmt service")"3"
			Add-LogEntry("Attempting to restart winmgmt service in 10 seconds")"1"
			Start-Sleep -Seconds 10 
			Start-Service "Winmgmt"
			If((Get-Service Winmgmt).Status-eq"Running"){
                Add-LogEntry("SUCCESS: Winmgmt service is now running")"1"
            } 
		}Else{
			Add-LogEntry("SUCCESS: Winmgmt service is now running")"1"
		}
		Add-LogEntry("Attempting to restart wmiApSrv service")"1"
		Start-Service "wmiApSrv" 
		Start-Sleep -Seconds 5
		If((Get-Service wmiApSrv).Status-eq"Stopped"){
			Add-LogEntry("ERROR: Could not restart wmiapSrv service")"3"
			Add-LogEntry("Attempting to restart wimApSrv service in 10 seconds")"1"
			Start-Sleep -Seconds 10
			Start-Service "wmiApSrv"
			If((Get-Service wmiApSrv).Status-eq"Running"){
                Add-LogEntry("SUCCESS: wmiApSrv service is now running")"1"}
		}Else{
			Add-LogEntry("SUCCESS: wmiApSrv service is now running")"1"
		}
		Add-LogEntry("Attempting to restart WmiPrvSE service")"1"
		Start-Service "WmiPrvSE"
		Start-Sleep -Seconds 5
		If((Get-Service WmiPrvSE).Status-eq"Stopped"){
			Add-LogEntry("ERROR: Could not restart WmiPrvSE service")"3"
			Add-LogEntry("Attempting to restart WmiPrvSE service in 10 seconds")"1"
			Start-Sleep -Seconds 10
			Start-Service "WmiPrvSE"
			If((Get-Service WmiPrvSE).Status-eq"Running"){
                Add-LogEntry("SUCCESS: WmiPrvSE service is now running")"1"}
		}Else{
			Add-LogEntry("SUCCESS: WmiPrvSE service is now running")"1"
		}
		ForEach($Service In $DependentServices){
			Add-LogEntry("Attempting to restart $Service service")"1"
			Start-Service $Service
			Start-Sleep -Seconds 5 
			If((Get-Service "$Service").Status-eq"Stopped"){
				Add-LogEntry("ERROR: Could not restart $Service")"3"
				Add-LogEntry("Attempting to restart $Service service in 10 seconds")
				Start-Sleep -Seconds 10
				Start-Service $Service
				If((Get-Service "$Service").Status-eq"Running"){
                    Add-LogEntry("SUCCESS: $Service service is now running")"1"
                }
			}Else{
				Add-LogEntry("SUCCESS: $Service service is now running")"1"
			}
		}
		$InstallClient=$true
		If((Get-WmiObject win32_ComputerSystem)-and(Get-WmiObject win32_OperatingSystem)-and(Get-WmiObject win32_Service)){
			Add-LogEntry("SUCCESS: Standard WMI has been repaired")"1"
			Add-LogEntry("Will Check SCCM WMI after client install")"1"
			Add-LogEntry("Reinstalling the SCCM Client to repair the SCCM part of WMI")"1"
			$CheckWMI=$true
		}Else{
			Add-LogEntry("ERROR: Standard WMI was not repaired")"3"
			Add-LogEntry("Will chack SCCM WMI after client install however further action may be needed to further repaire this device")
			Add-LogEntry("Reinstalling the SCCM Client to repair the SCCM part of WMI")"1"
			$CheckWMI=$true
		}
	}
}
# Installs SCCM Client #
Function Install-SCCMClient{Param([Parameter(Mandatory=$True)]$HostName,[Parameter(Mandatory=$True)]$Credentials)
    $RemoteTemp=("\\"+$HostName+"\Admin$\Temp")
	Add-LogEntry("---------------------------")"1"
	Add-LogEntry("Opening a 'New-PSSession' on '"+$HostName+"'.")"1"
    $UnInstallClient=@"
@Echo Off
Type "Beginning script to uninstall the SCCM Client." > C:\Windows\Temp\SCCMClient.log
Echo: Uninstalling the old SCCM client ... Please Wait!
%1\ccmsetup.exe /Uninstall
Type "Monitoring the progress of the uninstall process." > C:\Windows\Temp\SCCMClient.log
:Start
Type "Still processing uninstall..." > C:\Windows\Temp\SCCMClient.log
Tasklist /FI "ImageName eq ccmsetup.exe" | Find /i "ccmsetup.exe" >> null
IF ERRORLEVEL 2 Goto Running
IF ERRORLEVEL 1 Goto End
:Running
Goto Start
:end
Type "Completed the uninstall process." > C:\Windows\Temp\SCCMClient.log
Echo: Uninstall of the old SCCM client is complete.
Exit
"@
    Add-Content $RemoteTemp\UnInstallClient.bat $UnInstallClient
    $RemoteScript=($env:SystemRoot+"\Temp\UnInstallClient.bat")
    If(Test-Connection -ComputerName $HostName -Quiet){
        Try{
            Invoke-Command -ComputerName $HostName -Credential $SecureCredentials -FilePath $RemoteScript -ArgumentList $SCCMClientLocation
        }Catch{
        }
    }
    Remove-Item ($RemoteTemp+"\UnInstallClient.bat")


	If($InstallClient-eq$true){
		If(Test-path -Path $CCMPath){
			Add-LogEntry("SCCM client install files found")"1"
			Add-LogEntry("Removing old client install files")"1"
			Remove-Item -Path C:\Windows\ccmsetup -Recurse -Force -Verbose
			Start-Sleep -Seconds 10
			If(Test-Path -Path C:\Windows\ccmsetup){
                Add-LogEntry("WARNING: Could not remove ccmsetup folder")"2"
            }
			Add-LogEntry("Running SCCM Client uninstall")"1"
			Add-Content $Env:TEMP\UninstallClient.bat $UninstallClient
			Invoke-Expression "$Env:TEMP\UninstallClient.bat $SCCMClientLocation"
			Remove-Item "$Env:TEMP\UninstallClient.bat"
			If(Get-WmiObject win32_Product | Where-Object Name -EQ "Configuration Manager Client"){
				Add-LogEntry("ERROR: Could not uninstall SCCM Client")"3"
			}
			If(!(Get-WmiObject win32_Product | Where-Object Name -EQ "Configuration Manager Client")){
				Add-LogEntry("SCCM Client successfully uninstalled")"1"
			}
			Add-LogEntry("Remove leftover client files")
			Start-Sleep -Seconds 60
			Remove-Item C:\Windows\ccmcache -Recurse -Force -Verbose
			Start-Sleep -Seconds 10
			If(Test-Path -Path C:\Windows\ccmcache){
                Add-LogEntry("Could not remove ccmcache folder")"2"
            }
			Remove-Item $CCMPath -Recurse -Force -Verbose
			Start-Sleep -Seconds 10
			If(Test-Path -Path $CCMPath){
                Add-LogEntry("Could not remove CCM folder")"2"
            }
		}
		Add-LogEntry("Running SCCM Client Install")"1"
		If(!(Test-Path $SCCMClientLocation)){
			Add-LogEntry("ERROR: Cannont find $SCCMClientLocation")"3"
			Exit-Script
		}
		$InstallClientScript=@"
            @ECHO off
            ECHO Installing the new client...Please Wait
            %1\ccmsetup.exe SMSMP=it-cmmp.city.thornton.local DNSSUFFIX=city.thornton.local SMSSITECODE=CT1 CCMLOGLEVEL=0 CCMLOGMAXSIZE=16000000 CCMLOGMAXHISTORY=1 CCMDEBUGLOGGING=0 SMSCACHSIZE=25600
		
            :start
            tasklist /FI "IMAGENAME eq ccmsetup.exe" | find /i "ccmsetup.exe" >> null
		 
            IF ERRORLEVEL 2 GOTO running
            IF ERRORLEVEL 1 GOTO end
		
            :running
            goto start
		
            :end
            ECHO Install Complete
            exit cmd.exe
"@
		Add-Content $Env:TEMP\InstallClient.bat $InstallClientScript
		Invoke-Expression "$Env:TEMP\InstallClient.bat $SCCMClientLocation"
		Remove-Item "$Env:TEMP\InstallClient.bat"
		If(!(Get-WmiObject win32_Product | Where-Object Name -EQ "Configuration Manager Client")){
			Add-LogEntry("ERROR: Could not install SCCM Client")"3"
		}
		If(Get-WmiObject win32_Product | Where-Object Name -EQ "Configuration Manager Client"){
			Add-LogEntry("SCCM Client successfully installed")"1"
			Add-LogEntry("Running Machine Policy Cycle")
			$SMSClient=[wmiclass]"\\$env:COMPUTERNAME\root\ccm:SMS_Client"
			$SMSClient.TriggerSchedule("{00000000-0000-0000-0000-000000000021}")
			$InstallClient=$false
		}
		If($CheckWMI-eq$true){
			If(Get-WmiObject -Namespace root\ccm -Class sms_client){
				Add-LogEntry("SUCCESS: SCCM WMI was repaired")"1"
			}Else{
				Add-LogEntry("ERROR: SCCM WMI was not repaired")"3"
			}
		}
	}
	Else{
		Add-LogEntry("No issues where found that required the client to be reinstalled")"1"
	}
}
# Creates a new log file for the script #
Function New-LogFile{Param([Parameter(Mandatory=$True)]$LogFile)
    $LogFilePaths="$LogFile"
    ForEach($LogFilePath In $LogFilePaths){
        $NewLogError=$null
        $ConfigMgrLogFile=$LogFilePath
		Add-LogEntry("********************************************************************************************************************")"1"
		Add-LogEntry("Starting SCCM Client Health Check")"1"
		If($LogCleaned-eq$true){
            Add-LogEntry("Log was cleaned due to being too large or older then "+$LogAge+" Days")
        }
        If(-Not($NewLogError)){Break}
    }
    If($NewLogError){
        $ReturnCode=1
        Exit $ReturnCode
    }
}

Switch($DomainUser){
    {($_-like"sy10*")-or($_-like"sy60*")}{Break}
    Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
}
$SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain ($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=Get-Credential}
$ClearLogs=@($LogFile,$NotRunningFile,$NotInstalledFile,$OfflineFile,$SystemListFile)
If(!(Test-Path -LiteralPath $LogFolderPath)){
    New-Item -Path $LogFolderPath -ItemType Directory
}
ForEach($CurrentLog In $ClearLogs){
    If(Test-Path -Path $CurrentLog){
        Remove-Item $CurrentLog
    }
    If($CurrentLog-ne$SystemListFile){
        ("Beginning new log file for '"+$CurrentLog+"'.")|Out-File $CurrentLog
        Get-Date -Format "dddd MM/dd/yyyy HH:mm K"|Out-File $CurrentLog -Append
        If($CurrentLog-ne$LogFile){
            $Header="Computer Name"
            $Line=("_"*$Header.Length)
            ("`r`t"+$Header)|Out-File $CurrentLog -Append
            ("`t"+$Line)|Out-File $CurrentLog -Append
        }
    }
}
Get-ADComputer -Filter 'OperatingSystem -like "*windows*"' -Properties IPv4Address|FT Name,DNSHostName,IPv4Address -A|Out-File $SystemListFile
If(Test-Path -LiteralPath $SystemListFile){
    $SystemCount=0
    $SystemList=@()
    ForEach($CurrentLineValue In Get-Content -Path $SystemListFile){
        If($CurrentLineValue-like"* 10.*"){
            $InstallClient=$false
            $HostName=($CurrentLineValue -Split(" 10."))[0].Trim()
            $NetBIOS=($HostName -Split(" "))[0].Trim()
            $HostName=($HostName.Replace($NetBIOS+" ","")).Trim()
            $IPv4Address=($CurrentLineValue -Split(" 10."))[1].Trim()
            If($IPv4Address-ne""){
                $SystemCount+=1
                $System=New-Object PSObject
                $IPv4Address=("10."+$IPv4Address)
                Switch($CurrentLineValue){
                    {$_-like"*10.126.*"}{
                        $SiteServer="w19sccmmpb01"
                        $SiteCode=$MPB
                        Break
                    }
                    Default{
                        $SiteServer="w19sccmmpa01"
                        $SiteCode=$MPA
                        Break
                    }
                }
                $System|Add-Member -MemberType NoteProperty -Name 'SiteCode' -Value $SiteCode
                $System|Add-Member -MemberType NoteProperty -Name 'NetBIOS' -Value $NetBIOS
                $System|Add-Member -MemberType NoteProperty -Name 'HostName' -Value $HostName
                $System|Add-Member -MemberType NoteProperty -Name 'IPv4Address' -Value $IPv4Address
                $SystemList+=$System
                $SCCMClientLocation=("\\"+$SiteServer+".inf."+($env:USERDNSDOMAIN).ToLower()+"\SMS_"+$SiteCode+"\Client")
                $ClientLogFilePath=($LogFolderPath+"\"+$SiteCode+"\"+$NetBIOS)
                If(!(Test-Path -LiteralPath $ClientLogFilePath)){
                    New-Item $ClientLogFilePath -ItemType Directory
                }
                $ClientLogFileName=($ClientLogFilePath+"\SCCMClientHealthCheck.log")
                $ClientVersion=(Get-ClientInstalled -HostName $HostName -Credentials $SecureCredentials)-Split(";")[0]
                If(($ClientVersion[0]-ne$CurrentVersion)-or($InstallClient-eq$true)){
                    Install-SCCMClient -HostName $HostName -Credentials $SecureCredentials
                }Else{
                    Add-LogEntry("The SCCM Client version installed is: "+$ClientVersion[0])"1"
                    Add-LogEntry("and the state of CCMExec.exe on the system is: "+$ClientVersion[1])"1"
                }
            }
        }
    }
}
Set-Location $System32