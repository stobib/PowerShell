Clear-Host;Clear-History
Import-Module ProcessCredentials
$Global:SiteCodes=@("A","B")
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
            $CsvHeaders|Select-Object -Property "Name","State","LastBootTime","Provisioned Space","Used Space","Host","Guest OS","Memory Size","CPUs","IP Address","VMware Tools","Version Status","DNS Name","Encryption","Datacenter","Cluster","Computer Type"|Export-Csv -LiteralPath $ExportFile -NoTypeInformation
            Import-Csv ($WorkingPath+"\"+$WorkingCSV)|ForEach-Object{
                $VMCount++
                $VMName=$_.Name
                $IPAddress=""
                $DataCenter=""
                $Cluster=""
                $VMLabel=Get-View -Filter @{"Name"="^$VMName$"} -ViewType VirtualMachine -Property Name,Summary.QuickStats.UptimeSeconds|Select-Object Name,$LastBootProp
                ForEach($VM In $VMLabel){
                    [System.Net.IPAddress]$IPAddress=@()
                    If($_.Name-eq$VM.Name){
                        $FQDN=((Get-VM $_.Name).Guest.HostName).ToLower()
                        Write-Host ("Beginning to process: "+$FQDN)
                        $VMStatus=Get-View -ViewType Virtualmachine|Where-Object{$_.Name-like($VM.Name)}|Select-Object *
                        $xA=$VMStatus.Name
                        $xB=$VMStatus.Summary.Runtime.PowerState
                        $xC=$VMLabel.LastBootTime
                        $xD=[math]::Round(($VMStatus.Summary.Storage.Committed+$VMStatus.Summary.Storage.UnCommitted)/1GB,2)
                        $xE=[math]::Round($VMStatus.Summary.Storage.Committed/1GB,2)
                        $xF=Get-View -Id $VMStatus.Runtime.Host -Property Name|Select-Object -ExpandProperty Name
                        $xG=$VMStatus.Guest.GuestFullName
                        $xH=$VMStatus.Summary.Config.MemorySizeMB
                        $xI=$VMStatus.Summary.Config.NumCpu
                        $xJ=$VMStatus.Guest.IPAddress
                        Switch($xL.Split(".")[1]){
                            {$_-eq"118"}{$DataCenter="SITE-A-ARDC";$Cluster="MGT-A";Break}
                            Default{$DataCenter="SITE-B-UDCC";$Cluster="VDI-B";Break}
                        }
                        $xK=$VMStatus.Guest.ToolsVersion
                        $xL=$VMStatus.Guest.GuestState
                        $xM=$VMStatus.Guest.HostName
                        $xN="No"
                        $xO=$DataCenter
                        $xP=$Cluster
                        $xQ=$VMStatus.MoRef.Type
                        $AppendRow=($xA+","+$xB+","+$xC+","+$xD+","+$xE+","+$xF+","+$xG+","+$xH+","+$xI+","+$xJ+","+$xK+","+$xL+","+$xM+","+$xN+","+$xO+","+$xP+","+$xQ)
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
        $Reason+=("Failed to begin processing script because "+$Reason+".")
        $Reason|Out-File $LogFile -Append
        Write-Host $Reason -ForegroundColor Yellow -BackgroundColor DarkRed
    }
    $Message=$null;$Reason=$null;$VMProcessed=0;$VMCount=0;$EXcount=0;$POCount=0
    Rename-Item -Path ($ProcessList) -NewName "ProcessedList.txt" -Force
}
Disconnect-VIServer -Server $vSphere -Force
Set-Location ($env:SystemRoot+"\System32")