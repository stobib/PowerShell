# The default script execution is set to Form Based Interactive option $AMIAutomation = $false, the same script is executed in the Ami Automation framework set to $true
Param (
    $AMIAutomation = $false
)

$ScriptVersion = "2.1.1"
# placeholder for index of the failed functions $failedIndexList. The -fix parameter will call only functions that were marked/indexed as failed
$global:failedIndexList = @()
$global:PASSED = "PASSED"
$global:WARNING = "WARNING"
$global:FAILED = "FAILED"
$global:ImageInfo = @{}
$global:FreeSpaceMinimumGB = 10
$global:MinRearmCount = 1
$global:MaxDriveSize = 70
$global:MinPSVersion = 4
$global:SuccessLabel = "[SUCCESS]"
$global:FailureLabel = "[FAIL]"
$global:FailureText = "Unable to resolve the issue, please click on the info button for more detailed information"
$global:SupportedOS = @("6.1.7601", "10.0.10586", "10.0.14393", "10.0.15063", "10.0.16299", "10.0.17134", "10.0.17763","10.0.18362")

# Placeholder for Functions/Tests Exemptions that will be excluded from the execution
$WIN7ExemptedFunctions = @("Test-BYOL_AzureDomainJoined")
$WIN10ExemptedFunctions = @()
$AutomationExemptFunctions = @("Test-BYOL_DriveLessThan80GB")

# placeholder for script variables
$CurrentWorkingDirectory = $PSScriptRoot
$fileTimestamp = get-Date -f yyyy'-'MM'-'dd'_'hhmmss
$LogFileName = "BYOLPrevalidationlog" + $fileTimeStamp
$Logfile = "$currentWorkingDirectory\$LogFileName.txt"
$Infofile = "$currentWorkingDirectory\ImageInfo.txt"
$scriptName = $($MyInvocation.MyCommand.Name)
$global:OOBEfile = "$PSScriptRoot\OOBE_unattend.xml"
$appName = $scriptName # is used in IMS
$global:sysprepTimeRun = 300 # run time sysprep
[PsCustomObject]$global:FunctionList = @()

# Get all functions that start with "Test-BYOL_*" . This function will dynamically create a list of functions that will be executed to validate the BYOL.
function Get-BYOLFunctions {
    $allFunctions = Get-ChildItem function:\
    $global:BYOLFunctions = $allFunctions | Where-Object Name -like "Test-BYOL_*" | Select-Object Name
    return $global:BYOLFunctions
}
function Test-BYOL_PowershellVersion {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)
                TextLabel   = "PowerShell version installed is 4.0 or higher"
                FailureText = "Upgrade to PowerShell version 4.0 or higher."
            }
            $global:FunctionList += $obj
        }
        true {
            $log1 = $PSVersionTable.PSVersion.Major
            Write-LogFile "Powershell version is $log1"
            if ($PSVersionTable.psversion.major -ge $global:MinPSVersion) {
                Write-LogFile " $global:SuccessLabel PowerShell Version is greater than $global:MinPSVersion "
                return $global:PASSED
            }
            else {
                Write-LogFile " $global:FailureLabel PowerShell Version is less than $global:MinPSVersion"
                return $global:FAILED
            }
        
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_PCoIP_Check {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "PCoIP Agent is not installed"
                FailureText = "PCoIP Agent is installed. Uninstall PCoIP Agent. "
            }
            $global:FunctionList += $obj
            $global:PCoIP_del_try = $false
        }
        true {
            # Tipacally all three Checks must be false to properly install new PCoIP Agent
            $global:PCoIP_uninstaller = "C:\Program Files (x86)\Teradici\PCoIP Agent\uninst.exe"
            $Check1 = Test-Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\PCoIP*"
            $Check2 = Test-Path $PCoIP_uninstaller
            $Check3 = Get-Service | Where-Object {$_.Name -eq "PCoIPAgent"}
            if (!($Check1) -and !($Check2) -and !($Check3)) {
                # All Checks are false, no PCoIP agent artifacts
                Write-LogFile "$global:SuccessLabel PCoIP agent is not present"
                return $global:PASSED
            }
            elseif (!($global:PCoIP_del_try) -and !($Check2)) {
                # If uninst.exe is missing it will mark as Failed at first run, because we cannot uninstall the agent
                Write-LogFile " $global:FailureLabel PCoIP uninstaller failed"
                return $global:FAILED
            
            }
            elseif ($Check1 -or $Check2 -or $Check3 -or !($global:PCoIP_del_try)) {
                # If any of the Checks fail, than the PCoIP was present and an uninstall can be initiated
                Write-LogFile " $global:FailureLabel Detected PCoIP Agent installed"
                return $global:WARNING
            }
            else {
                Write-LogFile " $global:FailureLabel Unexpected PCoIP check failure"
                return $global:FAILED
            }
        }
        fix {
            $global:OutputBox.AppendText("Uninstalling PCoIP Agent. It can take several minutes. Please wait ...")
            $ExitCode = (Start-Process -FilePath $global:PCoIP_uninstaller -ArgumentList "/S /NoPostReboot '_?=C:\Program Files (x86)\Teradici\PCoIP Agent'" -Wait -PassThru).ExitCode
            if ($ExitCode -eq 0) {
                $global:OutputBox.AppendText("`nPCoIP Agent has been uninstalled successfullly")
                Write-LogFile "$global:SuccessLabel PCoIP Agent has been uninstalled successfullly"
            }
            else {
                $global:OutputBox.AppendText("`nFailed to uninstall PCoIP Agent with ExitCode: $ExitCode")
                Write-LogFile "$global:FailureLabel Failed to uninstall PCoIP Agent with ExitCode: $ExitCode"
                $global:PCoIP_del_try = $true
                $global:OutputBox.AppendText("$global:FailureText `nFailed to auto uninstall PCoIP Agent. Try uninstalling it manually.")
            }
        }
    }
}
function Test-BYOL_Disable_Updates {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "Windows updates is disabled"
                FailureText = "Windows updates is enabled. Disable Windows updates and try again."
            }
            $global:FunctionList += $obj
        }  
        true {
            # Desired Service Name and its StartType Mode
            $global:GoodService = @(
                [PsCustomObject]@{
                    Name      = "wuauserv"
                    StartMode = "Disabled"
                }
                ,
                [PsCustomObject]@{
                    Name      = "TrustedInstaller"
                    StartMode = "Manual"
                }
            )

            $ServiceStateList = @()
            foreach ($svc in $global:GoodService) {
                $ServiceState = Get-WmiObject -ClassName Win32_Service | Where-Object Name -eq $svc.Name | Select-Object Name, StartMode
                $ServiceStateList = $ServiceStateList + $ServiceState
            }
            $global:BadService = @()
            $global:BadService = Compare-Object $global:GoodService $ServiceStatelist -Property StartMode, Name | Select-Object Name -Unique -ExpandProperty Name
            if ($global:BadService -eq $null) {
                Write-LogFile "$global:SuccessLabel Update service status has passed the check"
                return $global:PASSED
            }
            else {
                Write-LogFile "$global:FailureLabel Update service status failed. Service(s): $global:BadService did not meet the startup criteria."
                return $global:WARNING
            }
        }
        fix {
            foreach ($service in $global:BadService) {
                try {
                    # Stopping the process, if it is running, before disabling it
                    $ServicePID = (get-wmiobject win32_service | Where-Object { $_.name -eq $service}).processID
                    if ($ServicePID -ne 0) {
                        Write-LogFile "$global:FailureLabel $service processID is $ServicePID. Stopping the service"
                        taskkill /pid $ServicePID /f /t
                    }
                    else {
                        Write-LogFile "$global:SuccessLabel $service processID is 0 (null)" 
                    }
                    # Disabling the service
                    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $service -StartupType ($global:GoodService | Where-Object {$_.Name -eq $service}).StartMode
                }
                catch {
                    $global:OutputBox.AppendText("$global:FailureText `nFailed to Auto disable Windows Updates. Please try to manualy disable Windows Updates.")
                }
            }
        }
    }
}
function Test-BYOL_AutoMount {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "Automount is enabled"
                FailureText = "Automount is disabled. Enable Automount."
            }
            $global:FunctionList += $obj
        }  
        true {
            $RegKey = "HKLM:\SYSTEM\CurrentControlSet\services\mountmgr"

        if ((Get-ItemProperty $RegKey).NoAutoMount -eq 1) {
            Write-LogFile " $global:FailureLabel Automount is Disabled."
            return $global:WARNING
        }
        else {
            Write-LogFile " $global:SuccessLabel Automount is Enabled"
            return $global:PASSED
}
        }
        fix {
            "automount enable" | diskpart
        }  
    }
}
function Test-BYOL_Workspaces_BYOLAccountExist {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "WorkSpaces_BYOL account exists"
                FailureText = "WorkSpaces_BYOL account not found in the SAM database. Create an account with this username and add it to local administrators group."
            }
            $global:FunctionList += $obj
        }  
        true {
            if (Get-WMIObject Win32_UserAccount -Filter "LocalAccount='true' and Name='WorkSpaces_BYOL'") {
            
                Write-LogFile " Workspaces_BYOL Exists"
                Write-LogFile "$global:SuccessLabel Workspaces_BYOL Account Exists"
                Return $global:PASSED
            }
            else {
                Write-LogFile " $global:FailureLabel Workspaces_BYOL Account Does Not Exist"
                Return $global:WARNING
            }
        }
        fix {
            New-WorkSpaces_BYOL_User
        }
    }
}
function Test-BYOL_Workspaces_BYOLAccountDisabled {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "WorkSpaces_BYOL account is enabled"
                FailureText = "WorkSpaces_BYOL account is disabled. Please enable it."
            }
            $global:FunctionList += $obj
        }
        true {
            $script:workspaces_BYOLAccount = Get-WmiObject -Class Win32_UserAccount -Filter  "LocalAccount='True'" | Where-Object {$_.Name -eq "WorkSpaces_BYOL"}
            $log14 = $workspaces_BYOLAccount.Disabled
            Write-LogFile "WorkSpaces_BYOL Disabled/Enabled status - $log14 (Status will be blank if this test is run on domain controller)"
            $ImageInfo["WorkSpaces_BYOLAccount.Disabled"] = $log14
            if ($workspaces_BYOLAccount.Disabled -eq $false) {
                Write-LogFile "$global:SuccessLabel WorkSpaces_BYOL Account Enabled"
                Return $global:PASSED
            }
            else {
                Write-LogFile " $global:FailureLabel WorkSpaces_BYOL Account Disabled"
                Return $global:WARNING
            }
        }
        fix {
            net user Workspaces_BYOL /active:yes
        }
    }
}
function Test-BYOL_DHCPEnabledInterface {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "DHCP is enabled on network interface"
                FailureText = "Network interface is currently using a static IP address. Change network interface to use DHCP."
            }
            $global:FunctionList += $obj
        }
        true {
            $script:networkAdapters = Get-WmiObject -Class win32_networkadapterconfiguration -filter 'ipenabled = "true"'
            $log = $networkAdapters.DHCPEnabled
            Write-LogFile "Network Adapter using DHCP logs - $log"
            $ImageInfo["NetworkAdapterUsingDHCP"] = $log
            #should not have 2 network adapters but we want to treat this test separate and consider multiple network interfaces but will succeed if true on all interfaces.
            if ($log -eq $False) {
                Write-LogFile " $global:FailureLabel DHCP disabled on network interface"
                return $global:FAILED
            }
            else {
                Write-LogFile "$global:SuccessLabel DHCP enabled on network interface"
                return $global:PASSED
            }
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_FreeDiskSpace {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "More than 10GB of free space on C: drive"
                FailureText = "C: drive has less than 10GB of free space. Clean up C: drive to free up some space"
            }
            $global:FunctionList += $obj
        }
        true {
            $script:disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object FreeSpace
            $log8 = ($disk.freespace / 1GB)
            Write-LogFile " Amount of free space on C: drive - $log8 GB"
            $ImageInfo["FreeSpaceOnCDrive"] = $log8
            if ($log8 -lt $global:FreeSpaceMinimumGB ) {
                Write-LogFile "$global:FailureLabel Free disk space is less than minimum required $global:FreeSpaceMinimumGB"
                return $global:FAILED
            }
            else {
                Write-LogFile "$global:SuccessLabel Free disk space is greater than minimum required $global:FreeSpaceMinimumGB"
                return $global:PASSED
            }
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_LocalDrives {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "Only local disks are attached"
                FailureText = "Removable or network drives attached. Remove all removable, network, and CD/ISO drives."
            }
            $global:FunctionList += $obj
        }
        true {
            $script:drives = @(Get-WmiObject -class win32_logicaldisk | Select-Object DeviceID, DriveType)
            $log9 = $drives | Out-String
            Write-LogFile " Attached Drives types:"
            Write-LogFile "$log9"
            if ($drives.Count -eq "1" -and $drives.DriveType -eq "3") {
                # Only one drive should be attached and it has to be Local Drive
                Write-LogFile "$global:SuccessLabel Drives of the correct type attached."
                return $global:PASSED
            }
            else {
                Write-LogFile " $global:FailureLabel Wrong type of drives attached."
                return $global:FAILED
            }
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_OSRequirements {
    # Reference for version https://en.wikipedia.org/wiki/Ver_%28command%29
    # Reference for edition numbers https://techontip.wordpress.com/tag/operatingsystemsku/
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "Supported Windows operating system"
                FailureText = "Operating System is not supported. Try again with image running supported OS."
            }
            $global:FunctionList += $obj
        }
        true {
            $OSinfo = get-wmiobject -class win32_operatingsystem
            [int]$OSType = $OSinfo.ProductType # 1 is for Workstation
            [String]$OSVersion = $OSinfo.Version
            # Only Worstations and WIN7, WIN10 can be used for BYOL
            if ($osType -eq 1 -and ($OSVersion -in $global:SupportedOS)) {
                Write-LogFile "$global:SuccessLabel OS type $osType is Desktop type and OS Version is $OSVersion"
                return $global:PASSED
            }
            else {
                Write-LogFile " $global:FailureLabel OS type $osType is NOT Desktop type and OS Version is $OSVersion"
                return $global:FAILED
            }
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_DomainJoined {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "System is not AD domain joined"
                FailureText = "System is domain joined. Unjoin from AD domain and try again."
            }
            $global:FunctionList += $obj
        }
        true {
            $script:partofDomain = (Get-WmiObject -Class win32_computersystem).partofdomain
            Write-LogFile "Computer part of domain - $script:partofDomain"
            $ImageInfo["partOfDomain"] = $script:partofDomain
            if ( $script:partofDomain -eq $true ) {
                Write-LogFile " $global:FailureLabel System is domain joined. Please detach the system from the domain."
                return $global:FAILED
            }
            else {
                Write-LogFile "$global:SuccessLabel System is not domain joined."
                return $global:PASSED
            }
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_AzureDomainJoined {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "System is Azure domain joined"
                FailureText = "System is Azure domain joined. Unjoin from Azure domain and try again."
            }
            $global:FunctionList += $obj
        }
        true {
            $DomainInfo = Invoke-Expression "dsregcmd /status"
            if ($DomainInfo -match "AzureAdJoined : YES") {
                " $global:FailureLabel System is AzureAdJoined joined. Please detach the system from the domain."
                return $global:FAILED
            }
            else {
                Write-LogFile "$global:SuccessLabel System is not domain joined."
                return $global:PASSED
            }
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_Firewall {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "Windows Firewall is disabled"
                FailureText = "Windows Firewall is enabled. Turn off public firewall profile and try again."
            }
            $global:FunctionList += $obj
        }
        true {
            $location = "Registry::HKLM\SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy"
            $publicFirewall = Get-ItemProperty -path $location\PublicProfile -ErrorAction SilentlyContinue
            $ImageInfo["Firewall"] = @{}
            $ImageInfo["Firewall"]["Type"] = "Public"
                
            if ($publicFirewall.enablefirewall -eq 1) {
                Write-LogFile " $global:FailureLabel Public Firewall Profile is turned ON"
                $ImageInfo["Firewall"]["TurnedOn"] = $TRUE
                return $global:WARNING
            }
            else {
                Write-LogFile "$global:SuccessLabel Public Firewall Profile is turned OFF"
                $ImageInfo["Firewall"]["TurnedOn"] = $FALSE
                return $global:PASSED
            }
        }
        fix {
            netsh advfirewall set publicprofile state off
        }
    }
}
function Test-BYOL_VMWareTools {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "VMWare tools not installed"
                FailureText = "VMWare tools are currently installed. Uninstall VMWare tools and try again."
            }
            $global:FunctionList += $obj
        }
        true {
            $path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            $installedApps = Get-ItemProperty $path | Select-Object DisplayName
            foreach ($app in $installedApps) {
                $ImageInfo["VMWareToolsInstalled"] = $app.displayname
                if ($app.displayname -eq "VMWare Tools") {
                    Write-LogFile " $global:FailureLabel VMware Tools is installed? - $VMWareToolsInstalled"
                    return $global:FAILED
                }
                else {
                    Write-LogFile "=$global:SuccessLabel> VMware Tools is installed? - $VMWareToolsInstalled"
                }
            }
            return $global:PASSED 
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_DriveLessThan80GB {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "Attached C: disk smaller than $MaxDriveSize GB"
                FailureText = "Attached C: disk is larger than $MaxDriveSize GB. Make them smaller than $MaxDriveSize GB and try again."
            }
            $global:FunctionList += $obj
        }
        true {
            $drive = Get-WmiObject -Class win32_logicaldisk -Filter "DeviceID='C:'" 
            $ImageInfo["Drives"] = $drive
            if (($drive.size / 1GB) -gt $global:MaxDriveSize) {
                Write-LogFile " $global:FailureLabel Attached drive size is greater than $global:MaxDriveSize"
                return $global:FAILED
            }
            else {
                Write-LogFile "$global:SuccessLabel Attached drive size is less than $global:MaxDriveSize"
                return $global:PASSED
            }
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_GPTPartitions {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "MBR partitioned volumes"
                FailureText = "Volumes are not MBR partitioned. Make all volumes MBR partitioned and try again."
            }
            $global:FunctionList += $obj
        }
        true {
            $script:partitions = Get-WmiObject -Class win32_diskpartition
            $ImageInfo["Partitions"] = $partitions
            $convertedPartitions = $partitions | Out-String
            $convertedPartitionTypes = $partitions.type | Out-String
            Write-LogFile "List of Partitions - "
            Write-LogFile "$convertedPartitions"
            Write-LogFile "(in respective order to above partition list)"
            Write-LogFile "$convertedPartitionTypes"
            foreach ($partition in $partitions) {   
                if ($partition.type.startswith("GPT")) {
                    Write-LogFile " $global:FailureLabel There is a GPT (GUID Partition Table) Partition on your disk "
                    return $global:FAILED
                }   
                else {
                    Write-LogFile "$global:SuccessLabel $($partitions.Name) is no GPT (GUID Partition Table) Partition on your disk "
                }
            }
            return $global:PASSED
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_PendingReboots {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "No pending system reboot"
                FailureText = "System is pending reboot. Complete system reboot and try again."
            }
            $global:FunctionList += $obj
        }
        true {
            $RebootRequired = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
            $RebootPending = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
            if ((test-path $RebootRequired -ErrorAction SilentlyContinue) -or (test-path $RebootPending -ErrorAction SilentlyContinue)) {
                Write-LogFile " $global:FailureLabel There are pending updates. All updates need to be installed before the Image can be converted to BYOL AMI"
                return $global:FAILED
            }
            else {
                Write-LogFile "$global:SuccessLabel No pending reboots detected."
                return $global:PASSED
            }
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_AutoLogon {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "AutoLogon is disabled"
                FailureText = "AutoLogon is enabled. Disable AutoLogon in registry and try again."
            }
            $global:FunctionList += $obj
        }
        true {
            $path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
            $result = Get-ItemProperty -path $path
            if ($result.AutoAdminLogon -eq 1) {
                Write-LogFile " $global:FailureLabel AutoLogon turned on? - True"
                $ImageInfo["AutoLogonTurnedOn"] = $TRUE
                return $global:WARNING
            }
            else {
                Write-LogFile "$global:SuccessLabel AutoLogon turned on? - False"
                $ImageInfo["AutoLogonTurnedOn"] = $FALSE
                return $global:PASSED
            }
        }
        fix {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon -Value "0"
        }
    }
}
function Test-BYOL_RealTimeUniversal {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "RealTimeISUniversal registry key is enabled"
                FailureText = "RealTimeIsUniversal registry key is disabled. Enable this setting and try again. `nSee: `nhttp://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/windows-set-time.html"
            }
            $global:FunctionList += $obj
        }
        true {
            $path = 'HKLM:\System\CurrentControlSet\Control\TimeZoneInformation'
            $result = Get-ItemProperty -path $path
            if ($result.RealTimeIsUniversal) {
                Write-LogFile "$global:SuccessLabel RealTimeIsUniversal reg key installed - True"
                $ImageInfo["RealTimeIsUniversal"] = $TRUE
                return $global:PASSED
            }
            else {
                Write-LogFile " $global:FailureLabel RealTimeIsUniversal reg key installed - False"
                $ImageInfo["RealTimeIsUniversal"] = $FALSE
                return $global:WARNING
            }
        }
        fix {
            reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f
        }
    }
}
function Test-BYOL_MultipleBootPartition {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "Single bootable partition"
                FailureText = "System has multiple bootable partitions. Decrease the number of bootable partitions to one and try again."
            }
            $global:FunctionList += $obj
        }
        true {
            $partitions = Get-WmiObject -class win32_diskpartition
            $numberofBootable = ($partitions | Group-Object Bootable) | Where-Object {$_.Name -eq "True"} | Select-Object -ExpandProperty Count
            if ($numberofBootable -gt 1) {
                Write-LogFile " $global:FailureLabel Number of bootable partition - $numberofBootable"
                return $global:FAILED
            }
            else {
                Write-LogFile "$global:SuccessLabel Number of bootable partition - $numberofBootable"
                return $global:PASSED
            }
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_64BitOS {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "OS is 64 bit"
                FailureText = "OS is not 64 bit. Try again with a 64 bit OS image."
            }
            $global:FunctionList += $obj
        }
        true {
            $OSArchitecture = (Get-WmiObject -Class Win32_ComputerSystem).SystemType
            Write-LogFile " OS Architecture - $OSArchitecture"
            $ImageInfo["OSArchitecture"] = $OSArchitecture
            if ($OSArchitecture -match 'x64') {
                Write-LogFile "$global:SuccessLabel This OS is a 64 bit OS. "
                return $global:PASSED
            }
            else {
                Write-LogFile $global:AdditionalOSRequirementsNotMet64BitLanguageLogMessage
                return $global:FAILED
            }
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_RearmCount {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "Rearm count is not 0"
                FailureText = "The rearm count of the image is 0. Rearm the image"
            }
            $global:FunctionList += $obj
        }
        true {
            # If rearm count is greatet then 0 = passed
            if((cscript C:\Windows\System32\slmgr.vbs /dlv | Out-String) -match "windows.+: ([1-9])"){
                Write-LogFile "$global:SuccessLabel The rearm count is sufficient for BYOL."
                return $global:PASSED
            }
            else {
                Write-LogFile " $global:FailureLabel The rearm count is not sufficient for BYOL."
                return $global:FAILED
            }
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_InPlaceUpgrade {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "Image is not in-place upgraded"
                FailureText = "Image is in-place upgrade. Try again with fresh image."
            }
            $global:FunctionList += $obj
        }
        true {
            $upgradecheck = Get-ChildItem -Path HKLM:\SYSTEM\Setup | Where-Object {$_.PsChildName -match "Source OS" -or $_.PsChildName -match "Upgrade"}
            if ($upgradecheck -eq $null) {
                Write-LogFile "$global:SuccessLabel OS is Not Upgraded"
                return $global:PASSED
            }
            else {
                Write-LogFile " $global:FailureLabel OS is Upgraded"
                return $global:FAILED
            }
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Test-BYOL_AVnotInstalled {
    switch ($AMIAutomation) {
        false {
            $obj = [PsCustomObject]@{
                Name        = $($MyInvocation.MyCommand.Name)	    
                TextLabel   = "Antivirus is not installed"
                FailureText = "Antivirus is installed. Uninstall Antivirus $AVname."
            }
            $global:FunctionList += $obj
        }
        true {
            # No Antivirus should be installed, exept "Windows Defender"
            $AVname = (Get-WmiObject -Namespace "root\SecurityCenter2" -Class AntiVirusProduct).displayName | Where-Object {$_ -NotLike "Windows Defender"}
            if ($AVname -eq $null) {
                Write-LogFile "$global:SuccessLabel Antivirus is not installed"
                return $global:PASSED
            }
            else {
                Write-LogFile " $global:FailureLabel Antivirus is installed. Detected Antivirus name $AVname."
                return $global:FAILED
            }
        }
        fix {
            $global:OutputBox.AppendText($global:FailureText)
        }
    }
}
function Write-BYOLCheckerRegkey {
    New-Item "HKLM:\Software\Amazon\BYOLChecker" -Force
    New-ItemProperty "HKLM:\Software\Amazon\BYOLChecker" -Name version -Value $ScriptVersion -Force
    New-ItemProperty "HKLM:\Software\Amazon\BYOLChecker" -Name status -Value $status -Force
    New-ItemProperty "HKLM:\Software\Amazon\BYOLChecker" -Name date -Value $fileTimestamp -Force
}
function Get-BYOLCheckerRegkey {
    $BYOLCheckerRegkey = "HKLM:\Software\Amazon\BYOLChecker"

    if (Test-Path $BYOLCheckerRegkey) {
        $Resp = Get-ItemProperty $BYOLCheckerRegkey
        $Message = "SUCCESS : $($Resp.status) - BYOLChecker version $($Resp.version) was executed on $($Resp.date)"
    }
    else {
        $Message = "WARNING : Offline BYOLChecker has not validated the image"
    }
    Write-log -Type Information -Message $Message
}
function Write-LogFile {
    Param ([string]$logstring)
    try {
        $currentTime = Get-Date
        Add-content $Logfile -Encoding Unicode -Value "$currentTime $logstring"
    }
    catch {
        # if the logs themselves give an error in logging. Simply, writing to host. 
        Write-Host $_.Exception.Message
    }
}
function Get-RandomCharacters($length, $characters) {
    # function used for generating a random password
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs = ""
    return [String]$characters[$random]
}
function Optimize-String([string]$inputString) {
    # function used for generating a random password
    $characterArray = $inputString.ToCharArray()   
    $OptimizedStringArray = $characterArray | Get-Random -Count $characterArray.Length     
    $outputString = -join $OptimizedStringArray
    return $outputString 
}
function New-Password {
    # function used for generating a random password
    $password = Get-RandomCharacters -length 10 -characters 'abcdefghiklmnoprstuvwxyz'
    $password += Get-RandomCharacters -length 1 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
    $password += Get-RandomCharacters -length 1 -characters '1234567890'
    $password += Get-RandomCharacters -length 1 -characters '!"§$%&/()=?}][{@#*+'
    $password = Optimize-String $password
    return $password
}
function New-WorkSpaces_BYOL_User {
    $password = New-Password
    NET USER "Workspaces_BYOL" $password /add | Out-Null
    NET LOCALGROUP "Administrators" "Workspaces_BYOL" /add | Out-Null
    $global:OutputBox.AppendText("`nNew User WorkSpaces_BYOL has been Startd.`nPlease copy and retain the following `nWorkspaces_BYOL/$password `n`n")
}
function SaveImageInfo {
    $InfoInJson = $ImageInfo | ConvertTo-Json
    Set-Content $Infofile -Encoding Unicode -Value $InfoInJson
}
function Set-EC2Config {
    # Enable execution of user data on bootup
    $configPath = "C:\Program Files\Amazon\Ec2ConfigService\Settings\config.xml"
    $OSCheck = (Get-CimInstance win32_operatingsystem).Caption
    
    if (($OSCheck -notlike "*Server 2016*") -and (Test-Path $configPath)) {
        Write-LogFile -Type Information -Message "Configuring EC2Config Settings & Config"
        $configFile = Get-Item $configPath
        $configXml = [xml](Get-Content $configFile)
        $pluginList = $configXml.Ec2ConfigurationSettings.Plugins.Plugin
        foreach ($plugin in $pluginList) {
            switch ($plugin.Name) {
                "Ec2HandleUserData" { $plugin.state = "Enabled" }
                default {}
            }
        }
        $globalSettings = $configXml.Ec2ConfigurationSettings.GlobalSettings
        $globalSettings.SetDnsSuffixList = "false"
        $configXml.save($configPath)
        Write-LogFile -Type Information -Message "Deleting old UserData Scripts"
        if (Test-Path "C:\Program Files\Amazon\Ec2ConfigService\Scripts\UserScript.ps1") {
            Remove-Item "C:\Program Files\Amazon\Ec2ConfigService\Scripts\UserScript.ps1" -Force
        }
    }
    else {
        Write-LogFile -Type Information -Message "OS is $OSCheck or $configPath is false. Skipping EC2Config"
    }
}
function Test-RunAsAdmin {
    $RuAsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (!($RuAsAdmin)) {
        Add-Type -AssemblyName System.Windows.Forms
        # show the MsgBox:
        $result = [System.Windows.Forms.MessageBox]::Show(
            'Administrator rights are required to run this script. 
Open a PowerShell session that is running as Administrator, and rerun the script. 
For more information, see https://docs.aws.amazon.com/workspaces/latest/adminguide/byol-windows-images.html
'
            , 'Error', 'OK', 16)
        exit
    }
}
function Set-OSFunctions {
    # Create Function List based on OS Version
    switch ([environment]::OSVersion.Version.Major){
    6 {$ExemptFunct = $WIN7ExemptedFunctions}
    10 {$ExemptFunct = $WIN10ExemptedFunctions}
    }
    $global:ListFunctions = $ListFunctionsAll | Where-Object {$ExemptFunct -NotContains $_}
}
function Disable-Hibernation {
    # Disabling Hibernations
    powercfg.exe /hibernate off
    Write-LogFile -Type Information -Message "Disabled hibernation"
}
function Set-AutomationFunctions {
    # Create Function List for AMIAutomation workflow (exclude functions not needed)
    $global:ListFunctions = $global:ListFunctions | Where-Object {$AutomationExemptFunctions -NotContains $_}
}
# Display Results of test in the form
function ClearOutputBox {
    $global:OutputBox.clear()
}
function Button_Click {
    #start writing results to log
    Write-LogFile (get-date)

    $mainPanel.Controls.Add($progressBarLabel)
    $mainPanel.Controls.Add($progressBar)
    
    clearOutputBox

    #place holder text
    $global:OutputBox.AppendText("Running Tests... This could take a few minutes to complete.")

    $TestResults = New-Object System.Collections.ArrayList
    For ($i = 0; $i -lt $global:CHECK_COUNT; $i++) {
        $ResultLabels.Item($i).forecolor = "Black"
        $ResultLabels.Item($i).text = "Checking.."
        $CommandName = $ListFunctions.Get($i)
        Write-LogFile "Beginning test : ${CommandName}"
        try {
            if ( ${CommandName} -eq "checkHotFixesInstalled") {
                $global:OutputBox.AppendText("`n`Running Tests... UI may be unresponsive for this section.. Please Wait..")
            }
            $scriptResult = (Get-Item "function:$CommandName").ScriptBlock.Invoke();
            if ($CommandName -eq "checkHotFixesInstalled") {
                clearOutputBox
                $global:OutputBox.AppendText("Running Tests... This could take a few minutes to complete")
            }
        }
        catch {
            Write-LogFile $_
            if ($scriptResult -eq $null) {
                Write-LogFile " ${CommandName} failed with an exception"
                $scriptResult = $global:FAILED;
            }
        }
        Write-LogFile "Ending test : ${CommandName}"
        $TestResults.Add($scriptResult)
        $progressBar.value = (100 / $global:CHECK_COUNT) * ($i + 1)
        switch ($TestResults.Item($i)) {
            PASSED {
                $ResultLabels.Item($i).ForeColor = "Green"
                $ResultLabels.Item($i).Text = $global:PASSED
                $TroubleButtons.Item($i).Visible = $false
            }
            FAILED {
                $ResultLabels.Item($i).ForeColor = "Red"
                $ResultLabels.Item($i).Text = $global:FAILED
                $FailureText = $FailureLabelTexts.Get($i)
                $ClickFunction = {
                    $global:OutputBox.clear()
                    $global:OutputBox.AppendText($FailureText)
                }.GetNewClosure()
                $TroubleButtons.Item($i).Visible = $true
                $TroubleButtons.Item($i).Add_Click($ClickFunction)
                $FailedFlag ++                
                Write-Host "Failed function: $CommandName"
            }
            WARNING {
                $ResultLabels.Item($i).ForeColor = "DarkOrange"
                $ResultLabels.Item($i).Text = $global:WARNING
                $FailureText = $FailureLabelTexts.Get($i)
                $ClickFunction = {
                    $global:OutputBox.clear()
                    $global:OutputBox.AppendText($FailureText)
                }.GetNewClosure()
                
                $ClickFunctionFix = {
                    $AMIAutomation = "fix"
                    Get-Date | Out-Host
                    $ListFunctions.Get($i) | Out-Host 
                    $global:BYOLFunctions.Get($i).Name
                    $global:OutputBox.clear()
                    $global:OutputBox.AppendText("Fixing")
                }.GetNewClosure()
                                               
                $TroubleButtons.Item($i).Visible = $true
                $TroubleButtons.Item($i).Add_Click($ClickFunction)
                
                $global:failedIndexList = $failedIndexList + $i 
                $FixButtons.Item($i).Add_Click( {button_Click2 $failedIndexList})
                $ButtonFix.Visible = $true
                $WarningFlag ++
            }
            Default { 
                $global:OutputBox.AppendText("Unable to return results") 
            }
        }
        $script:form.Refresh()
    }
    clearOutputBox
    $global:OutputBox.AppendText("Done")
    SaveImageInfo
    if ($FailedFlag -gt 0 -or $WarningFlag -gt 0) {
        $status = "fail"
    }
    else {
        $status = "success"   
    }

    Set-EC2Config
    Write-BYOLCheckerRegkey

    If ($status -eq "success"){
        $mainPanel.Visible = $false
        # New Panel
        $Panel2.Controls.Add($script:TextBox2)
        $Panel2.Controls.Add($script:textBox3)
        $Panel2.Controls.Add($script:textBox4)
        $Panel2.Controls.Add($script:textBox5)
        $Panel2.Controls.Add($script:textBox6)
        $Panel2.Controls.Add($script:textBox7)
        $Panel2.Controls.Add($script:textBox8)
        $Panel2.Controls.Add($script:textBox9)
        $Panel2.Controls.Add($script:textBox10)
        $Panel2.Controls.Add($LinkLabel3)
        $Panel2.Controls.Add($LinkLabel4)
        $Panel2.Controls.Add($ButtonSys)
        $Panel2.Visible = $true
        }
    $mainPanel.Controls.Remove($progressBar)
}
function Button_Click2 {
    clearOutputBox
    $AMIAutomation = "fix"
    foreach ($failedIndex in $failedIndexList) {
        & $ListFunctions.Get($failedIndex) #-AMIAutomation fix
        $outputbox.appendtext("`nFixing $($ListFunctions.Get($failedIndex))")
    }
    $outputbox.appendtext("`nFixing Completed. `nRerun the Tests")
    $Button1.Text = "Rerun Tests"
    $ButtonFix.Visible = $false
}
function Button_Click3 {
    #clearOutputBox
   Run-Sysprep
   $script:SysprepErrorFileEntry = "Running Sysprep "
   $global:sysprepExe = "success"

        if ($global:sysprepExe -eq "success"){
        # New Panel
        $Panel2.Visible = $false
        $Text = "Sysprep started"
        $TextBox = New-TexBox 0 40 500 30 $Text "29, 129, 2" "Arial" 14 Regular "TopLeft"
        $Panel3.Controls.Add($TextBox)
        $Panel3.Visible = $true
        $script:t = 0
        $outputbox1.appendtext("$script:SysprepErrorFileEntry")
        do {
            $script:t++
            Get-SysprepLogs
            Start-Sleep 2
            }
        while ($script:t -lt $global:sysprepTimeRun) 
    }
}
# Display Results of test to form
# Form section
function New-Form {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    # Changing AMIAutomation to true to run the functions	
    $AMIAutomation = $true
    $TestLabelTexts = $FunctionList.TextLabel
    $FailureLabelTexts = $FunctionList.FailureText
    $global:CHECK_COUNT = $FunctionList.Count
	
    # Build Form
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "Amazon WorkSpaces Image Validation"
    $Form.Size = New-Object System.Drawing.Size(550, 900)
    $Form.MaximumSize = New-Object System.Drawing.Size(550, 1000)
    $form.FormBorderStyle = "Sizable"
    $Form.StartPosition = "WindowsDefaultLocation"
    $Form.Topmost = $False
    $Form.ShowInTaskbar = $True
    $Form.AutoSizeMode = "GrowAndShrink"
    $Form.SizeGripStyle = "auto"
    $Form.AutoScroll = $True
    $iconPath = "${PSScriptRoot}\workspacesIcon.ico"
    $icon = [system.drawing.icon]::ExtractAssociatedIcon($iconPath)
    $Form.Icon = $icon
    $script:form = $Form;
    # Main Panel 
    $mainPanel = new-panel mainPanel
    $Form.Controls.Add($mainPanel)

    $Panel2 = new-panel panel2
    $Form.Controls.Add($Panel2)

    $Panel3 = new-panel Panel3
    $Form.Controls.Add($Panel3)
    
    # Big buttons
    # Add big buttons
    $Button1 = New-Object System.Windows.Forms.Button
    $Button1.Anchor = "top" , "left"
    $locX = $mainPanel.Location.X
    $locY = $mainPanel.Location.Y + 22
    $Button1.Location = New-Object System.Drawing.Point $locX , $locY
    $Button1.Size = New-Object System.Drawing.Size(100, 30)
    $Button1.Text = "Begin Tests"
    $Font = New-Object System.Drawing.Font("Arial",10,[System.Drawing.FontStyle]::Bold)
    $Button1.Font = $Font
    $Button1.ForeColor = "255, 255, 255"
    $Button1.BackColor = "67, 96, 140"

    $ButtonFix = New-Object System.Windows.Forms.Button
    $ButtonFix.Anchor = "top" , "left"
    $locX = $mainPanel.Location.X + 105
    $locY = $mainPanel.Location.Y + 22
    $ButtonFix.Location = New-Object System.Drawing.Point $locX , $locY
    $ButtonFix.Size = New-Object System.Drawing.Size(130, 30)
    $ButtonFix.Text = "Fix All Warnings"
    $Font = New-Object System.Drawing.Font("Arial",10,[System.Drawing.FontStyle]::Bold)
    $ButtonFix.Font = $Font
    $ButtonFix.BackColor = "Orange" 
    $ButtonFix.Visible = $false

    $ButtonSys = New-Object System.Windows.Forms.Button
    $ButtonSys.Anchor = "top" , "left"
    $locX = $Panel2.Location.X
    $locY = $Panel2.Location.Y + 325
    $ButtonSys.Location = New-Object System.Drawing.Point $locX , $locY
    $ButtonSys.Size = New-Object System.Drawing.Size(100, 30)
    $ButtonSys.Text = "Run Sysprep"
    $Font = New-Object System.Drawing.Font("Arial",10,[System.Drawing.FontStyle]::Bold)
    $ButtonSys.Font = $Font
    $ButtonSys.ForeColor = "255, 255, 255"
    $ButtonSys.BackColor = "67, 96, 140"
    $ButtonSys.Visible = $true

    $progressBarLabel = New-Object System.Windows.Forms.label
    $progressBarLabel.Anchor = "top", "right"
    $locX = $mainPanel.Location.X + 0.55 * $mainPanel.Size.Width
    $locY = $mainPanel.Location.Y + 5
    $progressBarLabel.Location = New-Object System.Drawing.Point $locX , $locY
    $progressBarLabel.AutoSize = $True
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Anchor = "top", "right"
    $progressBar.Value = 0
    $progressBar.Style = "Continuous"
    $locX = $mainPanel.Location.X + 0.5 * $mainPanel.Size.Width
    $locY = $mainPanel.Location.Y + 22
    $progressBar.Location = New-Object System.Drawing.Point $locX , $locY
    $progressBar.Size = New-Object System.Drawing.Size(170, 30)
    
    #Add big buttons to form
    $mainPanel.Controls.Add($Button1)
    $mainPanel.Controls.Add($ButtonFix)
    $mainPanel.Controls.Add($script:textBox1)

    #Add Button event
    $Button1.Add_Click( {Button_Click})
    $ButtonFix.Add_Click( {Button_Click2})
    $ButtonSys.Add_Click({Button_Click3})
    
    # Output Box
    $global:OutputBox = New-Object System.Windows.Forms.RichTextBox
    $locX = $mainPanel.Location.X 
    $locY = $mainPanel.Location.Y + 82
    $global:OutputBox.Location = New-Object System.Drawing.Point $locX , $locY
    $global:OutputBox.Size = New-Object System.Drawing.Size(420, 60)
    $mainPanel.Controls.Add($global:OutputBox)

    # Output Box1
    $global:OutputBox1 = New-Object System.Windows.Forms.RichTextBox
    $locX = $Panel3.Location.X 
    $locY = $Panel3.Location.Y + 100
    $global:OutputBox1.Location = New-Object System.Drawing.Point $locX , $locY
    $global:OutputBox1.Size = New-Object System.Drawing.Size(500, 400)
    $Panel3.Controls.Add($global:OutputBox1)

    # Test Labels
    $TestLabels = New-Object System.Collections.ArrayList
	
    For ($i = 0; $i -lt $global:CHECK_COUNT; $i++) {
        $TestLabel = New-Object System.Windows.Forms.label
        $TestLabel.Anchor = "top" , "left"
        $locX = $mainPanel.Location.X
        $locY = $mainPanel.Location.Y + 130 + ($i + 1) * 22
        $TestLabel.Location = New-Object System.Drawing.Point $locX, $locY
        $TestLabel.Text = $TestLabelTexts.Get($i)
        $TestLabel.AutoSize = $true
        $TestLabels.Add($TestLabel)
        $mainPanel.Controls.Add($TestLabel)
    }
    # Results Labels
    $ResultLabels = New-Object System.Collections.ArrayList
    #Add results labels
    For ($i = 0; $i -lt $global:CHECK_COUNT; $i++) {
        $ResultLabel = New-Object System.Windows.Forms.label
        $ResultLabel.Anchor = "top", "right"
        $locX = $mainPanel.Location.X + 0.65 * $mainPanel.Size.Width
        $locY = $mainPanel.Location.Y + 130 + ($i + 1) * 22
        $ResultLabel.Location = New-Object System.Drawing.Point $locX , $locY
        $ResultLabel.Text = "To be tested"
        $ResultLabel.AutoSize = $True
        $ResultLabels.Add($ResultLabel)
        $mainPanel.Controls.Add($ResultLabel)
    }
    $TroubleButtons = New-Object System.Collections.ArrayList
    # Add info buttons
    For ($i = 0; $i -lt $global:CHECK_COUNT; $i++) {
        $TroubleButton = New-Object System.Windows.Forms.Button
        $TroubleButton.Anchor = "top" , "right"
        $locX = $mainPanel.Location.X + 0.80 * $mainPanel.Size.Width
        $locY = $mainPanel.Location.Y + 130 + ($i + 1) * 22
        $TroubleButton.Location = New-Object System.Drawing.Point $locX , $locY
        $TroubleButton.Size = New-Object System.Drawing.Size(50, 20)
        $TroubleButton.Text = "Info..."
        $TroubleButton.Visible = $false
        $TroubleButtons.Add($TroubleButton)
        $mainPanel.Controls.Add($TroubleButton)
    }
    # Add fix buttons
    $FixButtons = New-Object System.Collections.ArrayList
    For ($i = 0; $i -lt $global:CHECK_COUNT; $i++) {
        $FixButton = New-Object System.Windows.Forms.Button
        $FixButton.Anchor = "top" , "right"
        $locX = $mainPanel.Location.X + 0.89 * $mainPanel.Size.Width
        $locY = $mainPanel.Location.Y + 130 + ($i + 1) * 22
        $FixButton.Location = New-Object System.Drawing.Point $locX , $locY
        $FixButton.Size = New-Object System.Drawing.Size(50, 20)
        $FixButton.Text = "Fix..."
        $FixButton.Visible = $false
        $FixButtons.Add($FixButton)
        $mainPanel.Controls.Add($FixButton)    
    }
    $lastTestLocation = [System.Windows.Forms.label]$TestLabels[-1] 
    # Link Labels
    # Add Link labels
    $LinkLabel1 = New-Object System.Windows.Forms.LinkLabel 
    $locX = $mainPanel.Location.X
    $locY = $lastTestLocation.Location.Y + 35
    $LinkLabel1.Location = New-Object System.Drawing.Point $locX , $locY
    $LinkLabel1.AutoSize = $True
    $LinkLabel1.LinkColor = "BLUE"
    $LinkLabel1.ActiveLinkColor = "RED"
    $LinkLabel1.Text = "AWS VM Import Prerequisite Page"
    $LinkLabel1.add_Click( {[system.Diagnostics.Process]::start("http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/VMImportPrerequisites.html")})
    
    $LinkLabel2 = New-Object System.Windows.Forms.LinkLabel
    $locX = $mainPanel.Location.X
    $locY = $lastTestLocation.Location.Y + 52
    $LinkLabel2.Location = New-Object System.Drawing.Point $locX , $locY
    $LinkLabel2.AutoSize = $True
    $LinkLabel2.LinkColor = "BLUE"
    $LinkLabel2.ActiveLinkColor = "RED"
    $LinkLabel2.Text = "Windows Management Framework 4.0 (For All Other Windows OS)"
    $LinkLabel2.add_Click( {[system.Diagnostics.Process]::start("https://www.microsoft.com/en-au/download/details.aspx?id=40855")})
    
    $Text = "Note: All tests must PASS for WorkSpaces image validation to succeed"
    $script:textBox1 = New-TexBox 10 62 500 20 $Text "black" "Arial" 9 Bold "TopLeft"
    
    $Text = "Validation successful"
    $script:textBox2 = New-TexBox 0 40 500 20 $Text "29, 129, 2" "Arial" 14 Regular "TopLeft"
        
    $Text = "Review the following locale settings:"
    $script:textBox3 = New-TexBox 0 70 500 20 $Text "black" "Arial" 12 Regular "TopLeft"

    $Text = "$([char]0x2022) System Locale :`n$([char]0x2022) User Locale:"
    $script:textBox4 = New-TexBox 0 95 140 50 $Text "black" "Arial" 12 Regular "TopLeft"

    $Text = "$global:SystemLocale`n$global:UserLocale"
    $script:textBox5 = New-TexBox 140 95 60 50 $Text "black" "Arial" 12 Regular "TopLeft"

    $Text = "Proceed to run the Sysprep"
    $script:textBox6 = New-TexBox 0 210 500 20 $Text "black" "Arial" 12 Bold "TopLeft"
    
    $Text = "Once Sysprep completes, your system will shut down"
    $script:textBox7 = New-TexBox 0 240 400 20 $Text "black" "Arial" 12 Regular "TopLeft"
    
    $Text = "Follow the remaining instructions to complete importing BYOL image"
    $script:textBox8 = New-TexBox 0 260 510 20 $Text "black" "Arial" 12 Regular "TopLeft"

    $LinkLabel4 = New-Object System.Windows.Forms.LinkLabel
    $locX = 0
    $locY = 280
    $LinkLabel4.Location = New-Object System.Drawing.Point $locX , $locY
    $LinkLabel4.AutoSize = $True
    $LinkLabel4.LinkColor = "BLUE"
    $LinkLabel4.ActiveLinkColor = "RED"
    $LinkLabel4.Text = "BYOL Administration Guide"
    $Font = New-Object System.Drawing.Font("Arial",12,[System.Drawing.FontStyle]::Regular)
    $LinkLabel4.Font = $Font
    $LinkLabel4.TextAlign = "TopLeft"
    $LinkLabel4.add_Click( {[system.Diagnostics.Process]::start("https://docs.aws.amazon.com/workspaces/latest/adminguide/byol-windows-images.html")})

    $Text = "I want to change locale settings"
    $script:textBox9 = New-TexBox 0 400 500 20 $Text "black" "Arial" 12 Bold "TopLeft"

    $LinkLabel3 = New-Object System.Windows.Forms.LinkLabel
    $locX = 0
    $locY = 420
    $LinkLabel3.Location = New-Object System.Drawing.Point $locX , $locY
    $LinkLabel3.AutoSize = $True
    $LinkLabel3.LinkColor = "BLUE"
    $LinkLabel3.ActiveLinkColor = "RED"
    $LinkLabel3.Text = "View guide"
    $Font = New-Object System.Drawing.Font("Arial",12,[System.Drawing.FontStyle]::Regular)
    $LinkLabel3.Font = $Font
    $LinkLabel3.add_Click( {[system.Diagnostics.Process]::start("https://msdn.microsoft.com/en-us/library/windows/hardware/dn965674(v=vs.85).aspx")})

    $LinkLabel5 = New-Object System.Windows.Forms.LinkLabel
    $LinkLabel5.AutoSize = $True
    $LinkLabel5.LinkColor = "BLUE"
    $LinkLabel5.ActiveLinkColor = "RED"
    $LinkLabel5.Text = "Sysprep Logs"
    $LinkLabel5.add_Click( {[system.Diagnostics.Process]::start("C:\Windows\System32\sysprep\Panther\setuperr.log")})

    # Add link labels to form
    $mainPanel.Controls.Add($LinkLabel1)
    $mainPanel.Controls.Add($LinkLabel2)
    $mainPanel.Controls.Add($script:TextBox1)
 
    # Show the Form (do this at the end of the function)
    $form.ShowDialog()| Out-Null
}
function New-Panel ($pannelName) {
    New-Variable -Name $pannelName -Force -Scope Global
    $global:pannelName = New-Object Windows.Forms.Panel
    $global:pannelName.Anchor = "top", "left"
    $global:pannelName.Size = New-Object System.Drawing.Size (500, 840)
    $locX = $global:pannelName.Location.X + 10
    $locY = $global:pannelName.Location.Y + 5
    $global:pannelName.Location = New-Object System.Drawing.Point $locX, $locY
    return $global:pannelName
}
Function New-TexBox ($x,$y,$sizeX,$sizeY,$text,$color,$font,$fontSize,$FontStyle,$textAlign) {
    # function to create Text Box for Form
    $TextBox = New-Object System.Windows.Forms.Label
    $locX = $Panel.Location.X + $x
    $locY = $Panel.Location.Y + $y
    $TextBox.Location = New-Object System.Drawing.Point $locX , $locY
    $TextBox.Size = New-Object System.Drawing.Size($sizeX,$sizeY)
    $Font = New-Object System.Drawing.Font($Font,$fontSize,[System.Drawing.FontStyle]::$FontStyle)
    $TextBox.Font = $Font
    $TextBox.TextAlign = $textAlign
    $TextBox.ForeColor = $color
    $TextBox.Text = $text
    return $TextBox
}
function Get-OOBE {
    $systemInfo = Get-WmiObject Win32_OperatingSystem 
    $global:RegisteredOrganization = $systemInfo.Organization
    $global:RegisteredOwner = $systemInfo.RegisteredUser
    $global:SystemLocale = Get-Culture | Select -ExpandProperty name
    $global:UserLocale = Get-UICulture | Select -ExpandProperty name
}
function Set-OOBE {
    $xml = [xml](Get-Content $global:OOBEfile)
    $xmlElement = $xml.get_DocumentElement()
    $xmlSetting = (($xmlElement.settings | Where-Object {$_.Pass -eq "oobeSystem"}).Component | Where-Object {$_.Name -eq "Microsoft-Windows-International-Core"})
    $xmlSetting.InputLocale = "$global:SystemLocale"
    $xmlSetting.SystemLocale = "$global:SystemLocale"

    $xmlSetting.UILanguage = "$global:UserLocale"
    $xmlSetting.UserLocale = "$global:UserLocale"

    $xmlSetting = (($xmlElement.settings | Where-Object {$_.Pass -eq "oobeSystem"}).Component | Where-Object {$_.Name -eq "Microsoft-Windows-Shell-Setup"})
    $xmlSetting.RegisteredOrganization = $RegisteredOrganization
    $xmlSetting.RegisteredOwner = $RegisteredOwner
    $xmlSetting = (($xmlElement.settings | Where-Object {$_.Pass -eq "specialize"}).Component | Where-Object {$_.Name -eq "Microsoft-Windows-Shell-Setup"})
    $xmlSetting.RegisteredOrganization = $RegisteredOrganization

    $xml.save($global:OOBEfile)
}
function Run-Sysprep {
    Set-OOBE
    # Clear sysprep logs before running it
    $script:SysprepErrorFileLocation = "C:\Windows\system32\sysprep\Panther\setuperr.log"
    if (test-path $script:SysprepErrorFileLocation) {
        Remove-Item $script:SysprepErrorFileLocation -Force -ErrorAction SilentlyContinue
    }
    $script:SysprepSuccededTag = "C:\Windows\system32\sysprep\Sysprep_succeeded.tag"
    if (test-path $script:SysprepSuccededTag) {
        Remove-Item $script:SysprepSuccededTag -Force -ErrorAction SilentlyContinue
    }
    Write-host "Syspreping ..."
    if ((Get-Service -Name Schedule).Status -ne "Running") {
        Start-Service Schedule
    }
    # The task is ran once on demand to execute sysprep under system context to mimic IMS process and will delete on completion 
    $argList = "/RL HIGHEST /Create /RU `"SYSTEM`" /TN `"sysprep`" /SC `"ONEVENT`" /F /EC Application /MO *[System/EventID=777777] /TR `"'C:\Windows\System32\Sysprep\sysprep.exe' /oobe /generalize /shutdown /quiet /unattend:$global:OOBEfile`""
    Start-process "C:\Windows\System32\schtasks.exe" -ArgumentList $argList -Wait -WindowStyle Hidden
    Start-process "C:\Windows\System32\schtasks.exe" -ArgumentList "/Run /tn `"sysprep`"" -Wait -WindowStyle Hidden
    Start-process "C:\Windows\System32\schtasks.exe" -ArgumentList "/Delete /tn `"sysprep`" /f" -WindowStyle Hidden
}
function Get-SysprepLogs {

    If((Test-Path $script:SysprepErrorFileLocation) -and $null -ne (Get-Content -Path $script:SysprepErrorFileLocation)){
        $Panel3.Controls.Remove($TextBox)
        $Text = "Sysprep failed"
        $TextBox11 = New-TexBox 0 40 200 30 $Text "red" "Arial" 14 Regular "TopLeft"
        $Panel3.Controls.Add($TextBox11)
        $Panel3.Visible = $true
        
        $global:OutputBox1.clear()
        $script:SysprepErrorFileEntry = ((Get-Content -Path $SysprepErrorFileLocation) | Select-String -Pattern "error","fail" | Select-Object -Last 10)
        $outputbox1.Controls.Add($LinkLabel5)
        
        foreach ($line in $script:SysprepErrorFileEntry){
            $text = "`n`n$line"
            $outputbox1.appendtext($text)
        }
        
            $script:t = $global:sysprepTimeRun
        $outputbox1.appendtext("`n`nOpening sysprep error log file in a separate window")
        Invoke-Item $SysprepErrorFileLocation
    }
    if (Test-Path $script:SysprepSuccededTag) {
        $Panel3.Controls.Remove($TextBox11)
        $Text = "Sysprep succeeded"
        $TextBox12 = New-TexBox 0 40 200 30 $Text "green" "Arial" 14 Regular "TopLeft"
        $Panel3.Controls.Add($TextBox12)
        $Panel3.Visible = $true
        $global:OutputBox1.clear()
        $outputbox1.appendtext("Sysprep succeeded. System will shutdown in 5 sec")
        shutdown.exe /s /f /t 5
    }
    else {
        $outputbox1.appendtext(" .")
    }
}

function main {
    # get all functions that will validate the system
    try {
        $ListFunctionsAll = (Get-BYOLFunctions).Name
        # AMI Automation condition is used for AMI Automation Workflow
        Set-OSFunctions      
        if ($AMIAutomation) {
            . "${PSScriptRoot}\helper.ps1"
            Set-AutomationFunctions           
            if (!([System.Diagnostics.EventLog]::SourceExists($scriptName))) {
                New-EventLog -LogName $LogName -Source $scriptname
            }
            else {
                Write-Debug "Event Log Source $scriptname exist"
            }

            Get-BYOLCheckerRegkey
            foreach ($byolFunc in $global:ListFunctions) {
                # Execute each Test BYOL function to validate the system
                # This will create a list of function objects with the function name and Text Labels needed to condtruct the Form    
                
                $result = Invoke-Expression $byolFunc
                Write-log -Type Information -Message "$result : $byolFunc"
                
                # Storing the results Success/Failed
                $resultList += $result
            }

            # Check the string for any failure
            # A failure will be recorded in DDB with Ami Automation Workflow and will stop AMI automation build
            if ($resultList -match "FAILED" -or $resultList -match "WARNING") {
                $BYOLValue = "FAILED"
            }
            else {
                $BYOLValue = "success"
            }
            return $BYOLValue
        }
        # Manual interactive form AMIAutomation = $true
        else {
            foreach ($byolFunc in $global:ListFunctions) {
                Invoke-Expression $byolFunc
            }
            # From the above Function Objects List Start the Interactive Form
            Write-Host "Begin Interactive Form Checker"
            Test-RunAsAdmin
            Disable-Hibernation
            Get-OOBE
            New-Form | Out-Null
        }
    }
    catch {
        Write-Host "Unexpected error: $_"
    }
}
# Execute
main
