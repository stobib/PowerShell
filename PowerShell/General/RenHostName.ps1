Clear-Host;Clear-History
Import-Module ActiveDirectory
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
$loadingActivity = "Loading $productName"
$script:completedActivities = 0
$script:percentComplete = 0
$script:currentActivity = ""
$script:totalActivities = $moduleList.Count + 1
Function Get-SystemNetDNS{param([IPAddress]$IPAddress=$null,[String]$ComputerName=$null)
    NullVariables -ItemList 'AddressList','LineItem','RecordData','Results','SearchType','SearchValue','SubArray','ValueCheck'
    Try{
        $Results=$null
        $ValueCheck=""
        $SearchType="IPAddress"
        If(!$($ComputerName).Length-lt1){
            $ValueCheck=$($ComputerName.Split(" "))
            Switch($ValueCheck[1].Length-gt1){
                {($_-eq$true)}{$ComputerName=$ValueCheck[1];Break}
                Default{Break}
            }
            $SearchValue=$ComputerName;$SearchType="HostName"
        }
        If($($IPAddress.AddressFamily)-eq"InterNetwork"){$SearchValue=$IPAddress.IPAddressToString}
        Switch($SearchType){
            Default{$Results=[System.Net.Dns]::GetHostEntry($SearchValue);Break}
        }
        If($ComputerName-eq$env:COMPUTERNAME){
            $ParseArray=New-Object PSObject
            $ParseArray|Add-Member -MemberType NoteProperty -Name "Found" -Value $true
            $ParseArray|Add-Member -MemberType NoteProperty -Name "HostName" -Value $($Results.HostName)
            $ParseArray|Add-Member -MemberType NoteProperty -Name "Aliases" -Value $($Results.Aliases)
            For($i=0;$($Results.AddressList[$i])-ne$null;$i++){
                If($($Results.AddressList[$i].IPAddressToString)-ne"::1"){
                    [IPAddress]$AddressList=$($Results.AddressList[$i])
                    $SubArray=New-Object PSObject
                    $SubArray|Add-Member -MemberType NoteProperty -Name "Address" -Value $AddressList.Address
                    $SubArray|Add-Member -MemberType NoteProperty -Name "AddressFamily" -Value $AddressList.AddressFamily
                    $SubArray|Add-Member -MemberType NoteProperty -Name "ScopeId" -Value $AddressList.ScopeId
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6Multicast" -Value $AddressList.IsIPv6Multicast
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6LinkLocal" -Value $AddressList.IsIPv6LinkLocal
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6SiteLocal" -Value $AddressList.IsIPv6SiteLocal
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6Teredo" -Value $AddressList.IsIPv6Teredo
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv4MappedToIPv6" -Value $AddressList.IsIPv4MappedToIPv6
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IPAddressToString" -Value $AddressList.IPAddressToString
                }
            }
            $ParseArray|Add-Member -MemberType NoteProperty -Name "AddressList" -Value $SubArray
        }Else{
            $ParseArray=New-Object PSObject
            $ParseArray|Add-Member -MemberType NoteProperty -Name "Found" -Value $true
            ForEach($RecordData In $Results){
                $ParseArray|Add-Member -MemberType NoteProperty -Name "HostName" -Value $RecordData.HostName
                $ParseArray|Add-Member -MemberType NoteProperty -Name "Aliases" -Value $RecordData.Aliases
                [IPAddress]$AddressList=$($RecordData.AddressList.IPAddressToString)
                $SubArray=New-Object PSObject
                ForEach($LineItem In $AddressList){
                    $SubArray|Add-Member -MemberType NoteProperty -Name "Address" -Value $LineItem.Address
                    $SubArray|Add-Member -MemberType NoteProperty -Name "AddressFamily" -Value $LineItem.AddressFamily
                    $SubArray|Add-Member -MemberType NoteProperty -Name "ScopeId" -Value $LineItem.ScopeId
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6Multicast" -Value $LineItem.IsIPv6Multicast
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6LinkLocal" -Value $LineItem.IsIPv6LinkLocal
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6SiteLocal" -Value $LineItem.IsIPv6SiteLocal
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv6Teredo" -Value $LineItem.IsIPv6Teredo
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IsIPv4MappedToIPv6" -Value $LineItem.IsIPv4MappedToIPv6
                    $SubArray|Add-Member -MemberType NoteProperty -Name "IPAddressToString" -Value $LineItem.IPAddressToString
                }
                $ParseArray|Add-Member -MemberType NoteProperty -Name "AddressList" -Value $SubArray
            }
        }
        Return $ParseArray
    }Catch [Exception]{
        If($($_.Exception.Message)-eq"No such host is known"){
        }Else{
            $Message="Error: [Get-SystemNetDNS]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Yellow -BackgroundColor DarkRed
        }
        Return $false
    }
}
Function Get-VMComputerData{param([IPAddress]$VCMManagerIP,[String]$VMServer,[PSCredential]$AdminAccount,[String]$FileName)
    NullVariables -ItemList 'Connected','Error','Message','NetworkCards','NtwkCard','ReportedVM','ReportedVMs','VM','VMs'
    Try{
        $VMServerIP=$VCMManagerIP.IPAddressToString
        Write-debug "Connecting to vCenter using '$VMServerIP', please wait..."
#        $Connected=Connect-VIServer -Server $VCMManagerIP -Protocol https -Credential $AdminAccount -ErrorAction SilentlyContinue
        $Connected=Connect-VIServer -Server $VMServerIP -Credential $AdminAccount -ErrorAction SilentlyContinue
        Trap{
            If($Error[0].exception-like"*incorrect user name or password*"){
                $Message="Error: [Get-VMComputerData]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Magenta -BackgroundColor Black
                Return $null
            }
        }
        If($Connected){
            $ReportedVMs=New-Object System.Collections.ArrayList
            $VMs=Get-View -ViewType VirtualMachine|Sort-Object -Property{$_.Config.Hardware.Device|Where{$_-is[VMware.Vim.VirtualEthernetCard]}|Measure-Object|select -ExpandProperty Count} -Descending
            ForEach($VM in $VMs){
                $ReportedVM=New-Object PSObject
                Add-Member -Inputobject $ReportedVM -MemberType noteProperty -name Guest -value $VM.Name
                Add-Member -InputObject $ReportedVM -MemberType noteProperty -name UUID -value $($VM.Config.Uuid)
                $NetworkCards=$VM.guest.net| ?{$_.DeviceConfigId-ne-1}
                $i=0
                ForEach($NtwkCard in $NetworkCards){
                    Add-Member -InputObject $ReportedVM -MemberType NoteProperty -Name "networkcard${i}.Network" -Value $NtwkCard.Network
                    Add-Member -InputObject $ReportedVM -MemberType NoteProperty -Name "networkcard${i}.MacAddress" -Value $NtwkCard.Macaddress  
                    Add-Member -InputObject $ReportedVM -MemberType NoteProperty -Name "networkcard${i}.IPAddress" -Value $($NtwkCard.IPAddress|?{$_-like"*.*"})
                    Add-Member -InputObject $ReportedVM -MemberType NoteProperty -Name "networkcard${i}.Device" -Value $(($VM.Config.Hardware.Device|?{$_.key-eq$($NtwkCard.DeviceConfigId)}).GetType().Name)
                    $i++
                }
                $ReportedVMs.add($ReportedVM)|Out-Null
            }
            $ReportedVMs|Export-CSV $FileName -NoTypeInformation -Encoding UTF8|Out-Null
            $Message=Set-DisplayMessage -Description "Export complete!  Safe to disconnect from '$($VMServer) [$($VMServerIP)]' server."
#            Disconnect-VIServer -Server $Connected -Force
            Return $true
        }Else{
            $Message=Set-DisplayMessage -Description "Error: [Get-VMComputerData]: Failed to connect to vCenter using '$VMServerIP'.";Write-Host $Message -ForegroundColor Magenta -BackgroundColor Black
            Return $false
        }
    }Catch [Exception]{
        $Message="Error: [Get-VMComputerData]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Magenta -BackgroundColor Black
        Return $false
    }
}
Function Get-VMExportedInfo{param([String]$MacAddress,[String]$GuestName,[Int]$Site)
    NullVariables -ItemList 'ExportVMData','Left','NetworkMAC','SiteLabel','VMAdapter','VMComputerList','VMComputerName','VMGuest','VMIPAddress','VMNetwork','VMPowerState'
    If($Site-eq0){
        $MacAddress=""
        $Left=$GuestName.Length-3
        $SiteLabel=$GuestName.Substring($Left,1)
        Switch($SiteLabel){
            {($_-eq"b")-or($_-eq"y")}{$Site=2;Break}
            Default{$Site=1;Break}
        }
    }Else{
        $GuestName=""
        Switch($Site){
            "126"{$Site=2;Break}
            Default{$Site=1;Break}
        }
    }
    $VMPowerState="Off"
    $VMComputerName=$null
    $ExportVMData="VMComputerData-Site$Site.csv"
    $VMComputerList=Import-Csv $ExportVMData|Sort -Property "Guest"
    ForEach($VMGuest In $VMComputerList){
        $VMComputerName=$VMGuest.Guest
        For($i=0;$i-lt1;$i++){
            $NetworkMAC=$VMGuest.$('networkcard'+$i+'.MacAddress')
            If(($MacAddress-eq$NetworkMAC-and$MacAddress.Length-lt1)-or($VMComputerName-like"*$GuestName*"-and$GuestName.Length-lt1)){
                $VMComputerName=$VMGuest.Guest
                $VMNetwork=$VMGuest.$('networkcard'+$i+'.Network').ToString()
                $VMIPAddress=$VMGuest.$('networkcard'+$i+'.IPAddress').ToString()
                $VMAdapter=$VMGuest.$('networkcard'+$i+'.Device').ToString()
                If($VMNetwork-ne$VMPoweredOffState){
                    $VMPowerState="On"
                }
                $ParseArray=New-Object PSObject
                $ParseArray|Add-Member -MemberType NoteProperty -Name "Found" -Value $true
                $ParseArray|Add-Member -MemberType NoteProperty -Name "HostName" -Value $VMComputerName
                $ParseArray|Add-Member -MemberType NoteProperty -Name "Network" -Value $VMNetwork
                $ParseArray|Add-Member -MemberType NoteProperty -Name "IPAddress" -Value $VMIPAddress
                $ParseArray|Add-Member -MemberType NoteProperty -Name "Device" -Value $VMAdapter
                $ParseArray|Add-Member -MemberType NoteProperty -Name "State" -Value $VMPowerState
                Return $ParseArray
                Break
            }
        }
    }
    Return $false
}
Function LoadModules(){
   ReportStartOfActivity "Searching for $productShortName module components..."
   
   $loaded = Get-Module -Name $moduleList -ErrorAction Ignore | % {$_.Name}
   $registered = Get-Module -Name $moduleList -ListAvailable -ErrorAction Ignore | % {$_.Name}
   $notLoaded = $registered | ? {$loaded -notcontains $_}
   
   ReportFinishedActivity
   
   foreach ($module in $registered) {
      if ($loaded -notcontains $module) {
		 ReportStartOfActivity "Loading module $module"
         
		 Import-Module $module
		 
		 ReportFinishedActivity
      }
   }
}
Function LocateHostAD{param([string]$ComputerName)
    Try{
        $GetHostInfo=Get-ADComputer -Server $DNSHost -Identity "$ComputerName" -Properties SID -Credential $DomainAuth
        $ADHostSID=$GetHostInfo.SID.value
        $ps=new-object System.Diagnostics.Process
        $ps.StartInfo.Filename=$PsGetSid
        $ps.StartInfo.RedirectStandardOutput=$True
        $ps.StartInfo.UseShellExecute=$false
        $ps.start()
        $ps.WaitForExit()
        [string]$Out=$ps.StandardOutput.ReadToEnd()
        ForEach($Line in $Out){
            If($Line -ccontains $ADHostSID){
                Return "";Break
            }
        }
        Return $ComputerName
    }
    Catch{
        Return "False"
    }
}
Function NullVariables{param([Parameter(Position=0,Mandatory=$true)]$ItemList=@())
    Try{
        ForEach($Item In $ItemList){
            If($Item.Length-lt1){
            }Else{
                Clear-Variable -Name "$Item" -Scope Global -Force -ErrorAction SilentlyContinue
            }
        }
    }Catch [Exception]{
        If($_.Exception.Message-eq"Cannot find a variable with the name '$Item'."){
        }Else{
            $Message="Error: [NullVariables]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Magenta -BackgroundColor Black
        }
    }
}
Function Protect-String{[CmdletBinding()]param([String][Parameter(Mandatory=$true)]$String,[String][Parameter(Mandatory=$true)]$Key)
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
Function ReportFinishedActivity() {
   $script:completedActivities++
   $script:percentComplete = (100.0 / $totalActivities) * $script:completedActivities
   $script:percentComplete = [Math]::Min(99, $percentComplete)
   
   Write-Progress -Activity $loadingActivity -CurrentOperation $script:currentActivity -PercentComplete $script:percentComplete
}
Function ReportStartOfActivity($activity) {
   $script:currentActivity = $activity
   Write-Progress -Activity $loadingActivity -CurrentOperation $script:currentActivity -PercentComplete $script:percentComplete
}
Function Set-DisplayMessage{param([String]$Description,[String]$StatusMessage,$FontColor="Yellow",$Background="Black",$RightJustified=$true)
    NullVariables -ItemList 'Height','Left','Message','Right','RightAlign','Width','WindowSize'
    [Int]$RightAlign=$Buffer.Width
    [Int]$WindowSize=$($RightAlign-$($Description.Length+1+$StatusMessage.Length+1))
    If($Buffer.Width-le$WindowSize){
        $Width=$WindowSize
        For($Height=0;$Buffer.Width-le$Width;$Height++){
            $Width=$Width-$Buffer.Width
        }
        $Buffer.Height=$Height
        $WindowSize=$Width
    }
    If($RightJustified-eq$true){
        For($Left=0;$Left-lt$WindowSize;$Left++){
            $Description=" "+$Description
        }
    }ElseIf($RightJustified-eq$false){
        For($Right=0;$Right-lt$WindowSize;$Right++){
            $Description=$Description+" "
        }
    }ElseIf($StatusMessage.Length-gt0-or($Description.Length-lt1-and$StatusMessage.Length-lt1)){
        For($Left=0;$Left-lt$WindowSize;$Left++){
            $StatusMessage=$StatusMessage+" "
        }
    }
    [String]$Message=$Description
    If($FontColor[1].Length-gt1){
        Write-Color "$Message"," $StatusMessage" -Color $FontColor[0],$FontColor[1]
    }Else{
        Write-Host $Message,$StatusMessage -ForegroundColor $FontColor -BackgroundColor $Background
    }
    If($Background-eq"DarkRed"){
        Add-Content -Path $ResultFile -Value $($Message.Trim()) -PassThru
    }
}
Function Unprotect-String{[CmdletBinding()]param([String][Parameter(Mandatory=$true)]$String,[String][Parameter(Mandatory=$true)]$Key)
    Begin{}
    Process{
        If(([System.Text.Encoding]::Unicode).GetByteCount($Key)*8-notin128,192,256){
            Throw "Given encryption key has an invalid length.  The specified key must have a length of 128, 192, or 256 bits."
            Return $false
        }
        $SecureKey=ConvertTo-SecureString -String $Key -AsPlainText -Force
        $PrivateKey=Get-Content -Path $EncryptionKeyFile|ConvertTo-SecureString -SecureKey $SecureKey
        $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PrivateKey)
        Return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    End{}
}
Function Verify-IPAddress{[CmdletBinding()][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][ValidateScript({$_ -match [IPAddress]$_ })]
Param([String]$IPAddress)
    Begin{}
    Process{
        Try{
            [IPAddress]$IPAddress
        }Catch [Exception]{
            $Message="Error: [Set-DisplayMessage]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Magenta -BackgroundColor Black
            Return $false
        }
    }
    End{}
}
LoadModules
Write-Progress -Activity $loadingActivity -Completed
Set-Location -Path "$($env:USERProfile)\Documents"
Set-Variable -Name Counter -Value 0
Set-Variable -Name LAcct -Value Admin
Set-Variable -Name HostFQDN -Value $null
Set-Variable -Name LSecure -Value 'd1$c0v3ry'
Set-Variable -Name DNSHost -Value 10.118.0.10
Set-Variable -Name Domain -Value utshare.local
Set-Variable -Name VIServer -Value 10.118.1.77
Set-Variable -Name RootDrive -Value $env:SystemRoot
Set-Variable -Name DSecure -Value 'h$@.z2;6ym,gKpAP'
Set-Variable -Name VMAuthAcct -Value sy1000829946@$Domain
Set-Variable -Name SvcAcctCred -Value zasvcvdiauthacct@$Domain
Set-Variable -Name HostName -Value $env:COMPUTERNAME.ToLower()
Set-Variable -Name DNSDomain -Value $env:USERDOMAIN.ToLower()
Set-Variable -Name WorkingPath -Value "$env:USERProfile\Documents\Passwords"
Set-Variable -Name SecureFile -Value "$WorkingPath\Encrypted.pwd"
If(Test-Path -Path $SecureFile){
    Set-Variable -Name Extensions -Value 'pwd','key'
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
    $SecureString=Read-Host -Prompt "Enter your [$VMAuthAcct] credentials" -AsSecureString
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
        $Dir=MkDir $WorkingPath
    }
    If($PrivateKey.length-lt1){
        Do{
            Switch($RandomKey){
                {($_-eq8)}{
                    $Key=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    $Key+=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    Break
                }
                {($_-eq12)}{
                    $Key=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    $Key+=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    $Key+=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    Break
                }
                {($_-eq16)}{
                    $Key=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    $Key+=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    $Key+=-join((48..57)|Get-Random -Count 4|%{[char]$_})
                    $Key+=-join((48..57)|Get-Random -Count 4|%{[char]$_})
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
        }While((Test-Path -Path $SecureFile)-eq$true)
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
                {($_-gt0)-and($_-le$Characters)}{$Set=-join((65..90)+(97..122)|Get-Random -Count 1|%{[Char]$_});Break}
                Default{$PrivateKey="";$Set="";Break}
            }
            $PrivateKey+=$Set
        }
        Set-Variable -Name "EncryptionKeyFile" -Value "$WorkingPath\$Key.key"
        Protect-String $PrivateKey $Key|Out-File -Filepath $EncryptionKeyFile
        $Validate=Unprotect-String $PrivateKey $Key
        If($Validate-ne$false){
            $SecureKey=ConvertTo-SecureString -String $Key -AsPlainText -Force
        }
        $SecureString=Read-Host -Prompt "Enter your [$VMAuthAcct] credentials" -AsSecureString
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
    }
}
Set-Variable -Name HostLen -Value $HostName.Length
Set-Variable -Name HostTrim -Value $HostName.Substring(0,$HostLen -3)
Set-Variable -Name RegPath -Value 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
Set-Variable -Name RegName -Value 'Customization'
Set-Variable -Name RegValue -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -noe -c ". \"C:\scripts\RenHostName.ps1\" $true"'
$PsGetSid=$RootDrive+'\System32\PsGetsid64.exe'
$LSecure=ConvertTo-SecureString $LSecure -AsPlainText -Force
$DSecure=ConvertTo-SecureString $DSecure -AsPlainText -Force
$LocalAuth=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $LAcct,$LSecure
$DomainAuth=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SvcAcctCred,$DSecure
$VMWareAuth=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $VMAuthAcct,$SecureString
If($Domain-ne$DNSDomain){
    $Site=0
    $Sites=1
    [Int]$Counter=0
    $VMServerIP=[System.Collections.ArrayList]@(0)
    Do{
        $Counter++
        Switch($Counter){
            "1"{$Prompt="Enter the IP Address of the Virtual Platform management server: ['$VIServer']";Break}
            Default{$Prompt="Please enter a valid IP Address: ['$VIServer']";Break}
        }
    #    $VMServerIP[0]=Read-Host -Prompt $Prompt
        If($VMServerIP[0].Length-le1){$VMServerIP[0]=$VIServer}
        $Results=Verify-IPAddress $VMServerIP[0]
        If($Results-eq$false){$VMServerIP[0]=-1}
    }Until($VMServerIP[0]-gt0)
    $ValidCredentials=$false
    Do{
        [String]$CurrentIP=""
        If($VMServerIP-like"*,*"){
            $CurrentIP=$VMServerIP.ToString().Split(",")[$Site]
        }Else{
            $CurrentIP=$VMServerIP
        }
        For($o=0;$o-le3;$o++){
            Switch($o){
                "0"{[Int]$Octate1=$VMServerIP[$Site].ToString().Split(".")[$o];Break}
                "1"{[Int]$Octate2=$VMServerIP[$Site].ToString().Split(".")[$o];Break}
                "2"{[Int]$Octate3=$VMServerIP[$Site].ToString().Split(".")[$o];Break}
                "3"{[Int]$Octate4=$VMServerIP[$Site].ToString().Split(".")[$o];Break}
            }
        }
        If($Octate2-eq118){
            $Octate2=126
        }
        $Site++
        $ExportVMData="VMComputerData-Site$Site.csv"
        If(Test-Path -Path $ExportVMData){Remove-Item -Path $ExportVMData}
        $Results=Get-SystemNetDNS -IPAddress $CurrentIP
        NullVariables -ItemList 'AddressList','LineItem','RecordData','SearchType','SearchValue','SubArray','ValueCheck'
        If($Results.Found-eq$true){
            $VMServerDNS=$Results.HostName
        }
        For($l=0;$l-lt2;$l++){
            Switch($l){
                "1"{$Message="Beginning to export the current state of VMs to '.\$ExportVMData'.  Please wait, this export could take upto a few minutes to complete.";Break}
                Default{$Message="";Break}
            }
            $Message=Set-DisplayMessage -Description $Message -FontColor White -Background Black -RightJustified $false
        }
        $Results=Get-VMComputerData -VCMManagerIP $CurrentIP -VMServer $VMServerDNS -AdminAccount $VMWareAuth -FileName $ExportVMData
        If($Results-eq$true){
            $Results="Successfully completed exporting the current state of Virtual Machine's from '$VMServerDNS'.",'White','Black'
            $ValidCredentials=$true
        }ElseIf($Results-eq$false){
            $Results="Wasn't able to retrieve the current state of Virtual Machine's from '$CurrentIP'.",'Yellow','DarkRed'
        }Else{
            Break
        }
        For($l=0;$l-le2;$l++){
            Switch($l){
                "1"{$Message=$Results[0],$Results[1],$Results[2];Break}
                Default{$Message="","Yellow","Black";Break}
            }
            $Message=Set-DisplayMessage -Description $Message[0] -FontColor $Message[1] -Background $Message[2] -RightJustified $false
        }
        $VMServerIP="$VMServerIP,$Octate1.$Octate2.$Octate3.$Octate4"
    }While($Site-lt$Sites)
    CLS
    [Int]$Counter=0
    Do{


        Start-Process -FilePath $PsGetSid -WindowStyle Hidden
        $GetSID=Get-Process|Where-Object{$_.WorkingSet-gt20000000}


        $Counter+=1
        If($Counter-eq1000){Break}
        If($Counter-le9){$TestName=$HostTrim+"00"+$Counter}
        If($Counter-ge10){$TestName=$HostTrim+"0"+$Counter}
        If($Counter-ge100){$TestName=$HostTrim+$Counter}
        $ComputerName=LocateHostAD($TestName)
        $Report = @()
        $VMs=Get-VM
        $Invalid=0
        Foreach($Server In $TestName){
            $VMs|Where-Object{$_.ExtensionData.Guest.Hostname-like"*$($Server)*"}|%{
                $Report+=New-Object PSObject -Property @{
                   VM_Name=$_.Name
                   DNS_Name=$_.ExtensionData.Guest.Hostname
                }
                $Invalid=+1;Break
            }
        }
        If($Invalid-eq0-and($HostName-ne$TestName-and$HostName.Length-eq$TestName.ToString().Length)){
            Set-ItemProperty -Path $RegPath -Name $RegName -Value $RegValue
            Rename-Computer $TestName -LocalCredential $LocalAuth -Restart;Break
        }
        Set-ItemProperty -Path $RegPath -Name $RegName -Value $RegValue
        Remove-ADComputer -Identity $HostName -Server $DNSHost -Credential $DomainAuth
        Start-Sleep 5000 
        Add-Computer -DomainName $Domain -NewName $HostName -Credential $DomainAuth -Restart -Force
    }
    Until($ComputerName-eq"True"-or$Counter-gt51)
    Move-ADObject -Identity "CN='$HostName',CN=Computers,DC=utshare,DC=local" -TargetPath "OU=vdi-ardc,OU=AllWrkstns,DC=utshare,DC=local"
}