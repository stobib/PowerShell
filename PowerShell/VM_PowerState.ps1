[CmdletBinding()]
param(
  [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$ComputerName,
  [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][boolean]$DefaultAnswer,
  [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][uint64]$TelnetPort,
  [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][int]$TimeOut
)
Clear-History;Clear-Host
Set-Variable -Name RestartNeeded -Value 0
Set-Variable -Name Repositories -Value @('PSGallery')
Set-Variable -Name ModuleList -Value @('Rsat.ActiveDirectory.')
Set-Variable -Name OriginalPref -Value $ProgressPreference
Set-Variable -Name PowerCLIPath -Value (${env:ProgramFiles(x86)}+"\VMware\Infrastructure\PowerCLI")
$ProgressPreference="SilentlyContinue"
Write-Host ("Please be patient while prerequisite modules are installed and loaded.")
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
Import-Module ActiveDirectory
Import-Module ProcessCredentials
$ErrorActionPreference='SilentlyContinue'
$Global:DomainUser=($env:USERNAME.ToLower())
$Global:Domain=($env:USERDNSDOMAIN.ToLower())
$ScriptPath=$MyInvocation.MyCommand.Definition
$ScriptName=$MyInvocation.MyCommand.Name
Set-Location ($ScriptPath.Replace($ScriptName,""))
Set-Variable -Name System32 -Value ($env:SystemRoot+"\System32")
Set-Variable -Name VCMgrSrvList -Value @('vcmgra01.inf','vcmgrb01.inf')
$Global:LogLocation=($ScriptPath.Replace($ScriptName,"")+"Logs\"+$ScriptName.Replace(".ps1",""))
$Global:LogDate=Get-Date -Format "yyyy-MMdd_HHmm"
If($DefaultAnswer-eq$false){[boolean]$DefaultAnswer=0}
If($TelnetPort-eq0){[uint64]$TelnetPort=0}
If($TimeOut-eq0){[int]$TimeOut=10}
$Global:SecureCredentials=$null
$Global:PortTest="Not checked"
$Global:DataEntry=""
$Global:VCMgrSrv=""
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
        If(($ServerData.VCManagerServer -ne $null)-and($VCAdmin -ne $null)){
            Connect-VIServer $ServerData.VCManagerServer -Credential $VCAdmin|Out-Null
            Clear-Host
        }
    }
    Process{
        $intVMGuest=0
        [System.Collections.ArrayList]$RowData=@()
        ForEach($VMGuest In $ServerData){
            $ProgressHeader="Logged into: ["+($ServerData.VCManagerServer).Split("")[0]+"] using credentials: ["+$VCAdmin.UserName+"@"+$Domain+"]."
            $ProgressStatus="Retrieving PowerState for ["+$VMGuest.VMGuestNames+"]."
            Write-Progress -Activity $ProgressHeader -Status $ProgressStatus -Completed;Start-Sleep -Seconds 1
            $NetBIOS=($VMGuest.VMGuestNames.Split(".")[0])
            $VMGuestInfo=Get-VM|Where-Object{$_.Name -like($NetBIOS+"*")}|Select-Object Name,PowerState
            $VMHostName=($VMGuestInfo.Name)
            $VMPowerState=($VMGuestInfo.PowerState)
            $NewRow=[PSCustomObject]@{'VMGuest'=$VMHostName;'PowerState'=$VMPowerState;'Guest IP'=$VMGuest.VMGuestIPv4;'Port Check'=$VMGuest.PortTest}
            $RowData.Add($NewRow)|Out-Null
            $Message=$ProgressStatus+$NewRow|Out-File ($LogLocation+"\Current_IP_"+$LogDate+".log") -Append
            $NewRow=$null
            $intVMGuest++
        }
    }
    End{
        Disconnect-VIServer $ServerData.VCManagerServer -Force:$true -Confirm:$false
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
        $TestPort=new-object -comobject wscript.shell 
        $intAnswer=$TestPort.popup($Message,$TimeOut,$Title,0)
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
    #Value  Description   
    #0 Show OK button. 
    #1 Show OK and Cancel buttons. 
    #2 Show Abort, Retry, and Ignore buttons. 
    #3 Show Yes, No, and Cancel buttons. 
    #4 Show Yes and No buttons. 
    #5 Show Retry and Cancel buttons. 
    #  http://msdn.microsoft.com/en-us/library/x83z1d9f(v=vs.84).aspx
    $Responce=new-object -comobject wscript.shell 
    $intAnswer=$Responce.popup($Message,0,$Title,0) #first number is timeout, second is display.
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
    Set-PowerCLIConfiguration -Scope Session -ParticipateInCEIP $false -DisplayDeprecationWarnings $false -Confirm:$false|Out-Null
    LoadModules
    Write-Progress -Activity $loadingActivity -Completed
    Clear-Host;Clear-History
    Switch($DomainUser){
        {($_-like"sy100*")-or($_-like"sy600*")}{Break}
        Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
    }
    $SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain($Domain).Split(".")[0]
    If(!($SecureCredentials)){$SecureCredentials=Get-Credential}
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
                $ProgressStatus=""
                $Hostname=($DataEntry+"*")
                $Hostname=(Get-ADComputer -Filter {DNSHostname -like $Hostname} -Properties Name,IPv4Address,OperatingSystem|Sort-Object Name|Select-Object DNSHostName,IPv4Address,OperatingSystem)
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
                        $DNSHostName=(($VMGuest.DNSHostName).Split(".")[0]+".*")
                        If($VMGuest.IPv4Address){
                            If($TelnetPort-ne0){
                                $PortResults=Test-NetConnection -ComputerName $VMGuest.DNSHostName -Port $TelnetPort -InformationLevel "Detailed"
                                If($PortResults.RemotePort-eq$TelnetPort){
                                    If($PortResults.TcpTestSucceeded-eq$true){
                                        $PortTest="Open"
                                    }Else{
                                        $PortTest="Closed"
                                    }
                                }
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
                            $ProgressHeader="Beginning to process the VM's that are assigned to: ["+$VCManager+"]."
                            $ProgressStatus="  VM Guest: ["+$VMGuest.DNSHostName+"] is assigned IP Address: ["+$VMGuest.IPv4Address+"]."
                        }Else{
                            $ProgressHeader="The computer being processed doesn't have an IP Address!"
                            $ProgressStatus="  ["+$VMGuest.DNSHostName+"] could verify the assignment to VCenter Manager site."
                            $Message=$ProgressHeader+$ProgressStatus|Out-File ($LogLocation+"\Missing_IP_"+$LogDate+".log") -Append
                        }
                        Write-Progress -Activity $ProgressHeader -Status $ProgressStatus;Start-Sleep -Seconds 1
                    }
                    Do{
                        If($intCounter-eq0){
                            If($HeadersSiteA){
                                $ProgressHeader="Beginning to process the VM's that are assigned to: ["+($HeadersSiteA.VCManagerServer).Split("")[0]+"]."
                                $ProgressStatus="Currently working on the first of ["+$VMCounter+"] system search matches."
                                Write-Progress -Activity $ProgressHeader -Status $ProgressStatus;Start-Sleep -Seconds 5
                                $VMResults=Get-VMStatus -ServerData $HeadersSiteA -VCAdmin $SecureCredentials
                            }
                        }
                        If($intCounter-eq1){
                            If($HeadersSiteB){
                                $ProgressHeader="Beginning to process the VM's that are assigned to: ["+($HeadersSiteB.VCManagerServer).Split("")[0]+"]."
                                $ProgressStatus="Currently working on the remaining ["+($VMCounter-$ProgressLoop)+"] system search matches."
                                Write-Progress -Activity $ProgressHeader -Status $ProgressStatus;Start-Sleep -Seconds 5
                                $VMResults=Get-VMStatus -ServerData $HeadersSiteB -VCAdmin $SecureCredentials
                            }
                        }
                        If(!($VMResults.VMGuest-eq$null)-or(!($VMResults.VMGuest-eq""))){
                            ForEach($VMGuestInfo In $VMResults){
                                $ProgressLoop++
                                $ProgressStatus="Currently working on ["+$ProgressLoop+"] of the ["+$VMCounter+"] system search matches."
                                $ProgressHeader="Processing the ["+$VMCounter+"] system that were found that match the search value ["+$DataEntry+"] you entered."
                                Write-Progress -Activity $ProgressHeader -Status $ProgressStatus -PercentComplete($ProgressLoop/$VMCounter*100);Start-Sleep -Seconds 1
                                $VMHostName=($VMGuestInfo.VMGuest)
                                $VMPowerState=($VMGuestInfo.PowerState)
                                $NewRow=[PSCustomObject]@{'VMGuest'=$VMHostName;'PowerState'=$VMPowerState}
                                $VMHeaders.Add($NewRow)|Out-Null
                                $NewRow=$null
                                If($VMPowerState-eq"PoweredOff"){
                                    $Message=("["+$VMHostName+"] is currently ["+$VMPowerState+"].  Do you want to power it on?")
                                    $Title="VMGuest powered off!"
                                    $PowerState=new-object -comobject wscript.shell 
                                    $intAnswer=$PowerState.popup($Message,$TimeOut,$Title,4)
                                    If($DefaultAnswer-eq$false){
                                        $intAnswer="No"
                                    }Else{
                                        $intAnswer="Yes"
                                    }
                                    Switch($intAnswer){
                                        6{$Response="No";Break}
                                        7{$Response="Yes";Break}
                                        Default{$Response=$DefaultAnswer;Break}
                                    }
                                    If($Response-eq"Yes"){
                                        Switch($intCounter){
                                            0{$VCManagerServer=$VCMgrSiteA.ComputerName;Break}
                                            1{$VCManagerServer=$VCMgrSiteB.ComputerName;Break}
                                        }
                                        Connect-VIServer $VCManagerServer -Credential $SecureCredentials|Out-Null
                                        Start-VM -VM $VMHostName -Confirm:$false -RunAsync
                                        Disconnect-VIServer $VCManagerServer -Force:$true -Confirm:$false|Out-Null
                                    }
                                }
                            }
                        }
                        $intCounter++
                    }Until($intCounter-ge2)
                    Write-Progress -Activity $ProgressHeader -Status $ProgressStatus -Completed
                    Clear-History;Clear-Host
                    $VMHeaders|Format-List -Property VMGuest,PowerState
                    $ComputerName=""
                }
                Break
            }
        }
    }Until($DataEntry.ToLower()-eq"exit")
    Set-Location $System32
}
$ProgressPreference=$OriginalPreference