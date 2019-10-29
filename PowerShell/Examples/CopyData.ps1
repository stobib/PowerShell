Clear-Host;Clear-History
Set-Location $env:SystemRoot\System32
$CurrentLocation=Get-Location
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
Set-Variable -Name Loops -Value 0
Set-Variable -Name LoopCount -Value 0
Clear
Do{
    Set-Variable -Name Domain -Value $env:USERDNSDOMAIN.ToLower()
    Set-Variable -Name SecureUser -Value $env:USERNAME@$Domain
    Set-Variable -Name WorkingPath -Value "$env:USERProfile\AppData\Local\$Domain\Credentials"
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
        }
    }
	$WorkingPath="$env:USERProfile\AppData\Local\Temp"
    Set-Variable -Name SrcSrvr -Value "fs8600a01.inf.$Domain"
    Set-Variable -Name DecSrvr -Value "w16adfs01.inf.$Domain"
    Set-Variable -Name Options -Value '/XA:RSH'
    Set-Variable -Name NetDrvs -Value $null
    Set-Variable -Name LastDrv -Value $null
    Set-Variable -Name Counter -Value 0
    Set-Location -Path $WorkingPath
    $SecureCredentials=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SecureUser,$SecureString
    If($SrcSrvr.Substring(1,1)-ne":"){$SrcSrvr="\\$SrcSrvr"}
    If($DecSrvr.Substring(1,1)-ne":"){$DecSrvr="\\$DecSrvr"}
    Set-Variable -Name NetDrvs -Value "D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"
    $DrvLtrs=Get-CimInstance -Class Win32_LogicalDisk
    Set-Variable -Name MapDrvList -Value $null
    $IntLoop=0
    Do{
        $Counter++
        $LastDrv=$null
        Switch($Counter){
            1{$CurPath=$SrcSrvr;Break}
            2{$CurPath=$DecSrvr;Break}
        }
        If($CurPath.Substring(0,2)-eq"\\"){
            ForEach($NetDrv In $NetDrvs){
                If($IntLoop-eq$Counter){Break}
                If(($LastDrv-eq$null)-or($MapDrvList-eq$NetDrv)){
                    ForEach($DrvLtr In $DrvLtrs.DeviceID){
                        $NetID=$NetDrv+':'
                        If(($DrvLtrs.DeviceID-notcontains"$NetID")-and($MapDrvList-notlike"*$NetDrv*")){
                            $IntLoop++
                            Switch($IntLoop){
                                1{$MapDrvList=$NetDrv;Break}
                                2{If($MapDrvList-eq$null){
                                        $MapDrvList=$NetDrv;Break
                                    }Else{
                                        $MapDrvList=$MapDrvList+","+$NetDrv;Break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }Until($Counter-eq2)
    $Shares="arshared","dashared","sashared","tyshared","projects","iso","Stat-Projects","Stat-Shared"
    Set-Variable -Name SrcDrv -Value $null
    Set-Variable -Name DesDrv -Value $null
    Set-Variable -Name Folders -Value $null
    $Counter=0
    ForEach($Share In $Shares){
        $CurrentSrc="$SrcSrvr\$Share"
        If($CurrentSrc.Substring(0,2)-eq"\\"){
            $SrcDrv=$MapDrvList.Substring(0,1)
            New-PSDrive -Name "$SrcDrv" -Root "$CurrentSrc" -Credential $SecureCredentials -Persist -PSProvider FileSystem
        }
        $Counter++
        If($Counter-le5){
            Switch($Counter){
                5{
                    $Share="developers\za"
                    Break}
                Default{
                    $Share="developers\"+$Share.ToString().Substring(0,2)
                    Break}
            }
        }
        $CurrentDes="$DecSrvr\$Share"
        If($CurrentDes.Substring(0,2)-eq"\\"){
            If($MapDrvList.Substring(1,1)-eq","){
                $DesDrv=$MapDrvList.Substring(2,1)
            }Else{
                $DesDrv=$MapDrvList.Substring(0,1)
            }
            New-PSDrive -Name "$DesDrv" -Root "$CurrentDes" -Credential $SecureCredentials -Persist -PSProvider FileSystem
        }
        Robocopy $SrcDrv":\" $DesDrv":\" '*.*' $Options /E /SL /MIR /R:0 /W:0 /XD ".clusterConfig" /XD "DfsrPrivate" /XD ".TemporaryItems" /XD "replica*" /XD "cache"
        If($SrcDrv-ne$null){Get-PSDrive $SrcDrv|Remove-PSDrive}
        If($DesDrv-ne$null){Get-PSDrive $DesDrv|Remove-PSDrive}
    }
    $CurrentSrc=$DecSrvr+"\sysadm"
    $CurrentDes=$DecSrvr+"\sysadmins"
    New-PSDrive -Name "$SrcDrv" -Root "$CurrentSrc" -Credential $SecureCredentials -Persist -PSProvider FileSystem
    New-PSDrive -Name "$DesDrv" -Root "$CurrentDes" -Credential $SecureCredentials -Persist -PSProvider FileSystem
    Robocopy $SrcDrv":\" $DesDrv":\" '*.*' $Options /E /SL /MIR /R:0 /W:0 /XD /XD ".clusterConfig" /XD "DfsrPrivate" /XD ".TemporaryItems" /XD "replica*" /XD "cache"
    If($SrcDrv-ne$null){Get-PSDrive $SrcDrv|Remove-PSDrive}
    If($DesDrv-ne$null){Get-PSDrive $DesDrv|Remove-PSDrive}
    $Folders="ar","da","ep","pb","rg","sa","sy","ty"
    ForEach($Folder In $Folders){
        $CurrentSrc=$DecSrvr+"\working"
        $CurrentDes=$DecSrvr+"\users"
        New-PSDrive -Name "$SrcDrv" -Root "$CurrentSrc" -Credential $SecureCredentials -Persist -PSProvider FileSystem
        New-PSDrive -Name "$DesDrv" -Root "$CurrentDes" -Credential $SecureCredentials -Persist -PSProvider FileSystem
#        Remove-Item $DesDrv":\"$Folder -Recurse -Force
        Robocopy $SrcDrv":\"$Folder $DesDrv":\"$Folder '*.*' $Options /E /SL /COPYALL /R:0 /W:0 /XD /XD ".clusterConfig" /XD "DfsrPrivate" /XD ".TemporaryItems" /XD "replica*" /XD "cache"
        If($SrcDrv-ne$null){Get-PSDrive $SrcDrv|Remove-PSDrive}
        If($DesDrv-ne$null){Get-PSDrive $DesDrv|Remove-PSDrive}
    }
    $LoopCount++
}While($LoopCount-le$Loops)
Set-Location -Path $CurrentLocation
