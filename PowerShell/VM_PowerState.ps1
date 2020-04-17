Clear-Host;Clear-History
Import-Module ActiveDirectory
Import-Module ProcessCredentials
$Global:Domain = ($env:USERDNSDOMAIN.ToLower())
Set-Variable -Name VCMgrSrvList -Value @('vcmgra01.inf','vcmgrb01.inf')
$Global:SecureCredentials = $null
Clear-History;Clear-Host
$Global:DataEntry = ""
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
$moduleList = @(
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
$productName = "PowerCLI"
$productShortName = "PowerCLI"
$loadingActivity = ("Loading ["+$productName+"]")
$script:completedActivities = 0
$script:percentComplete = 0
$script:currentActivity = ""
$script:totalActivities = $moduleList.Count + 1
Function Get-VMStatus{
    Param(
        [Parameter(Mandatory=$true)][Alias("ComputerName")][string]$Name = '*',
        [Parameter(Mandatory=$true)][Alias("vCenterHost")][string]$Server = $null,
        [Parameter(Mandatory=$true)][Alias("vCenterAdmin")][PSCredential]$VCAdmin = $null
    )
    Begin{
        If($Server -ne $null){
            Connect-VIServer $Server -Credential $VCAdmin|Out-Null
            Clear-Host
        }
    }
    Process{
        $vms = Get-VM|Where-Object{$_.Name -like ($Name+"*")}|Select-Object Name,PowerState
    }
    End{
        Disconnect-VIServer $Server -Force:$true -Confirm:$false
        Return ($vms)
    }
}
Function LoadModules(){
    ReportStartOfActivity ("Searching for ["+$productShortName+"] module components...")
    $loaded = Get-Module -Name $moduleList -ErrorAction Ignore | % {$_.Name}
    $registered = Get-Module -Name $moduleList -ListAvailable -ErrorAction Ignore | % {$_.Name}
    $notLoaded = $registered | ? {$loaded -notcontains $_}
    ReportFinishedActivity
    Foreach($module in $registered){
        If($loaded -notcontains $module){
            ReportStartOfActivity ("Loading module ["+$module+"].")
            Import-Module $module
            ReportFinishedActivity
        }
    }
}
Function ReportFinishedActivity(){
    $script:completedActivities++
    $script:percentComplete = (100.0 / $totalActivities) * $script:completedActivities
    $script:percentComplete = [Math]::Min(99, $percentComplete)
    Write-Progress -Activity $loadingActivity -CurrentOperation $script:currentActivity -PercentComplete $script:percentComplete
}
Function ReportStartOfActivity($activity){
    $script:currentActivity = $activity
    Write-Progress -Activity $loadingActivity -CurrentOperation $script:currentActivity -PercentComplete $script:percentComplete
}
LoadModules
Write-Progress -Activity $loadingActivity -Completed
Switch($DomainUser){
    {($_-like"sy100*")-or($_-like"sy600*")}{Break}
    Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
}
$SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain ($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=Get-Credential}
Do{
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'VM PowerState'
    $form.Size = New-Object System.Drawing.Size($FormWidth,$FormHeight)
    $form.StartPosition = 'CenterScreen'

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point($ButtonLeft,($ButtonTop))
    $okButton.Size = New-Object System.Drawing.Size($ButtonWidth,$ButtonHeight)
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(($ButtonLeft+$ButtonWidth),($ButtonTop))
    $cancelButton.Size = New-Object System.Drawing.Size($ButtonWidth,$ButtonHeight)
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point($LabelLeft,$LabelTop)
    $label.Size = New-Object System.Drawing.Size($LabelWidth,$LabelHeight)
    $label.Text = 'Please enter the hostname of the computer.'
    $form.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point($LabelLeft,$TextboxTop)
    $textBox.Size = New-Object System.Drawing.Size($LabelWidth,$LabelHeight)
    $form.Controls.Add($textBox)

    $form.Topmost = $true

    $form.Add_Shown({$textBox.Select()})
    $result = $form.ShowDialog()
    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){
        $DataEntry = "exit"
    }

    If($result -eq [System.Windows.Forms.DialogResult]::OK){
        $Hostname = ""
        $DataEntry = $textBox.Text
        Switch(($DataEntry).ToLower()){
            {($_-eq"exit")}{
                Break
            }
            {($_.Length-eq0)-or($_-contains" ")}{
                $Message=("The value that you entered ["+$DataEntry+"] didn't return a valid active computer in the ["+$Domain+"] domain.")
                [System.Windows.MessageBox]::Show($Message,'Hostname not found!','Ok','Error')
                Clear-History;Clear-Host
                Break
            }
            Default{
                $VMResults = $null
                $VMHostName = @()
                $VMPowerState = @()
                $Connected = $false
                $Hostname = ($DataEntry+"*")
                $Hostname = (Get-ADComputer -Filter {DNSHostname -like $Hostname} -Properties Name,IPv4Address,OperatingSystem|Sort-Object Name|Select-Object DNSHostName,IPv4Address,OperatingSystem)
                If($Hostname){
                    If($VCMgrSrv-eq""){
                        ForEach($VCMgrSite In $VCMgrSrvList){
                            $Server = ($VCMgrSite+"."+$Domain)
                            $Return = Test-NetConnection -ComputerName $Server
                            If($Return.PingSucceeded -eq $True){
                                If($Return.RemoteAddress-like"10.118.*"){
                                    $VCMgrSiteA=$Return
                                }Else{
                                    $VCMgrSiteB=$Return
                                }
                                Clear-Host
                            }
                        }
                    }
                    [System.Collections.ArrayList]$VMHeaders=@()
                    ForEach($VMGuest In $Hostname){
                        $DNSHostName = (($VMGuest.DNSHostName).Split(".")[0]+".*")
                        If($VMGuest.IPv4Address-like"10.118.*"){
                            $VCMgrSrv=$VCMgrSiteA
                        }Else{
                            $VCMgrSrv=$VCMgrSiteB
                        }
                        $VMResults=Get-VMStatus -Name $DNSHostName -Server $VCMgrSrv.ComputerName -VCAdmin $SecureCredentials
                        $VMHostName=($VMResults.Name)
                        $VMPowerState=($VMResults.PowerState)
                        $NewRow=[PSCustomObject]@{'VMGuest'=$VMHostName;'PowerState'=$VMPowerState}
                        $VMHeaders.Add($NewRow)|Out-Null
                        $NewRow=$null
                    }
                    $VMHeaders|Format-List -Property VMGuest,PowerState
                }
                Break
            }
        }
    }
}Until($DataEntry.ToLower()-eq"exit")
