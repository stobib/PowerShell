[CmdletBinding()]
param(
  [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$ComputerName,
  [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][boolean]$DefaultAnswer,
  [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][uint64]$TelnetPort,
  [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][int]$TimeOut
)
<#             http://msdn.microsoft.com/en-us/library/x83z1d9f(v=vs.84).aspx             #>
<# Button Types
                    Decimal value    Hexadecimal value    Description
                    0                0x0                  Show OK button.
                    1                0x1                  Show OK and Cancel buttons.
                    2                0x2                  Show Abort, Retry, and Ignore buttons.
                    3                0x3                  Show Yes, No, and Cancel buttons.
                    4                0x4                  Show Yes and No buttons.
                    5                0x5                  Show Retry and Cancel buttons.
                    6                0x6                  Show Cancel, Try Again, and Continue buttons.
#>#             Button Types
<# Icon Types
                    Decimal value    Hexadecimal value    Description
                    16               0x10                 Show "Stop Mark" icon.
                    32               0x20                 Show "Question Mark" icon.
                    48               0x30                 Show "Exclamation Mark" icon.
                    64               0x40                 Show "Information Mark" icon.
#>#             Icon Types
<# Return Value
                    Decimal value    Description
                    -1               The user did not click a button before nSecondsToWait seconds elapsed.
                    1                OK button
                    2                Cancel button
                    3                Abort button
                    4                Retry button
                    5                Ignore button
                    6                Yes button
                    7                No button
                    10               Try Again button
                    11               Continue button
#>#             Return Value
[datetime]$Global:StartTime=Get-Date -Format o
[datetime]$Global:EndTime=0
Clear-History;Clear-Host
Set-Variable -Name RestartNeeded -Value 0
Set-Variable -Name Repositories -Value @('PSGallery')
Set-Variable -Name PackageProviders -Value @('Nuget')
Set-Variable -Name ModuleList -Value @('Rsat.ActiveDirectory.')
Set-Variable -Name OriginalPref -Value $ProgressPreference
Set-Variable -Name PowerCLIPath -Value (${env:ProgramFiles(x86)}+"\VMware\Infrastructure\PowerCLI")
# PowerShell Version (.NetFramework Error Checking) ---> Future change needed for PowerShell Core 7.0
$ProgressPreference="SilentlyContinue"
Write-Host ("Please be patient while prerequisite modules are installed and loaded.")
$NugetPackage=Find-PackageProvider -Name $PackageProviders
ForEach($Provider In $PackageProviders){
    $FindPackage=Find-PackageProvider -Name $Provider
    $GetPackage=Get-PackageProvider -Name $Provider
    If($FindPackage.Version-ne$GetPackage.Version){
        Install-PackageProvider -Name $FindPackage.Name -Force -Scope CurrentUser
    }
}
ForEach($Repository In $Repositories){
    Set-PSRepository -Name $Repository -InstallationPolicy Trusted
}
ForEach($ModuleName In $ModuleList){
    $RSATCheck=Get-WindowsCapability -Name ($ModuleName+"*") -Online|Select-Object -Property Name,State
    If($RSATCheck.State-eq"NotPresent"){
        $InstallStatus=Add-WindowsCapability -Name $RSATCheck.Name -Online
        If($InstallStatus.RestartNeeded-eq$true){
            $RestartNeeded=1
        }
    }
}
Write-Host ("THe prerequisite modules are now installed and ready to process this script.")
$ProgressPreference=$OriginalPref
# PowerShell Version (.NetFramework Error Checking) ---<
Import-Module ActiveDirectory
Import-Module ProcessCredentials
$ErrorActionPreference='SilentlyContinue'
[string]$Global:DomainUser=($env:USERNAME.ToLower())
[string]$Global:Domain=($env:USERDNSDOMAIN.ToLower())
[string]$Global:ScriptPath=$MyInvocation.MyCommand.Definition
[string]$Global:ScriptName=$MyInvocation.MyCommand.Name
Set-Location ($ScriptPath.Replace($ScriptName,""))
Set-Variable -Name System32 -Value ($env:SystemRoot+"\System32")
Switch($DomainUser){
    {($_-like"sy100*")-or($_-like"sy600*")}{Break}
    Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
}
$SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=Get-Credential}
# Script Body --->> Unique code for Windows PowerShell scripting
Set-Variable -Name VCMgrSrvList -Value @('vcmgra01.inf','vcmgrb01.inf')
[string]$Global:LogLocation=($ScriptPath.Replace($ScriptName,"")+"Logs\"+$ScriptName.Replace(".ps1",""))
[string]$Global:LogDate=Get-Date -Format "yyyy-MMdd"
[string]$Global:LogCurrentIP=($LogLocation+"\Current_IP_"+$LogDate+".log")
[string]$Global:LogMissingIP=($LogLocation+"\Missing_IP_"+$LogDate+".log")
If($DefaultAnswer-eq$false){[boolean]$DefaultAnswer=0}
If($TelnetPort-eq0){[uint64]$TelnetPort=0}
[string]$Global:PortTest="Not tested"
If($TimeOut-eq0){[int]$TimeOut=10}
$Global:SecureCredentials=$null
[String]$Global:RunTime=$null
[string]$Global:VCMgrSrv=""
$Global:DataEntry=""
[int]$Global:toFast=1
[int]$Global:toSlow=5
[int]$FormHeight=200
[int]$FormWidth=400
[int]$LabelLeft=10
[int]$LabelTop=20
[int]$TextboxTop=$LabelTop*2
[int]$ButtonTop=$FormHeight/2
[int]$ButtonLeft=$FormWidth/4
[int]$ButtonHeight=$FormHeight/6.5
[int]$ButtonWidth=$FormWidth/4.5
[int]$LabelHeight=$FormHeight/$LabelLeft
[int]$LabelWidth=$FormWidth-($LabelLeft*4)
Clear-History;Clear-Host
Function Get-VMStatus{
    Param(
        [Parameter(Mandatory=$true)][Alias("vCenterHost")][object]$ServerData=$null,
        [Parameter(Mandatory=$true)][Alias("vCenterAdmin")][PSCredential]$VCAdmin=$null
    )
    Begin{
        $StartConnection=0
        Do{
            ForEach($VCManager In $ServerData.VCManagerServer){
                If(($VCManager -ne $null)-and($VCAdmin -ne $null)){
                    Connect-VIServer $VCManager -Credential $VCAdmin|Out-Null
                    Clear-Host;Break
                }
            }
            $StartConnection++
        }Until($StartConnection-eq1)
    }
    Process{
        [System.Collections.ArrayList]$RowData=@()
        ForEach($VMGuest In $ServerData){
            [boolean]$bProcessVM=$false
            $VMGuestInfo=""
            $VMHostName=""
            $VMPowerState=""
            $GuestOS=""
            $IPAddress=""
            $VCManagerServer=($ServerData.VCManagerServer).Split("")[0]
            $VMStatusHeader="Logged into: ["+$VCManagerServer+"] using credentials: ["+$VCAdmin.UserName+"@"+$Domain+"]."
            $VMStatusProgress="Retrieving PowerState for ["+$VMGuest.VMGuestNames+"]."
            $NetBIOS=($VMGuest.VMGuestNames.Split(".")[0])
            $VMGuestInfo=Get-VM|Where-Object{$_.Name -like($NetBIOS+".*")}|Select-Object Name,PowerState,Guest
            If($VMGuestInfo.Name){
                If($VMGuestInfo.PowerState-eq"PoweredOn"){
                    If(($VMGuestInfo.Guest.OSFullName).ToLower()-notlike"*server*"){
                        $VMHostName=($VMGuestInfo.Name)
                        $VMPowerState=($VMGuestInfo.PowerState)
                        $GuestOS=($VMGuestInfo.Guest.OSFullName)
                        $IPAddress=($VMGuestInfo.Guest.IPAddress)
                        $bProcessVM=$true
                    }
                }ElseIf($VMGuestInfo.PowerState-eq"PoweredOff"){
                    $Message=("["+$VMGuestInfo.Name+"] is currently ["+$VMGuestInfo.PowerState+"].  Do you want to power it on?")
                    $Title="VM-Guest powered off!"
                    $PowerState=New-Object -ComObject WScript.Shell
                    $intAnswer=$PowerState.Popup($Message,$TimeOut,$Title,36) # Icon is the last variable.
                    If($intAnswer-eq-1){
                        If($DefaultAnswer-eq$false){
                            $intAnswer=7
                        }Else{
                            $intAnswer=6
                        }
                    }
                    Switch($intAnswer){
                        6{$Response="Yes";Break}
                        7{$Response="No";Break}
                        Default{$Response="No";Break}
                    }
                    If($Response-eq"Yes"){
                        Start-VM -VM $VMGuestInfo.Name -Confirm:$false -RunAsync
                        $VMHostName=($VMGuest.VMGuestNames)
                        $VMPowerState="Sent command to power on."
                        $GuestOS="Not validated."
                        $IPAddress=($VMGuest.VMGuestIPv4)
                        $bProcessVM=$true
                    }
                }
                If($bProcessVM){
                    $NewRow=[PSCustomObject]@{'VMGuest'=$VMHostName;'PowerState'=$VMPowerState;'GuestOS'=$GuestOS;'IPv4Address'=$IPAddress;'PortCheck'=$VMGuest.PortTest}
                    $VMStatusProgress+=$NewRow
                    $RowData.Add($NewRow)|Out-Null
                    $Message=$VMStatusProgress|Out-File $LogCurrentIP -Append
                    $NewRow=$null
                    Write-Progress -Activity $VMStatusHeader -Status $VMStatusProgress;Start-Sleep -Milliseconds $toFast
                }
            }
        }
    }
    End{
        $EndConnection=0
        Write-Progress -Activity $VMStatusHeader -Status $VMStatusProgress -Completed
        Do{
            ForEach($VCManager In $ServerData.VCManagerServer){
                Disconnect-VIServer $ServerData.VCManagerServer -Force:$true -Confirm:$false;Break
            }
            $EndConnection++
        }Until($EndConnection-eq1)
        Return ($RowData)
    }
}
Function LoadModules(){
    ReportStartOfActivity("Searching for ["+$productShortName+"] module components...")
    $loaded=Get-Module -Name $moduleList -ErrorAction Ignore|% {$_.Name}
    $registered=Get-Module -Name $moduleList -ListAvailable -ErrorAction Ignore|% {$_.Name}
    $notLoaded=$registered|?{$loaded -notcontains $_}
    ReportFinishedActivity
    Foreach($module In $registered){
        If($loaded -notcontains $module){
            ReportStartOfActivity("Loading module ["+$module+"].")
            Import-Module $module
            ReportFinishedActivity
        }
    }
}
Function ReportFinishedActivity(){
    $script:completedActivities++
    $script:percentComplete=(100.0 / $totalActivities)*$script:completedActivities
    $script:percentComplete=[Math]::Min(99, $percentComplete)
    Write-Progress -Activity $loadingActivity -CurrentOperation $script:currentActivity -PercentComplete $script:percentComplete
}
Function ReportStartOfActivity($activity){
    $script:currentActivity=$activity
    Write-Progress -Activity $loadingActivity -CurrentOperation $script:currentActivity -PercentComplete $script:percentComplete
}
Function ValidatePortRange{
    Param(
        [Parameter(Mandatory=$true)][Alias("vCenterHost")][object]$PortNumber=0
)
    If(($PortNumber-gt65535)-or($PortNumber-lt0)){
        $Message=("["+$PortNumber+"] is not a valid port number.  Please enter a number between 0 and 65535 for the port you want to check.")
        $Title="Port number not within the valid port number range!"
        $TestPort=New-Object -ComObject WScript.Shell 
        $intAnswer=$TestPort.Popup($Message,$TimeOut,$Title,48)
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        # Form design
        $form=New-Object System.Windows.Forms.Form
        $form.Text=$Title
        $form.Size=New-Object System.Drawing.Size(440,220)
        $form.StartPosition='CenterScreen'
        # Botton variables
        $okButton=New-Object System.Windows.Forms.Button
        $okButton.Location=New-Object System.Drawing.Point(111,111)
        $okButton.Size=New-Object System.Drawing.Size(90,35)
        $okButton.Text='OK'
        $okButton.DialogResult=[System.Windows.Forms.DialogResult]::OK
        $form.AcceptButton=$okButton
        $form.Controls.Add($okButton)
        # Cancel Button design and action
        $cancelButton=New-Object System.Windows.Forms.Button
        $cancelButton.Location=New-Object System.Drawing.Point(211,111)
        $cancelButton.Size=New-Object System.Drawing.Size(90,35)
        $cancelButton.Text='Cancel'
        $cancelButton.DialogResult=[System.Windows.Forms.DialogResult]::Cancel
        $form.CancelButton=$cancelButton
        $form.Controls.Add($cancelButton)
        # Form Label values
        $label=New-Object System.Windows.Forms.Label
        $label.Location=New-Object System.Drawing.Point(10,20)
        $label.Size=New-Object System.Drawing.Size(400,50)
        $label.Text="Please enter the port number that you want to test.  It needs to be within 0 and 65535 to be valid."
        $form.Controls.Add($label)
        # Form Textbox values
        $textBox=New-Object System.Windows.Forms.TextBox
        $textBox.Location=New-Object System.Drawing.Point(10,70)
        $textBox.Size=New-Object System.Drawing.Size(400,35)
        # Form Controls
        $form.Controls.Add($textBox)
        $form.Topmost=$true
        $form.Add_Shown({$textBox.Select()})
        # Form results actions
        $result=$form.ShowDialog()
        If($result-eq[System.Windows.Forms.DialogResult]::Cancel){
            $PortNumber=0
        }
        If($result-eq[System.Windows.Forms.DialogResult]::OK){
            $PortNumber=$textBox.Text
        }
    }
    Return $PortNumber
}
If($RestartNeeded-eq1){
    $Message="A restart of your computer is needed before this script can be run."
    $Title="Reboot required!"
    $Responce=New-Object -ComObject WScript.Shell 
    $intAnswer=$Responce.Popup($Message,0,$Title,32)
}Else{
    $moduleList=@(
        "VMware.VimAutomation.Core",
        "VMware.VimAutomation.Vds",
        "VMware.VimAutomation.Cloud",
        "VMware.VimAutomation.PCloud",
        "VMware.VimAutomation.Cis.Core",
        "VMware.VimAutomation.Storage",
        "VMware.VimAutomation.HorizonView",
        "VMware.VimAutomation.HA",
        "VMware.VimAutomation.vROps",
        "VMware.VumAutomation",
        "VMware.DeployAutomation",
        "VMware.ImageBuilder",
        "VMware.VimAutomation.License"
        )
    $productName="PowerCLI"
    $productShortName="PowerCLI"
    $loadingActivity=("Loading ["+$productName+"]")
    $script:completedActivities=0
    $script:percentComplete=0
    $script:currentActivity=""
    $script:totalActivities=$moduleList.Count + 1
    LoadModules
    Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -DisplayDeprecationWarnings $false -Confirm:$false|Out-Null
    # Process Existing Log Files
    [string[]]$LogFiles=@($LogCurrentIP,$LogMissingIP)
    ForEach($LogFile In $LogFiles){
        If(Test-Path -Path $LogFile){
            $FileName=(Split-Path -Path $LogFile -Leaf).Replace(".log","")
            $Files=Get-Item -Path ($LogLocation+"\*.*")
            [int]$FileCount=0
            ForEach($File In $Files){
                If(!($File.Mode-eq"d----")-and($File.Name-like($FileName+"*"))){
                    $FileCount++
                }
            }
            If($FileCount-gt0){
                Rename-Item -Path $LogFile -NewName ($FileName+"("+$FileCount+").log")
            }
        }
    }
    Write-Progress -Activity $loadingActivity -Completed
    Clear-Host;Clear-History
    Do{
        $ProgressPreference=$OriginalPreference
        If($ComputerName-eq""){
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
            # Form design
            $form=New-Object System.Windows.Forms.Form
            $form.Text='VM PowerState'
            $form.Size=New-Object System.Drawing.Size($FormWidth,$FormHeight)
            $form.StartPosition='CenterScreen'
            # Botton variables
            $okButton=New-Object System.Windows.Forms.Button
            $okButton.Location=New-Object System.Drawing.Point($ButtonLeft,($ButtonTop))
            $okButton.Size=New-Object System.Drawing.Size($ButtonWidth,$ButtonHeight)
            $okButton.Text='OK'
            $okButton.DialogResult=[System.Windows.Forms.DialogResult]::OK
            $form.AcceptButton=$okButton
            $form.Controls.Add($okButton)
            # Cancel Button design and action
            $cancelButton=New-Object System.Windows.Forms.Button
            $cancelButton.Location=New-Object System.Drawing.Point(($ButtonLeft+$ButtonWidth),($ButtonTop))
            $cancelButton.Size=New-Object System.Drawing.Size($ButtonWidth,$ButtonHeight)
            $cancelButton.Text='Cancel'
            $cancelButton.DialogResult=[System.Windows.Forms.DialogResult]::Cancel
            $form.CancelButton=$cancelButton
            $form.Controls.Add($cancelButton)
            # Form Label values
            $label=New-Object System.Windows.Forms.Label
            $label.Location=New-Object System.Drawing.Point($LabelLeft,$LabelTop)
            $label.Size=New-Object System.Drawing.Size($LabelWidth,$LabelHeight)
            $label.Text='Please enter the hostname of the computer.'
            $form.Controls.Add($label)
            # Form Textbox values
            $textBox=New-Object System.Windows.Forms.TextBox
            $textBox.Location=New-Object System.Drawing.Point($LabelLeft,$TextboxTop)
            $textBox.Size=New-Object System.Drawing.Size($LabelWidth,$LabelHeight)
            # Form Controls
            $form.Controls.Add($textBox)
            $form.Topmost=$true
            $form.Add_Shown({$textBox.Select()})
            # Form results actions
            $result=$form.ShowDialog()
            If($result-eq[System.Windows.Forms.DialogResult]::Cancel){
                $DataEntry="exit"
            }
            If($result-eq[System.Windows.Forms.DialogResult]::OK){
                $Hostname=""
                $DataEntry=$textBox.Text
            }
        }Else{
            If($ComputerName.length-gt0){
                $DataEntry=($ComputerName.ToLower())
            }
        }
        Do{
            $TelnetPort=ValidatePortRange -PortNumber $TelnetPort
        }Until(($TelnetPort-ge0)-and($TelnetPort-le65535))
        Switch(($DataEntry).ToLower()){
            {($_-eq"exit")}{
                Break
            }
            {($_.Length-eq0)-or($_-contains" ")}{
                $Message=("The value that you entered ["+$DataEntry+"] didn't return a valid active computer In the ["+$Domain+"] domain.")
                [System.Windows.MessageBox]::Show($Message,'Hostname not found!','Ok','Error')
                Clear-History;Clear-Host
                Break
            }
            Default{
                $VMCounter=0
                $DataSiteA=@()
                $DataSiteB=@()
                $ProgressLoop=0
                $VMResults=$null
                $VMHostName=@()
                $VMPowerState=@()
                $Connected=$false
                $Hostname=($DataEntry+"*")
                $Hostname=(Get-ADComputer -Filter{DNSHostname -like $Hostname} -Properties Name,IPv4Address,OperatingSystem,LastLogonDate|Sort-Object Name)
                If($Hostname){
                    If($VCMgrSrv-eq""){
                        ForEach($VCMgrSite In $VCMgrSrvList){
                            $Server=($VCMgrSite+"."+$Domain)
                            $Results=Test-NetConnection -ComputerName $Server
                            If($Results.PingSucceeded-eq$True){
                                If($Results.RemoteAddress-like"10.118.*"){
                                    $VCMgrSiteA=$Results
                                }Else{
                                    $VCMgrSiteB=$Results
                                }
                                Clear-Host
                            }
                        }
                    }
                    $intCounter=0
                    [System.Collections.ArrayList]$VMHeaders=@()
                    [System.Collections.ArrayList]$HeadersSiteA=@()
                    [System.Collections.ArrayList]$HeadersSiteB=@()
                    If(!(Test-Path -Path $LogLocation)){mkdir $LogLocation}
                    ForEach($VMGuest In $Hostname){
                        $VCManager=""
                        $PortTest="Not tested"
                        $DNSHostName=(($VMGuest.DNSHostName).Split(".")[0]+".*")
                        If($VMGuest.IPv4Address){
                            If($TelnetPort-ne0){
                                $TestPortHeader="Verifying that TCP Port: ["+$TelnetPort+"] is listening and access is allowed."
                                $TestPortProgress="  Currently testing VM Guest: ["+$VMGuest.DNSHostName+"]."
                                Write-Progress -Activity $TestPortHeader -Status $TestPortProgress;Start-Sleep -Milliseconds $toFast
                                $PortResults=Test-NetConnection -ComputerName $VMGuest.DNSHostName -Port $TelnetPort -InformationLevel "Detailed"
                                If($PortResults.RemotePort-eq$TelnetPort){
                                    If($PortResults.TcpTestSucceeded-eq$true){
                                        $PortTest="Open"
                                    }Else{
                                        $PortTest="Closed"
                                    }
                                }
                                Write-Progress -Activity $TestPortHeader -Status $TestPortProgress -Completed
                            }
                            If($VMGuest.IPv4Address-like"10.118.*"){
                                $DataSiteA+=($VCMgrSiteA.ComputerName,$VMGuest.DNSHostName,$VMGuest.IPv4Address,$PortTest)
                                $NewRow=[PSCustomObject]@{
                                    'VCManagerServer'=$VCMgrSiteA.ComputerName;
                                    'VMGuestNames'=$VMGuest.DNSHostName;
                                    'VMGuestIPv4'=$VMGuest.IPv4Address;
                                    'PortTest'=$PortTest}
                                $HeadersSiteA.Add($NewRow)|Out-Null
                                $VCManager=$VCMgrSiteA.ComputerName
                            }Else{
                                $DataSiteB+=($VCMgrSiteB.ComputerName,$VMGuest.DNSHostName,$VMGuest.IPv4Address,$PortTest)
                                $NewRow=[PSCustomObject]@{
                                    'VCManagerServer'=$VCMgrSiteB.ComputerName;
                                    'VMGuestNames'=$VMGuest.DNSHostName;
                                    'VMGuestIPv4'=$VMGuest.IPv4Address;
                                    'PortTest'=$PortTest}
                                $HeadersSiteB.Add($NewRow)|Out-Null
                                $VCManager=$VCMgrSiteB.ComputerName
                            }
                            $NewRow=$null
                            $VMCounter++
                            $SiteSortHeader="Beginning to process the VM's that are assigned to: ["+$VCManager+"]."
                            $SiteSortProgress="  VM Guest: ["+$VMGuest.DNSHostName+"] is assigned IP Address: ["+$VMGuest.IPv4Address+"]."
                        }Else{
                            $LastLogon=$VMGuest.LastLogonDate
                            [datetime]$CurrentDate=Get-Date
                            [datetime]$LastLogonDate=$LastLogon
                            $DateDiff=([datetime]$CurrentDate.Date)-([datetime]$LastLogonDate.Date)
                            $SiteSortHeader="The computer being processed doesn't have an IP Address!"
                            If($DateDiff.TotalDays-ge30){
                                $SiteSortProgress=("  ["+$VMGuest.DNSHostName+"] has been off-line for: '"+$DateDiff.TotalDays+"' days and needs to be reviewed for removal from the "+$Domain+" domain.")
                            }Else{
                                $SiteSortProgress={"  ["+$VMGuest.DNSHostName+"] couldn't verify the assignment to VCenter Manager site."}
                            }
                            $Message=$SiteSortHeader+$SiteSortProgress|Out-File $LogMissingIP -Append
                        }
                        Write-Progress -Activity $SiteSortHeader -Status $SiteSortProgress;Start-Sleep -Milliseconds $toFast
                    }
                    Write-Progress -Activity $SiteSortHeader -Status $SiteSortProgress -Completed
                    Do{
                        If($intCounter-eq0){
                            If($HeadersSiteA){
                                $VCMgrSiteHeader="Beginning to process the VM's that are assigned to: ["+($HeadersSiteA.VCManagerServer).Split("")[0]+"]."
                                $VCMgrSiteProgress="   Retrieving data for the first of ["+$VMCounter+"] system search matches."
                                $VMResults=Get-VMStatus -ServerData $HeadersSiteA -VCAdmin $SecureCredentials
                                Write-Progress -Activity $VCMgrSiteHeader -Status $VCMgrSiteProgress;Start-Sleep -Milliseconds $toSlow
                            }
                        }
                        If($intCounter-eq1){
                            If($HeadersSiteB){
                                $VCMgrSiteHeader="Beginning to process the VM's that are assigned to: ["+($HeadersSiteB.VCManagerServer).Split("")[0]+"]."
                                $VCMgrSiteProgress="   Retrieving data for the remaining ["+($VMCounter-$ProgressLoop)+"] system search matches."
                                $VMResults=Get-VMStatus -ServerData $HeadersSiteB -VCAdmin $SecureCredentials
                                Write-Progress -Activity $VCMgrSiteHeader -Status $VCMgrSiteProgress;Start-Sleep -Milliseconds $toSlow
                            }
                        }
                        If(!($VMResults.VMGuest-eq$null)-or(!($VMResults.VMGuest-eq""))){
                            ForEach($VMGuestInfo In $VMResults){
                                If($VMGuestInfo.VMGuest){
                                    $ProgressLoop++
                                    $VMResultsHeader="Processing the ["+$VMCounter+"] system that were found that match the search value ["+$DataEntry+"] you entered."
                                    $VMResultsProgress="Currently working on ["+$ProgressLoop+"] of the ["+$VMCounter+"] system search matches."
                                    $VMHostName=($VMGuestInfo.VMGuest)
                                    $VMPowerState=($VMGuestInfo.PowerState)
                                    $GuestOS=($VMGuestInfo.GuestOS)
                                    $IPAddress=($VMGuestInfo.IPv4Address)
                                    $NewRow=[PSCustomObject]@{'Guest Name'=$VMHostName;'Power State'=$VMPowerState;'Operating System'=$GuestOS;'IP Address(s)'=$IPAddress}
                                    $VMHeaders.Add($NewRow)|Out-Null
                                    $NewRow=$null
                                    Write-Progress -Activity $VMResultsHeader -Status $VMResultsProgress -PercentComplete($ProgressLoop/$VMCounter*100);Start-Sleep -Milliseconds $toFast
                                }
                            }
                            Write-Progress -Activity $VMResultsHeader -Status $VMResultsProgress -Completed
                        }
                        $intCounter++
                    }Until($intCounter-ge2)
                    Write-Progress -Activity $VCMgrSiteHeader -Status $VCMgrSiteProgress -Completed
                    Clear-History;Clear-Host
                    $VMHeaders|Format-List -Property ('Guest Name','Power State','Operating System','IP Address(s)')
                    $ComputerName=""
                }
                $EndTime=Get-Date -Format o
                $RunTime=(New-TimeSpan -Start $StartTime -End $EndTime)
                Break
            }
        }
    }Until($DataEntry.ToLower()-eq"exit")
}
# Script Body --->> Unique code for Windows PowerShell scripting
If($EndTime-eq0){
    [datetime]$EndTime=Get-Date -Format o
    $RunTime=(New-TimeSpan -Start $StartTime -End $EndTime)
    Write-Host ("Script runtime: ["+$RunTime+"]")
}Else{
    Write-Host ("Script runtime: ["+$RunTime.Hours+":"+$RunTime.Minutes+":"+$RunTime.Seconds+"."+$RunTime.Milliseconds+"]")
}
Set-Location $System32
$ProgressPreference=$OriginalPreference