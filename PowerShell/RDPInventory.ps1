Clear-Host;Clear-History
Import-Module ProcessCredentials
$Global:Separator="________________________________________________________________________________________________________________________"
$Global:ResetHost=@();$ResetHost=""
$Global:SiteCodes=@("A","B")
$Global:FailedToConnect=@();$FailedToConnect=""
$Global:PortNotListening=@();$PortNotListening=""
$Global:ExcludedFolders=@(
    "Excluded",
    "Retired",
    "Templates",
    "UTD IaaS (Root)",
    "RPA-INF (Support)",
    "RPA-NON (Dev)",
    "RPA-NRP (Tst)",
    "RPA-PRD (Prd)",
    "Templates (RPA-VDI Images)"
)
$Global:Domain=("utshare.local")
$Global:DomainUser=(($env:USERNAME+"@"+$Domain).ToLower())
$ScriptPath=$MyInvocation.MyCommand.Definition
$ScriptName=$MyInvocation.MyCommand.Name
$Global:WorkingPath=($env:USERPROFILE+"\Desktop\"+($ScriptName.Split(".")[0]))
If(!(Test-Path -Path $WorkingPath)){New-Item -Path $WorkingPath -ItemType Directory}
$ErrorActionPreference='SilentlyContinue'
Set-Location ($ScriptPath.Replace($ScriptName,""))
Set-Variable -Name SecureCredentials -Value $null
Set-Variable -Name LogName -Value ($ScriptName.Replace("ps1","log"))
Set-Variable -Name LogFile -Value ($WorkingPath+"\"+$LogName)
Set-Variable -Name TempFile -Value ($env:TEMP+"\"+$LogName)
Set-Variable -Name WorkingCSV -Value ($ScriptName.Replace(".ps1","_RAW.csv"))
Set-Variable -Name WorkCSVFile -Value ($WorkingPath+"\"+$WorkingCSV)
Set-Variable -Name ExportCSV -Value ($ScriptName.Replace("ps1","csv"))
Set-Variable -Name ExportFile -Value ($WorkingPath+"\"+$ExportCSV)
Set-Variable -Name MailServer -Value ("mail.utshare.utsystem.edu")
Set-Variable -Name EndTime -Value $null
Set-Variable -Name vSphere -Value $null
Set-Variable -Name EmailTo -Value $null
Set-Variable -Name SendTo -Value $null
Set-Variable -Name Sender -Value $null
Function LoadModules(){
   ReportStartOfActivity "Searching for $ProductShortName module components..."
   $Loaded=Get-Module -Name $ModuleList -ErrorAction Ignore|ForEach-Object {$_.Name}
   $Registered=Get-Module -Name $ModuleList -ListAvailable -ErrorAction Ignore|ForEach-Object {$_.Name}
   ReportFinishedActivity
   Foreach($Module In $Registered){
      If($Loaded -notcontains $Module){
		 ReportStartOfActivity "Loading module $Module"
		 Import-Module $Module
		 ReportFinishedActivity
      }
   }
}
Function ReportStartOfActivity($Activity){
   $Script:CurrentActivity=$Activity
   Write-Progress -Activity $LoadingActivity -CurrentOperation $Script:CurrentActivity -PercentComplete $Script:PercentComplete
}
Function ReportFinishedActivity(){
   $Script:CompletedActivities++
   $Script:PercentComplete=(100.0/$TotalActivities)*$Script:CompletedActivities
   $Script:PercentComplete=[Math]::Min(99,$PercentComplete)
   Write-Progress -Activity $LoadingActivity -CurrentOperation $Script:CurrentActivity -PercentComplete $Script:PercentComplete
}
Function ResolveIPAddress{Param([IPAddress][Parameter(Mandatory=$True)]$IP,[Parameter(Mandatory=$True)]$FQDN)
    $SubDomain=($FQDN.Split(".")[1])    
    Try{
        If($IP-eq0.0.0.0){
            $AddressList=([System.Net.Dns]::GetHostEntry($FQDN).AddressList)
            $IP=$AddressList.IPAddressToString
            $1st=($IP.Split(".")[0]);$2nd=($IP.Split(".")[1]);$3rd=($IP.Split(".")[2]);$4th=($IP.Split(".")[3])
            $ReverseZone=($3rd+"."+$2nd+"."+$1st+".in-addr.arpa")
            Add-DnsServerResourceRecordPtr -Name ($4th) -ZoneName ($ReverseZone) -AllowUpdateAny -TimeToLive 01:00:00 -AgeRecord -PtrDomainName $FQDN
            Return $AddressList
        }Else{
            $ComputerName=[System.Net.Dns]::GetHostEntry($IP).HostName
            Return ($ComputerName.ToLower())
        }
    }Catch{
        $FQDN=($NetBIOS+"."+$SubDomain+"."+$Domain).ToLower()
        If($_.Exception.Message-eq'Exception calling "GetHostByAddress" with "1" argument(s): "The requested name is valid, but no data of the requested type was found"'){
            $1st=($IP.Split(".")[0]);$2nd=($IP.Split(".")[1]);$3rd=($IP.Split(".")[2]);$4th=($IP.Split(".")[3])
            $ReverseZone=($3rd+"."+$2nd+"."+$1st+".in-addr.arpa")
            Add-DnsServerResourceRecordPtr -Name ($4th) -ZoneName ($ReverseZone) -AllowUpdateAny -TimeToLive 01:00:00 -AgeRecord -PtrDomainName $FQDN
        }ElseIf($_.Exception.Message-eq'Exception calling "GetHostByName" with "1" argument(s): "No such host is known"'){
            $ForwardZone=(($FQDN.Split(".")[1])+"."+$Domain).ToLower()
            Add-DnsServerResourceRecordA -Name $ComputerName -ZoneName ($ForwardZone) -AllowUpdateAny -IPv4Address $IP -TimeToLive 01:00:00 -CreatePtr
        }Else{
            Write-Host $_.Exception.Message -ForegroundColor Green
        }
    }
}
Function Test-OpenPort{[CmdletBinding()]Param([Parameter(Position=0)]$Target='localhost', 
[Parameter(Mandatory=$True,Position=1,Helpmessage='Enter Port Numbers. Separate them by comma.')]$Port)
    $Result=@()
    ForEach($T In $Target){
        ForEach($P In $Port){
            $A=Test-NetConnection -ComputerName $T -Port $P -WarningAction SilentlyContinue
            $Result+=New-Object -TypeName PSObject -Property ([ordered]@{'Target'=$A.ComputerName;'RemoteAddress'=$A.RemoteAddress;'Port'=$A.RemotePort;'Status'=$A.tcpTestSucceeded})
        }
    }
    Return $Result
}
Switch($DomainUser){
    {($_-like"sy10*")-or($_-like"sy60*")}{Break}
    Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
}
$SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain ($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=get-credential}
#Load PowerCli Context
$Script:PromptForCEIP=$false
$ModuleList=@(
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
$ProductName="PowerCli"
$ProductShortName="PowerCli"
$LoadingActivity="Loading $ProductName"
$Script:CompletedActivities=0
$Script:PercentComplete=0
$Script:Validate=$null
$Script:CurrentActivity=""
$Script:ServerList="ServerList.txt"
$Script:ProcessList=($WorkingPath+"\"+$ServerList)
$Script:totalActivities=$ModuleList.Count+1
$Script:PortNotListening=@();$PortNotListening=""
$Script:FailedToConnect=@();$FailedToConnect=""
LoadModules
$PowerCliFriendlyVersion=[VMware.VimAutomation.Sdk.Util10.ProductInfo]::PowerCliFriendlyVersion
$Host.ui.RawUI.WindowTitle=$PowerCliFriendlyVersion
Try{
	$configuration=Get-PowerCliConfiguration -Scope Session
	If($PromptForCEIP-and!($configuration.ParticipateInCEIP)-and[VMware.VimAutomation.Sdk.Util10Ps.CommonUtil]::InInteractiveMode($Host.UI)){
		$caption="Participate in VMware Customer Experience Improvement Program (CEIP)"
		$Message=`
			"VMware's Customer Experience Improvement Program (`"CEIP`") provides VMware with information "+
			"that enables VMware to improve its Products and services, to fix problems, and to advise you "+
			"on how best to deploy and use our Products.  As part of the CEIP, VMware collects technical information "+
			"about your organization’s use of VMware Products and services on a regular basis in association "+
			"with your organization’s VMware license key(s).  This information does not personally identify "+
			"any individual."+
			"`n`nFor more details: press Ctrl+C to exit this prompt and type `"help about_ceip`" to see the related help article."+
			"`n`nYou can join or leave the program at any time by executing: Set-PowerCliConfiguration -Scope User -ParticipateInCEIP `$true or `$false."
		$AcceptLabel="&Join"
		$choices=(
			(New-Object -TypeName "System.Management.Automation.Host.ChoiceDescription" -ArgumentList $AcceptLabel,"Participate in the CEIP"),
			(New-Object -TypeName "System.Management.Automation.Host.ChoiceDescription" -ArgumentList "&Leave","Don`t participate")
		)
		$userChoiceIndex = $Host.UI.PromptForChoice($caption, $Message, $choices, 0)
		$participate = $choices[$userChoiceIndex].Label -eq $AcceptLabel
		If($participate){
            [VMware.VimAutomation.Sdk.Interop.V1.CoreServiceFactory]::CoreService.CeipService.JoinCeipProgram();
        }Else{
            Set-PowerCliConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
        }
    }
}Catch{}
Write-Progress -Activity $LoadingActivity -Completed
#Connect vSphere
ForEach($Site In $SiteCodes){
    $Script:StartTime=(Get-Date)
    $vSphere=("vcmgr01"+$Site+".inf."+$Domain).ToLower()
    $Validate=Connect-VIServer -Server $vSphere -credential $SecureCredentials
    $LastBootProp=@{Name='LastBootTime';Expression={(Get-Date)-(New-TimeSpan -Seconds $_.Summary.QuickStats.UptimeSeconds)}}
    If($Validate){
        If($Site-eq"B"){
            $Script:VMCount=0
            $Script:CsvHeaders=""
            $Script:AppendRow=""
            $Script:DataCenter=""
            $Script:Cluster=""
            $Reason=("["+$SecureCredentials.UserName+"] was successfully connected to: ["+$vSphere+"]")
            Write-Host ("Beginning to process script because "+$Reason+".") -ForegroundColor Cyan -BackgroundColor DarkBlue
            Get-VM|Select-Object Name,Guest,Folder|Where-Object {($_.Guest-Like"*Windows 10*")-or($_.Guest-Like"win10*")-or($_.Guest-Like"w10*")}|Where-Object {$_.Folder-notlike"*RPA*"}|Sort Name|Export-Csv -Path ($WorkingPath+"\"+$WorkingCSV) �NoTypeInformation
            $CsvHeaders|Select-Object -Property "Name","State","Status","Provisioned Space","Used Space","Host CPU","Host Mem","Host","Guest OS","Memory Size","CPUs","IP Address","VMware Tools","Version Status","DNS Name","Encryption","Datacenter","Cluster","Computer Type"|Export-Csv -LiteralPath $ExportFile -NoTypeInformation
            Import-Csv ($WorkingPath+"\"+$WorkingCSV)|ForEach-Object{
                $VMCount++
                $IPAddress=""
                $DataCenter=""
                $Cluster=""
                $VMName=$_.Name
                $VMLabel=Get-View -Filter @{"Name"="^$VMName$"} -ViewType VirtualMachine -Property Name,Summary.QuickStats.UptimeSeconds|Select-Object Name,$LastBootProp
                ForEach($VM In $VMLabel){
                    [System.Net.IPAddress]$IPAddress=@()
                    If(Test-Path -Path $TempFile){Remove-Item $TempFile}
                    If($_.Name-eq$VM.Name){
                        $FQDN=((Get-VM $_.Name).Guest.HostName).ToLower()
                        Write-Host ("Beginning to process: "+$FQDN)
                        $VMStatus=Get-VM|Where-Object{$_.Name-like($VM.Name)}|Select-Object *
                        $xA=$VMStatus.Name
                        $xB=$VMStatus.PowerState
                        $xC=$VMStatus.Guest.State
                        $xD=$VMStatus.ProvisionedSpaceGB
                        $xE=$VMStatus.UsedSpaceGB
                        $xF=$VMStatus.Host.NumCpu
                        $xG=$VMStatus.Host.MemoryTotalGB
                        $xH=$VMStatus.Host.Name
                        $xI=$VMStatus.Guest.OSFullName
                        $xJ=$VMStatus.MemoryGB
                        $xK=$VMStatus.NumCpu
                        $xL=$VMStatus.Guest.IPAddress
                        Switch($xL.Split(".")[1]){
                            {$_-eq"118"}{$DataCenter="SITE-A-ARDC";$Cluster="MGT-A";Break}
                            Default{$DataCenter="SITE-B-UDCC";$Cluster="VDI-B";Break}
                        }
                        $xM=$VMStatus.ExtensionData.Client.Version
                        $xN=$VMStatus.Guest.State
                        $xO=$FQDN
                        $xP="No"
                        $xQ=$DataCenter
                        $xR=$Cluster
                        $xS=$VMStatus.ExtensionData.MoRef.Type
                        $AppendRow=($xA+","+$xB+","+$xC+","+$xD+","+$xE+","+$xF+","+$xG+","+$xH+","+$xI+","+$xJ+","+$xK+","+$xL+","+$xM+","+$xN+","+$xO+","+$xP+","+$xQ+","+$xR+","+$xS)
                        $AppendRow|Out-File $ExportFile -Append
                        $AppendRow=""
                    }
                }
            }
            $AttachmentList=$null
            $Sender=($vSphere.Split(".")[0]+"@"+$Domain)
            $EmailTo=("dschaubert@utsystem.edu")
            $SendTo=("Schaubert, Derek <$($EmailTo)>")
            $Message=("Start Time: "+$StartTime+"`n`n")
            $Message+=("The ["+$ExportCSV+"] file contains a list of ["+$VMCount+"] RDP Systems that were processed from vSphere inventory.")
            $Message+=("`n`nEnd Time: "+(Get-Date))
            $AttachmentList=@($ExportFile)
            Send-MailMessage -From "<$($Sender)>" -To $SendTo -Subject ("Summary of VMWare RDP systems from vSphere") -Body $Message -Attachments $AttachmentList -SmtpServer $MailServer
        }
    }Else{
        $Reason=("["+$SecureCredentials.UserName+"] was unable to connect to: ["+$vSphere+"]")
        ("Failed to begin processing script because "+$Reason+".")|Out-File $LogFile -Append
        Write-Host ("Failed to beginning process script because "+$Reason+".") -ForegroundColor Yellow -BackgroundColor DarkRed
    }
    $Message=$null;$Reason=$null;$VMProcessed=0;$VMCount=0;$EXcount=0;$POCount=0
    Rename-Item -Path ($ProcessList) -NewName "ProcessedList.txt" -Force
}
Disconnect-VIServer -Server $vSphere -Force
Set-Location ($env:SystemRoot+"\System32")