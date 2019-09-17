Clear-Host;Clear-History
$Global:Separator="________________________________________________________________________________________________________________________"
$Global:ResetHost=@()
$Global:Validate=$null
$Global:SiteCode="A"
$Global:Domain=("utshare.local")
$Global:DomainUser=(($env:USERNAME+"@"+$Domain).ToLower())
$Global:ExcludedFolders=@("Retired","Templates","UTD IaaS (Root)")
$ScriptPath=$MyInvocation.MyCommand.Definition
$ScriptName=$MyInvocation.MyCommand.Name
$ErrorActionPreference='SilentlyContinue'
Set-Location ($ScriptPath.Replace($ScriptName,""))
Set-Variable -Name DateTime -Value (Get-Date)
Set-Variable -Name SecureCredentials -Value $null
Set-Variable -Name vSphere -Value ("vcmgr01"+$SiteCode+".inf."+$Domain).ToLower()
Set-Variable -Name LogName -Value ($ScriptName.Replace("ps1","log"))
Set-Variable -Name LogFile -Value ($env:USERPROFILE+"\Desktop\"+$LogName)
Set-Variable -Name TempFile -Value ($env:TEMP+"\"+$LogName)
Set-Variable -Name ExcludedName -Value ("ExcludedSystems.log")
Set-Variable -Name ExcludedFile -Value ($env:USERPROFILE+"\Desktop\"+$ExcludedName)
Set-Variable -Name PoweredOffName -Value ("PoweredOff.log")
Set-Variable -Name PoweredOffFile -Value ($env:USERPROFILE+"\Desktop\"+$PoweredOffName)
Set-Variable -Name MailServer -Value ("mail.utshare.utsystem.edu")
#Set-Variable -Name SendTo -Value ("GRP-SIS_SysAdmin@utsystem.edu")
Set-Variable -Name SendTo -Value ("bstobie@utsystem.edu")
Set-Variable -Name EndTime -Value $null
Set-Variable -Name Sender -Value $null
Function LoadModules(){
   ReportStartOfActivity "Searching for $ProductShortName module components..."
   $Loaded=Get-Module -Name $ModuleList -ErrorAction Ignore|ForEach-Object{$_.Name}
   $Registered=Get-Module -Name $ModuleList -ListAvailable -ErrorAction Ignore|ForEach-Object{$_.Name}
   $NotLoaded=$Registered|Where-Object{$Loaded -notcontains $_}
   ReportFinishedActivity
   Foreach($Module In $Registered){
      If($Loaded -notcontains $Module){
		 ReportStartOfActivity "Loading module $Module"
		 Import-Module $Module
		 ReportFinishedActivity
      }
   }
}
Function Protect-String{[CmdletBinding()]param([String][Parameter(Mandatory=$True)]$String,[String][Parameter(Mandatory=$True)]$Key)
    Begin{}
    Process{      
        If(([System.Text.Encoding]::Unicode).GetByteCount($Key)*8-notin128,192,256){
            Throw "Given encryption key has an invalid length.  The specified key must have a length of 128, 192, or 256 bits."
        }
        $SecureKey=ConvertTo-SecureString -String $Key -AsPlainText -Force
        Return ConvertTo-SecureString $String -AsPlainText -Force|ConvertFrom-SecureString -SecureKey $SecureKey
    }
    End{}
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
Function SetCredentials{[CmdletBinding()]Param([String][Parameter(Mandatory=$True)]$SecureUser,[String][Parameter(Mandatory=$True)]$Domain)
    Set-Variable -Name WorkingPath -Value ($($env:USERProfile)+"\AppData\Local\Credentials\"+$($Domain))
    Set-Variable -Name SecureFile -Value ("$WorkingPath\"+$($SecureUser.Split("@")[0])+".pwd")
    If(Test-Path -Path $SecureFile){
        Set-Variable -Name Extensions -Value @("pwd","key")
        Set-Variable -Name KeyDate -Value $null
        Set-Variable -Name PwdDate -Value $null
        ForEach($FileType In $Extensions){
            $Results=Get-ChildItem -Path $WorkingPath
            $Extension=$($Results.Name).Split(".")[1]
            If($Extension-eq$FileType){
                $PwdDate=$($Results.CreationTime)[1]
                If($KeyDate.Date-ne$PwdDate.Date){
                    Set-Variable -Name SecureString -Value 0
                }Else{
                    $SecureString=Get-Content -Path $SecureFile|ConvertTo-SecureString -SecureKey $SecureKey -ErrorAction Stop
                    $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
                    $Validate=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                }
            }Else{
                $KeyDate=$($Results.CreationTime)[0]
                $KeyName=$($Results.Name).Split(".")[0]
                If(([System.Text.Encoding]::Unicode).GetByteCount($KeyName)*8-notin"128,192,256"){
                    $EncryptionKeyFile="$WorkingPath\$KeyName.$Extension"
                    $SecureKey=ConvertTo-SecureString -String $KeyName -AsPlainText -Force
                    $PrivateKey=Get-Content -Path $EncryptionKeyFile|ConvertTo-SecureString -SecureKey $SecureKey
                    $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PrivateKey)
                    $UnEncrypted=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                }
            }
        }
    }Else{
        $SecureString=Read-Host -Prompt "Enter your [$SecureUser] credentials" -AsSecureString
        $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        $Encrypted=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        Set-Variable -Name "EncryptionKeyFile" -Value ""
        Set-Variable -Name "Characters" -Value ""
        Set-Variable -Name "PrivateKey" -Value ""
        Set-Variable -Name "SecureKey" -Value ""
        [String]$Key=0
        [Int]$Min=8
        [Int]$Max=1024
        $Prompt="Enter the length you want to use for the security key: [8, 12, or 16]"
        If($Prompt.Length-eq0){$Prompt=8}
        [Int]$RandomKey=Read-Host -Prompt $Prompt
        If(Test-Path $WorkingPath){
            $Results=Get-ChildItem -Path $WorkingPath -File
            ForEach($File In $Results){
                $FileName=$($File.Name).Split(".")[0]
                If($FileName.length-eq$RandomKey){
                    $KeyFile="$($File.Name)"
                    $Key=$($KeyFile).Split(".")[0]
                    If(([System.Text.Encoding]::Unicode).GetByteCount($Key)*8-notin"128,192,256"){
                        $EncryptionKeyFile="$WorkingPath\$KeyFile"
                        $SecureKey=ConvertTo-SecureString -String $Key -AsPlainText -Force
                        $PrivateKey=Get-Content -Path $EncryptionKeyFile|ConvertTo-SecureString -SecureKey $SecureKey
                        $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PrivateKey)
                        $UnEncrypted=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                        Break
                    }
                }
            }
        }Else{
            MkDir $WorkingPath
        }
        If($PrivateKey.length-lt1){
            Do{
                Switch($RandomKey){
                    {($_-eq8)}{
                        $Key=-join((48..57)|Get-Random -Count 4|ForEach-Object{[char]$_})
                        $Key+=-join((48..57)|Get-Random -Count 4|ForEach-Object{[char]$_})
                        Break
                    }
                    {($_-eq12)}{
                        $Key=-join((48..57)|Get-Random -Count 4|ForEach-Object{[char]$_})
                        $Key+=-join((48..57)|Get-Random -Count 4|ForEach-Object{[char]$_})
                        $Key+=-join((48..57)|Get-Random -Count 4|ForEach-Object{[char]$_})
                        Break
                    }
                    {($_-eq16)}{
                        $Key=-join((48..57)|Get-Random -Count 4|ForEach-Object{[char]$_})
                        $Key+=-join((48..57)|Get-Random -Count 4|ForEach-Object{[char]$_})
                        $Key+=-join((48..57)|Get-Random -Count 4|ForEach-Object{[char]$_})
                        $Key+=-join((48..57)|Get-Random -Count 4|ForEach-Object{[char]$_})
                        Break
                    }
                    {($Key.length-lt$RandomKey)}{
                        $RandomKey+=1
                        Break
                    }
                    {($Key.length-gt$RandomKey)}{
                        $RandomKey-=1
                        Break
                    }
                    Default{
                        $RandomKey=16
                        Break
                    }
                }
            }Until(($Key.length-eq8)-or($Key.length-eq12)-or($Key.length-eq16))
            $i=0
            Do{
                $i++
                If(Test-Path -Path $SecureFile){
                    $SecureFile="$WorkingPath\Encrypted$i.pwd"
                }
            }While((Test-Path -Path $SecureFile)-eq$True)
            $Prompt="Enter the amount of characters you want to use for the encryption key: [min $Min, max $Max]"
            Do{
                [Int]$Characters=Read-Host -Prompt $Prompt
                If(($Characters-ge$Min)-and($Characters-le$Max)){
                }Else{
                    $Prompt="Please enter a value between the minimum '$Min' and maximum '$Max' range"
                }
            }Until(($Characters-ge$Min)-and($Characters-le$Max))
            For($i=0;$i-le$Characters;$i++){
                Switch($i){
                    {($_-gt0)-and($_-le$Characters)}{$Set=-join((65..90)+(97..122)|Get-Random -Count 1|ForEach-Object{[Char]$_});Break}
                    Default{$PrivateKey="";$Set="";Break}
                }
                $PrivateKey+=$Set
            }
            Set-Variable -Name "EncryptionKeyFile" -Value "$WorkingPath\$Key.key"
            Protect-String $PrivateKey $Key|Out-File -Filepath $EncryptionKeyFile
            $Validate=Unprotect-String $PrivateKey $Key
            If($Validate-ne$False){
                $SecureKey=ConvertTo-SecureString -String $Key -AsPlainText -Force
            }Else{
                $SecureString=Read-Host -Prompt "Enter your [$SecureUser] credentials" -AsSecureString
            }
            $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
            $EncryptedString=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            $EncryptedString|ConvertTo-SecureString -AsPlainText -Force|ConvertFrom-SecureString -SecureKey $SecureKey|Out-File -FilePath $SecureFile
        }
        Try{
            $SecureString=Get-Content -Path $SecureFile|ConvertTo-SecureString -SecureKey $SecureKey -ErrorAction Stop
            $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
            $Validate=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            If($EncryptedString-ceq$Validate){}
        }Catch [Exception]{
            $Message="Error: [Validation]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Yellow -BackgroundColor DarkRed
            $EncryptedString=$null;$BSTR=$null
        }
    }
    $EncryptedString=$null;$BSTR=$null
    $Script:SecureCredentials=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SecureUser,$SecureString
    Return $Validate
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
Function Unprotect-String{[CmdletBinding()]param([String][Parameter(Mandatory=$True)]$String,[String][Parameter(Mandatory=$True)]$Key)
    Begin{}
    Process{
        If(([System.Text.Encoding]::Unicode).GetByteCount($Key)*8-notin128,192,256){
            Throw "Given encryption key has an invalid length.  The specified key must have a length of 128, 192, or 256 bits."
            Return $False
        }
        $SecureKey=ConvertTo-SecureString -String $Key -AsPlainText -Force
        $PrivateKey=Get-Content -Path $EncryptionKeyFile|ConvertTo-SecureString -SecureKey $SecureKey
        $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PrivateKey)
        Return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    End{}
}
Switch($DomainUser){
    {($_-like"sy10*")-or($_-like"sy60*")}{Break}
    Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
}
$Validate=SetCredentials -SecureUser $DomainUser -Domain ($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=get-credential};$Validate=$null
#Load PowerCli Context
$Script:PromptForCEIP=$False
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
$Script:StartTime=$DateTime
$Script:PercentComplete=0
$Script:Reason=""
$Script:VMGuest=$null
$Script:Validate=$null
$Script:LastBootProp=@()
$Script:CurrentActivity=""
$Script:ServerList="ServerList.txt"
$Script:WorkingPath=($env:USERPROFILE+"\Desktop")
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
			"`n`nYou can join or leave the program at any time by executing: Set-PowerCliConfiguration -Scope User -ParticipateInCEIP `$True or `$False."
		$AcceptLabel="&Join"
		$choices=(
			(New-Object -TypeName "System.Management.Automation.Host.ChoiceDescription" -ArgumentList $AcceptLabel,"Participate in the CEIP"),
			(New-Object -TypeName "System.Management.Automation.Host.ChoiceDescription" -ArgumentList "&Leave","Don`t participate")
		)
		$userChoiceIndex = $Host.UI.PromptForChoice($caption, $Message, $choices, 0)
		$Participate = $choices[$userChoiceIndex].Label -eq $AcceptLabel
		If($Participate){
            [VMware.VimAutomation.Sdk.Interop.V1.CoreServiceFactory]::CoreService.CeipService.JoinCeipProgram();
        }Else{
            Set-PowerCliConfiguration -Scope User -ParticipateInCEIP $False -Confirm:$False | Out-Null
        }
    }
}Catch{}
Write-Progress -Activity $LoadingActivity -Completed
#Connect vSphere
$Validate=Connect-VIServer -Server $vSphere -credential $SecureCredentials;Clear-Host
$LastBootProp=@{Name='LastBootTime';Expression={(Get-Date)-(New-TimeSpan -Seconds $_.Summary.QuickStats.UptimeSeconds)}}
If($Validate){
    If((Get-Service -Name sshd).Status-eq"Stopped"){
        Start-Service sshd
        Set-Service -Name sshd -StartupType 'Automatic'
        Get-NetFirewallRule -Name *ssh*
    }
    If(Test-Path -Path $ExcludedFile){Remove-Item $ExcludedFile -ErrorAction $ErrorActionPreference}
    If(Test-Path -Path $PoweredOffFile){Remove-Item $PoweredOffFile -ErrorAction $ErrorActionPreference}
    If(Test-Path -Path $LogFile){Remove-Item $LogFile -ErrorAction $ErrorActionPreference}
    $Reason=("["+$SecureCredentials.UserName+"] was successfully connected to: ["+$vSphere+"}")
    ("Beginning to process script because "+$Reason+".")|Out-File $ExcludedFile -Append
    ("Beginning to process script because "+$Reason+".")|Out-File $PoweredOffFile -Append
    ("Beginning to process script because "+$Reason+".")|Out-File $LogFile -Append
    ("<<<"+$Separator+">>>")|Out-File $LogFile -Append
    Write-Host ("Beginning to process script because "+$Reason+".") -ForegroundColor Cyan -BackgroundColor DarkBlue
    If(!(Test-Path -Path ($ProcessList))){
        (Get-VM).Name|Sort-Object|Out-File ($ProcessList)
    }
    #Health Check
<#
    Foreach($Server In [System.IO.File]::ReadLines($ProcessList)){
        $FQDN=$null
        $Bypass=$True
        $NetBIOS=$null
        $VMStatus=$null
        $HostName=$null
        $SubDomain="inf"
        $IPAddress=$null
        $ServerName=$null
        $FolderName=$null
        $DateTime=Get-Date
        $PowerState="PoweredOff"
        $IPAddressToString=$null
        $VMStatus=Get-VM|Where-Object{$_.Name-like($Server)}|Select *
        If($Server-like"*.*"){
            $Server=(($Server).Split(("."))[0])
        }
        $Sender=($Server+"@utsystem.edu")
        If($VMStatus-ne$null){
            $Hostname=$VMStatus.Name
            $PowerState=$VMStatus.PowerState
            $FolderName=($VMStatus.Folder).Name
            If($FolderName-eq"UTD IaaS (Root)"){
                $Reason=("host VM is not being managed by our team")
            }Else{
                If(($PowerState-eq"PoweredOn")-and($PowerState-ne$null)){
                    $FQDN=(Get-VM $Hostname).Guest.HostName
                    If($Hostname-like"*.*"){
                        $NetBIOS=($FQDN.Split(".")[0])
                        $SubDomain=($FQDN.Split(".")[1])
                    }Else{
                        $NetBIOS=$Hostname
                    }
                    Try{
                        $IPAddressToString=([System.Net.Dns]::GetHostEntry($FQDN).AddressList).IPAddressToString
                    }Catch{
                        $IPAddressToString=(ResolveIPAddress -IP "0.0.0.0" -NetBIOS $FQDN -Environment $SubDomain).IPAddressToString
                    }
                    If($IPAddressToString-ne$null){
                        ForEach($IP In $IPAddressToString){
                            If(($IP-ne$null)-and($IP.Split(".")[0]-eq"10")-and{($IP.Split(".")[1]-eq"118")-or($IP.Split(".")[1]-eq"126")}){
                                $ServerName=ResolveIPAddress -IP $IP -FQDN $FQDN
                                If($ServerName-ne$null){
                                    $Bypass=$False
                                }Else{
                                    $Bypass=$True
                                }
                            }Else{
                                $Reason=("host VM has an invalid IP Address: ["+$IP+"]")
                            }
                        }
                    }Else{
                        $Reason=("host VM isn`t registered in DNS")
                    }
                }Else{
                    $Reason=("host VM is currently powered off")
                }
            }
        }
        Write-Host ("Currently working on hostname(VM): '"+$Hostname+"' and is currently: "+$PowerState)
        If(($PowerState-eq"PoweredOn")-and($Bypass-eq$False)){
            ("Currently working on hostname(VM): ["+$Hostname+"] and is currently: powered on.")|Out-File $LogFile -Append
            Try{
                If(Test-Connection -ComputerName $FQDN -Count 3 -BufferSize 256 -ThrottleLimit 32){
                    (“`tTesting connection to $ServerName is successful”)|Out-File $LogFile -Append
                }Else{
                    $EndTime=Get-Date
                    "Connection Failed `t`t"+$DateTime.DateTime+"`t`t"+($EndTime–$DateTime).TotalSeconds+" seconds"|Out-File $LogFile -Append
#                    Send-MailMessage -From "<$($Sender)>" -To "GRP-SIS_SysAdmin <$($SendTo)>" -Subject ($ServerName+" not responding") -Body ($ServerName+" not responding, waiting 10 seconds and will try again.") -SmtpServer $MailServer
                    "Waiting 10 seconds"
                    Start-Sleep 10
                    If(!(Test-Connection -ComputerName $FQDN -Count 3 -BufferSize 256 -ThrottleLimit 32)){
                        $EndTime=Get-Date
                        "Connection Failed `t`t"+$DateTime.DateTime+"`t`t"+($EndTime–$DateTime).TotalSeconds+" seconds"|Out-File $LogFile -Append
#                        (Get-VM -Name $Hostname).ExtensionData.ResetVM() 
#                        Send-MailMessage -From "<$($Sender)>" -To "GRP-SIS_SysAdmin <$($SendTo)>" -Subject ("Server: '"+$ServerName+"' crashed!") -Body ($ServerName+" must have crashed and was reset.") -SmtpServer $MailServer
                        Start-Sleep 30
                    }Else{
                        $EndTime=Get-Date
                        “Successful `t`t"+$DateTime.DateTime+"`t`t"+($EndTime–$DateTime).TotalSeconds+" seconds"|Out-File $LogFile -Append
#                        Send-MailMessage -From "<$($Sender)>" -To "GRP-SIS_SysAdmin <$($SendTo)>" -Subject ($ServerName+" is responding") -Body ($ServerName+" is responding again and was not reset.") -SmtpServer $MailServer
                    }
                }
            }Catch{}
        }Else{
            ("Bypassing ["+$Server+"] because "+$Reason+".")|Out-File $LogFile -Append
        }
        ("----------------------------------------------------------------------------------------------------")|Out-File $LogFile -Append
    }
#>
    $VM=$null
    $Script:EXCount=0
    $Script:POCount=0
    $Script:VMCount=0
    $Script:VMProcessed=0
    ForEach($VMGuest In [System.IO.File]::ReadLines($ProcessList)){
        $VMLabel=Get-View -Filter @{"Name"="^$VMGuest$"} -ViewType VirtualMachine -Property Name, Summary.QuickStats.UptimeSeconds|Select-Object Name,$LastBootProp
        ForEach($VM In $VMLabel){
            $FQDN=""
            $LineCount=0
            $ByPass=$False
            $VMTools=$null
            $VMStatus=$null
            $IPAddress=$null
            $DnsError=$False
            $SystemDetails=$null
            [System.Net.IPAddress]$IPAddress=@()
            If(Test-Path -Path $TempFile){Remove-Item $TempFile}
            If(($VM.Name-eq$VMGuest)-or($VM-eq$VMGuest)){
                $VMCount++
                Write-Host ("Beginning to process: "+$VMGuest)
                $FQDN=((Get-VM $VMGuest).Guest.HostName).ToLower()
                $VMStatus=Get-VM|Where-Object{$_.Name-like($VMGuest)}|Select-Object *
                $OSState=$VMStatus.Guest.State
                $IPAddress+=@($VMStatus.Guest.IPAddress)
                $OSFullName=$VMStatus.Guest.OSFullName
                If((!($FQDN))-or($FQDN-eq"")){
                    $FQDN=$VMGuest
                }
                ("VMWare object name: ["+$VMGuest+"] is being processed at this time.")|Out-File $TempFile -Append
                ("`tGuest system: ["+$FQDN+"] was last rebooted on: ["+$VMLabel.LastBootTime+"].")|Out-File $TempFile -Append
                ("`tThe current state of: ["+$FQDN+"] is:")|Out-File $TempFile -Append
                ("`tHost (ESXi):`t`t"+$VMStatus.VMHost)|Out-File $TempFile -Append
                ("`tPower state:`t`t"+$VMStatus.PowerState)|Out-File $TempFile -Append
                ("`tOperating System:`t"+$OSFullName)|Out-File $TempFile -Append
                ("`tOS Status:`t`t"+$OSState)|Out-File $TempFile -Append
                ("`tIP Address(es):`t`t"+$IPAddress)|Out-File $TempFile -Append
                ("`tCPU count:`t`t"+$VMStatus.NumCpu)|Out-File $TempFile -Append
                ("`tCores Per Socket:`t"+$VMStatus.CoresPerSocket)|Out-File $TempFile -Append
                ("`tMemory in MB:`t`t"+$VMStatus.MemoryMB)|Out-File $TempFile -Append
                ("`tFolder:`t`t`t"+$VMStatus.Folder)|Out-File $TempFile -Append
                ("`tSpace used in GB:`t"+$VMStatus.UsedSpaceGB)|Out-File $TempFile -Append
                ("`tProvisioned in GB:`t"+$VMStatus.ProvisionedSpaceGB)|Out-File $TempFile -Append
                If($ExcludedFolders-like("*"+$VMStatus.Folder.Name+"*")){
                    ("****`tBypassing ["+$FQDN+"] because it's in the excluded folder: ["+$VMStatus.Folder+"].`t****")|Out-File $LogFile -Append
                    ("<<<"+$Separator+">>>")|Out-File $ExcludedFile -Append
                    $SystemDetails=Get-Content -Path $TempFile
                    ForEach($Line In $SystemDetails){
                        ($Line)|Out-File $ExcludedFile -Append
                    }
                    $ByPass=$True
                    $EXCount++
                }ElseIf($VMStatus.PowerState-eq"PoweredOff"){
                    ("****`tBypassing ["+$FQDN+"] because it's power state is currently ["+$VMStatus.PowerState+"].`t****")|Out-File $LogFile -Append
                    ("<<<"+$Separator+">>>")|Out-File $PoweredOffFile -Append
                    $SystemDetails=Get-Content -Path $TempFile
                    ForEach($Line In $SystemDetails){
                        ($Line)|Out-File $PoweredOffFile -Append
                    }
                    $ByPass=$True
                    $POCount++
                }Else{
                    $SystemDetails=Get-Content -Path $TempFile
                    ForEach($Line In $SystemDetails){
                        ($Line)|Out-File $LogFile -Append
                    }
                    Try{
                        $IPAddressToString=([System.Net.Dns]::GetHostEntry($FQDN).AddressList).IPAddressToString
                        ("`t"+$VMGuest+" is returning: ["+$FQDN+"] as the FQDN with an IP Address of ["+$IPAddressToString+"].")|Out-File $LogFile -Append
                    }Catch{
                        $DnsError=$True
                        Switch($FQDN){
                            {($_-like"*."+$Domain)}{$DnsError=$False;Break}
                            {($_-like"*.edu")}{$DnsError=$False;Break}
                        }
                        If($DnsError-eq$True){
                            $FQDN=$VMGuest
                        }
                        ("`t["+$FQDN+"] failed to return DNS information using the Hostname.")|Out-File $LogFile -Append
                        $Error.Clear()
                        If(($ByPass-eq$False)-and(!($IPAddress))){
                            $IPAddressToString=ResolveIPAddress -IP $IPAddress -FQDN $FQDN
                            $FQDN=([System.Net.Dns]::GetHostEntry("($IPAddress)").Hostname)
                        }
                    }
                }
                If(($ByPass-eq$False)-and(($FQDN-ne"")-or(!($FQDN)))){
                    Write-Host ("`tVerifying a running and health state for ["+$FQDN+"].")
                    $VMTools=Get-View -ViewType VirtualMachine -Filter @{"Name"="^$VMGuest$"}|Select-Object Name,
                        @{N="HW Version";E={$_.Config.version}},
                        @{N='VMware Tools Status';E={$_.Guest.ToolsStatus}},
                        @{N="VMware Tools version";E={$_.Config.Tools.ToolsVersion}}
                    ("`tHardware version:`t"+$VMTools.'HW Version')|Out-File $LogFile -Append
                    ("`tvmtools version:`t"+$VMTools.'VMware Tools version')|Out-File $LogFile -Append
                    ("`tvmtools status:`t"+$VMTools.'VMware Tools Status')|Out-File $LogFile -Append
                    If($OSState-eq"Running"){
                        $TestPort=$null
                        $PortCheck=$null
                        $TraceRoute=$null
                        $RemoteTest=$null
                        $PingResults=$null
                        $TestReturn=Test-NetConnection -ComputerName $FQDN -TraceRoute
                        If($TestReturn){
                            $PingResults=$TestReturn.PingSucceeded
                            $TraceRoute=@($TestReturn.TraceRoute)
                            Switch($OSFullName){
                                {($_-like"Microsoft*")}{$PortCheck=3389;Break}
                                Default{$PortCheck=22;Break}
                            }
                            If($PingResults){
                                ("`t"+$FQDN+" successfully returned a ping with a TTL of "+$TestReturn.PingReplyDetails.RoundtripTime+" ms.")|Out-File $LogFile -Append
                                $TestPort=Test-OpenPort -Target $FQDN -Port $PortCheck
                            }
                        }
                        If($TestPort.Status-eq$True){
                            ("`tSuccessfully connected to ["+$TestPort.Target+"] on port ["+$TestPort.Port+"].")|Out-File $LogFile -Append
                            Switch($OSFullName){
                                {($_-like"Microsoft*")}{
                                    Write-Host("`tConnecting to "+$FQDN+".")
                                    ("`tAttempting to remotely connect to "+$FQDN+".")|Out-File $LogFile -Append
                                    Try{
                                        $RemoteTest=Test-WSMan -ComputerName $FQDN -Credential $SecureCredentials -Authentication Default
                                        $RemoteTest=$True
                                    }Catch{
                                        Write-Host $_.Exception.Message
                                        $RemoteTest=$False
                                        $Error.Clear()
                                    }
                                    Break
                                }
                                Default{
                                    $RemoteTest=Test-OpenPort -Target $FQDN -Port 22
                                    Break
                                }
                            }
                        }Else{
                            ("`tFailed to connected to ["+$TestPort.Target+"] on port ["+$TestPort.Port+"].")|Out-File $LogFile -Append
                            $ResetHost+=($FQDN)
                        }
                    }Else{}
                }
            }
        }
        ("<<<"+$Separator+">>>")|Out-File $LogFile -Append
    }
    $AttachmentList=$null
    $VMProcessed=([int]$VMCount-([int]$EXcount+[int]$POCount))
    $Sender=($vSphere.Split(".")[0]+"@"+$Domain)
    $SendTo=("Bob Stobie <$($SendTo)>")
#    $SendTo=("GRP-SIS_SysAdmin <$($SendTo)>")
    $Message=("Start Time: "+$StartTime+"`n`n")
    $Message+=("The attachment: ["+$ServerList+"] is a list of ["+$VMCount+"] systems that were processed for being reset.  ")
    $Message+=("The second attachment are the results from each VM of the ["+$VMProcessed+"] VMs processed from the ["+$LogName+"] file.  ")
    $AttachmentList=@($ProcessList,$LogFile)
    If($EXcount-gt0){
        $AttachmentList+=($ExcludedFile)
        $Message+=("The third attachment ["+$ExcludedName+"] is a list of ["+$EXcount+"] systems that have been marked as excluded.  ")
    }Else{
        $Message+=("The attachment ["+$ExcludedName+"] was not included because there were ["+$EXcount+"] systems that were excluded.  ")
    }
    If($POCount-gt0){
        $AttachmentList+=($PoweredOffFile)
        $Message+=("The last attachment ["+$PoweredOffName+"] is a list of ["+$POCount+"] systems that are currently powered off and won't be reset.")
    }Else{
        $Message+=("The attachment ["+$PoweredOffName+"] was not included because there were ["+$POcount+"] systems that were powered off.")
    }
    $Message+=("`n`nEnd Time: "+(Get-Date))
    Send-MailMessage -From "<$($Sender)>" -To $SendTo -Subject ("Summary of VMWare systems from Site-"+$SiteCode+"") -Body $Message -Attachments $AttachmentList -SmtpServer $MailServer
}Else{
    $Reason=("["+$SecureCredentials.UserName+"] was unable to connect to: ["+$vSphere+"}")
    ("Failed to beginning process script because "+$Reason+".")|Out-File $LogFile -Append
    Write-Host ("Failed to beginning process script because "+$Reason+".") -ForegroundColor Yellow -BackgroundColor DarkRed
}
$Message=$null;$Reason=$null;$VMProcessed=0;$VMCount=0;$EXcount=0;$POCount=0
Rename-Item -Path ($ProcessList) -NewName "ProcessedList.txt" -Force
Disconnect-VIServer -Server $global:DefaultVIServers -Force
Set-Location ($env:SystemRoot+"\System32")