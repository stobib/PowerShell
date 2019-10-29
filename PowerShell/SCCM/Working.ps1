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
Function SetCredentials{[CmdletBinding()]Param([String][Parameter(Mandatory=$true,HelpMessage=”Service Account”)]$SrvAccount="")
    Set-Variable -Name NetworkPath -Value "\\w16apmpas01.inf.utshare.local\backup$\SrvAccount\Credentials"
    Set-Variable -Name WorkingPath -Value "$env:USERProfile\AppData\Local\Credentials"
    Set-Variable -Name SecureFile -Value ($($WorkingPath)+"\"+$($SrvAccount)+".pwd")
    RoboCopy $NetworkPath $WorkingPath "*.*"|Out-Null
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
                    $EncryptionKeyFile=($WorkingPath+"\"+$KeyName+"."+$Extension)
                    $SecureKey=ConvertTo-SecureString -String $KeyName -AsPlainText -Force
                    $PrivateKey=Get-Content -Path $EncryptionKeyFile|ConvertTo-SecureString -SecureKey $SecureKey
                    $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PrivateKey)
                    $UnEncrypted=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                }
            }
        }
    }Else{
        $SecureString=Read-Host -Prompt "Enter the password for: [$SecureUser]" -AsSecureString
        $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        $Encrypted=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        Set-Variable -Name EncryptionKeyFile -Value $null
        Set-Variable -Name Characters -Value $null
        Set-Variable -Name PrivateKey -Value $null
        Set-Variable -Name SecureKey -Value $null
        [String]$Key=0
        [Int]$Min=8
        [Int]$Max=1024
        $Prompt="Enter the length you want to use for the security key: [8, 12, or 16]"
        If($Prompt.Length-eq0){$Prompt=8}
        [Int]$RandomKey=Read-Host -Prompt $Prompt
        If(Test-Path -Path $WorkingPath){
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
            Do{
                If(Test-Path -Path $WorkingPath){
                    $SecureFile=($($WorkingPath)+"\"+$($SrvAccount)+".pwd")
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
            Set-Variable -Name EncryptionKeyFile -Value ($WorkingPath+"\"+$Key+".key")
            Protect-String $PrivateKey $Key|Out-File -Filepath $EncryptionKeyFile
            $Validate=Unprotect-String $PrivateKey $Key
            If($Validate-ne$false){
                $SecureKey=ConvertTo-SecureString -String $Key -AsPlainText -Force
            }Else{
                $SecureString=Read-Host -Prompt "Enter the password for: [$SecureUser]" -AsSecureString
            }
            $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
            $EncryptedString=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            $EncryptedString|ConvertTo-SecureString -AsPlainText -Force|ConvertFrom-SecureString -SecureKey $SecureKey|Out-File -FilePath $SecureFile
        }
        Try{
            $SecureString=Get-Content -Path $SecureFile|ConvertTo-SecureString -SecureKey $SecureKey -ErrorAction Stop
            $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
            $Validate=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            If($EncryptedString-ceq$Validate){
                Robocopy $WorkingPath $NetworkPath "*.*"|Out-Null
            }
        }Catch [Exception]{
            $Message="Error: [Validation]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Yellow -BackgroundColor DarkRed
        }
    }
    $script:SecureCredentials=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SecureUser,$SecureString
}

Clear-Host;Clear-History
Set-Location $env:SystemRoot\System32
$CurrentLocation=Get-Location

#Load Configuration Manager PowerShell Module
Import-module($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5)+'\ConfigurationManager.psd1')

#Get User Domain for FQDN
$UDomainFQDN=($env:USERDNSDOMAIN).ToUpper()
$UDomain=($UDomainFQDN).split(".")[0]
#Retrieve or create secure credentials for Service Accounts
Set-Variable -Name SecureCredentials -Value $null
Set-Variable -Name SecureUser -Value "zasvccm_cp"

#Get SiteServer and SiteCode
$SiteServer=$($(Get-PSDrive -PSProvider CMSite).Root).Split(".")[0]
$SiteServerFQDN=($SiteServer+".inf."+$UDomainFQDN).ToLower()
$SiteCode=$(Get-PSDrive -PSProvider CMSite).Name
Set-Variable -Name SiteName -Value $null
Switch($SiteCode){
    "A01"{$SiteName="ARDC";Break}
    "B01"{$SiteName="UDCC";Break}
    Default{$SiteName=$null;Break}
}

#Set location within the SCCM environment
Set-location $SiteCode":"

#Service Accounts being used for SCCM
SetCredentials -SrvAccount $SecureUser
Set-Variable -Name SvcAccountExists -Value $null
$ClientInstallUser=($UDomain+"\"+$SecureCredentials.UserName)
$SvcAccountExists=Get-CMAccount -UserName $ClientInstallUser
If($SvcAccountExists-eq$null){
    New-CMAccount -UserName $ClientInstallUser -Password $SecureCredentials.Password -SiteCode $SiteCode|Out-Null
}

#Create and Configure Device Client Settings
Set-Variable -Name ClientObject -Value $null
Set-Variable -Name ClientSetting -Value $null
Set-Variable -Name ClientTypes -Value @("Servers","Workstations")
ForEach($ClientType In $ClientTypes){
    $ClientSetting=($($SiteName)+" - Client Computers ("+($($ClientType))+")")
    $ClientObject=Get-CMClientSetting -Name $ClientSetting
    If($ClientObject-eq$null){New-CMClientSetting -Name $ClientSetting -Type Device|Out-Null}
    Switch($ClientType){
        "Servers"{
            #Parameter Set: SetEndpointProtectionSettingsByName
#            Set-CMClientSetting -Name $ClientSetting -DisableFirstSignatureUpdate $true -EnableEndpointProtection $true -ForceRebootPeriod 24 -InstallEndpointProtectionClient $true -RemoveThirdParty $true -SuppressReboot $true -WhatIf

            #Parameter Set: SetHardwareInventorySettingsByName
#            Set-CMClientSetting -Name $ClientSetting -EnableHardwareInventory $true -InventorySchedule $HWScheduleServer -WhatIf

            #Parameter Set: SetSoftwareDeploymentSettingsByName
<#            Set-CMClientSetting -Name $ClientSetting
                [-EvaluationSchedule <IResultObject> ] #>

            #Parameter Set: SetSoftwareInventorySettingsByName
<#            Set-CMClientSetting -Name $ClientSetting
                [-EnableSoftwareInventory <Boolean> ]
                [-SoftwareInventoryFileDisplayName <String> ]
                [-SoftwareInventoryFileInventoriedName <String> ]
                [-SoftwareInventoryFileName <String> ]
                [-SoftwareInventorySchedule <IResultObject> ] #>

            #Parameter Set: SetSoftwareUpdatesSettingsByName
<#            Set-CMClientSetting -Name $ClientSetting
                [-BatchingTimeout <Int32> ]
                [-DeploymentEvaluationSchedule <IResultObject> ]
                [-EnableSoftwareUpdatesOnClient <Boolean> ]
                [-EnforceMandatory <Boolean> ]
                [-ScanSchedule <IResultObject> ]
                [-TimeUnit <BatchingTimeoutType> {Days | Hours} ] #>
            #>
            Break
        }
        Default{
            #Parameter Set: SetEndpointProtectionSettingsByName
<#            Set-CMClientSetting -Name $ClientSetting
                [-DisableFirstSignatureUpdate <Boolean> ]
                [-EnableEndpointProtection <Boolean> ]
                [-ForceRebootPeriod <Int32> ]
                [-InstallEndpointProtectionClient <Boolean> ]
                [-RemoveThirdParty <Boolean> ]
                [-SuppressReboot <Boolean> ] #>

            #Parameter Set: SetHardwareInventorySettingsByName
<#            Set-CMClientSetting -Name $ClientSetting
                [-EnableHardwareInventory <Boolean> ]
                [-InventoryReportId <String> ]
                [-InventorySchedule <IResultObject> ] #>

            #Parameter Set: SetRemoteToolsSettingsByName
<#            Set-CMClientSetting -Name $ClientSetting
                [-AccessLevel <AccessLevelType> {FullControl | NoAccess | ViewOnly} ]
                [-AllowClientChange <Boolean> ]
                [-AllowPermittedViewersToRemoteDesktop <Boolean> ]
                [-AllowRemoteControlOfUnattendedComputer <Boolean> ]
                [-AudibleSignal <AudibleSignalType> {PlayNoSound | PlaySoundAtBeginAndEnd | PlaySoundRepeatedly} ]
                [-FirewallExceptionProfile {Disabled | Domain | Private | Public}[] ]
                [-GrantRemoteControlPermissionToLocalAdministrator <Boolean> ]
                [-ManageRemoteDesktopSetting <Boolean> ]
                [-ManageSolicitedRemoteAssistance <Boolean> ]
                [-ManageUnsolicitedRemoteAssistance <Boolean> ]
                [-PermittedViewer <String[]> ]
                [-PromptUserForPermission <Boolean> ]
                [-RemoteAssistanceAccessLevel <RemoteAssistanceAccessLevelType> {FullControl | None | RemoteViewing} ]
                [-RequireAuthentication <Boolean> ]
                [-ShowNotificationIconOnTaskbar <Boolean> ]
                [-ShowSessionConnectionBar <Boolean> ] #>

            #Parameter Set: SetSoftwareDeploymentSettingsByName
<#            Set-CMClientSetting -Name $ClientSetting
                [-EvaluationSchedule <IResultObject> ] #>

            #Parameter Set: SetSoftwareInventorySettingsByName
<#            Set-CMClientSetting -Name $ClientSetting
                [-EnableSoftwareInventory <Boolean> ]
                [-SoftwareInventoryFileDisplayName <String> ]
                [-SoftwareInventoryFileInventoriedName <String> ]
                [-SoftwareInventoryFileName <String> ]
                [-SoftwareInventorySchedule <IResultObject> ] #>

            #Parameter Set: SetSoftwareUpdatesSettingsByName
<#            Set-CMClientSetting -Name $ClientSetting
                [-BatchingTimeout <Int32> ]
                [-DeploymentEvaluationSchedule <IResultObject> ]
                [-EnableSoftwareUpdatesOnClient <Boolean> ]
                [-EnforceMandatory <Boolean> ]
                [-ScanSchedule <IResultObject> ]
                [-TimeUnit <BatchingTimeoutType> {Days | Hours} ] #>
            #>
            Break
        }
    }
}

#Set location back to operating system
<#
Set-Location -Path $CurrentLocation #>
