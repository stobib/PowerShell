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
Set-Variable -Name SecureUser -Value "zasvccm_sr"

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

#If the Site System Server doesn't exist, create a new Site System Server
Set-Variable -Name ActiveSiteSystem -Value $null
$ActiveSiteSystem=Get-CMSiteSystemServer -SiteSystemServerName $SiteServerFQDN
If($ActiveSiteSystem-eq$null){
    New-CMSiteSystemServer -SiteSystemServerName $SiteServerFQDN -SiteCode $SiteCode
}

#Service Accounts being used for SCCM
SetCredentials -SrvAccount $SecureUser
Set-Variable -Name SvcAccountExists -Value $null
$ReportServerUser=($UDomain+"\"+$SecureCredentials.UserName)
$SvcAccountExists=Get-CMAccount -UserName $ReportServerUser
If($SvcAccountExists-eq$null){
    New-CMAccount -UserName $ReportServerUser -Password $SecureCredentials.Password -SiteCode $SiteCode|Out-Null
}
$ReportingDatabase=("CM_"+$SiteCode)

#Add Site System Roles
Set-Variable -Name ApplicationCatalogWeb -Value $null
Set-Variable -Name ApplicationCatalogWebSite -Value $null
Set-Variable -Name SoftwareUpdatePoint -Value $null
Set-Variable -Name EndpointProtectionPoint -Value $null
Set-Variable -Name ReportingServicePoint -Value $null
$ApplicationCatalogWeb=Get-CMApplicationCatalogWebServicePoint
If($ApplicationCatalogWeb-eq$null){
    Add-CMApplicationCatalogWebServicePoint -SiteSystemServerName $SiteServerFQDN -SiteCode $SiteCode -CommunicationType Https -Verbose|Out-Null
}
$SoftwareUpdatePoint=Get-CMSoftwareUpdatePoint
If($SoftwareUpdatePoint-eq$null){
    Add-CMSoftwareUpdatePoint -SiteSystemServerName $SiteServerFQDN -SiteCode $SiteCode -WsusIisPort 8530 -WsusIisSslPort 8531 -Verbose|Out-Null
}
$EndpointProtectionPoint=Get-CMEndpointProtectionPoint
If($EndpointProtectionPoint-eq$null){
    Add-CMEndpointProtectionPoint -SiteSystemServerName $SiteServerFQDN -SiteCode $SiteCode -ProtectionService AdvancedMembership -Verbose|Out-Null
}
$ReportingServicePoint=Get-CMReportingServicePoint
If($ReportingServicePoint-eq$null){
    Add-CMReportingServicePoint -ReportServerInstance "SSRS" -SiteCode $SiteCode -SiteSystemServerName $SiteServerFQDN -UserName $ReportServerUser -DatabaseServerName $SiteServerFQDN -DatabaseName $ReportingDatabase -Verbose|Out-Null
}
$ApplicationCatalogWebSite=Get-CMApplicationCatalogWebsitePoint
If($ApplicationCatalogWebSite-eq$null){
    $ApplicationCatalogWeb=Get-CMApplicationCatalogWebServicePoint
    If($ApplicationCatalogWeb-ne$null){
        Add-CMApplicationCatalogWebsitePoint -ApplicationWebServicePointServerName $ApplicationCatalogWeb.NetworkOSPath -SiteSystemServerName $SiteServerFQDN -SiteCode $SiteCode -CommunicationType Https -OrganizationName "UTS SIS Configuration Manager ($($SiteName))" -Verbose|Out-Null
    }
}

#Set location back to operating system
Set-Location -Path $CurrentLocation
