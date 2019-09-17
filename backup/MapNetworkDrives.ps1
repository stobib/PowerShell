Clear-Host;Clear-History
Set-Location ($env:SystemRoot+"\System32")
$CurrentLocation=Get-Location
Set-Variable -Name SecureCredentials -Value $null
If((!($env:USERDNSDOMAIN)-eq$null)-or($env:USERDNSDOMAIN)-eq"home.net"){
    $Global:DomainA=($env:USERDNSDOMAIN.ToLower())
}
$Global:DomainB=("utshare.local")
$Global:Validate=$null
$Global:UserAccount="sy1000829946"
$Global:SecureUserDA=($env:USERNAME+"@"+$DomainA)
$Global:SecureUserDB=($UserAccount+"@"+$DomainB)
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
Function SetCredentials{[CmdletBinding()]Param([String][Parameter(Mandatory=$true)]$SecureUser="",[String][Parameter(Mandatory=$true)]$Domain="")
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
            $EncryptedString=$null;$BSTR=$null
        }
    }
    $EncryptedString=$null;$BSTR=$null
    $script:SecureCredentials=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SecureUser,$SecureString
    Return $Validate
}
Clear
Set-Variable -Name Loops -Value 0
Set-Variable -Name LoopCount -Value 0
Do{
    Set-Variable -Name utsis -Value ("grey."+$DomainA)
    Set-Variable -Name utshare -Value ($DomainB+"\replication")
    If(($DomainA-eq$DomainB)-or($DomainA-eq$null)){
        Set-Variable -Name Drives -Value @("S","W")
    }Else{
        Set-Variable -Name Drives -Value @("G","S","W")
    }
    $Domain=($DomainB).split(".")[0]
    ForEach($Drive In $Drives){
        Set-Variable -Name ShareName -Value $null
        Switch ($Drive){
            "G"{$Validate=SetCredentials -SecureUser $SecureUserDA -Domain ($DomainA).split(".")[0]
                $SecureUser=($env:USERNAME+"@"+$DomainA)
                $ShareName=("\\"+$utsis+"\apps")
                Break}
            "S"{$Validate=SetCredentials -SecureUser $SecureUserDB -Domain ($DomainB).split(".")[0]
                $SecureUser=($Domain+"\"+$UserAccount)
                $ShareName=("\\"+$utshare+"\SysAdmins")
                Break}
            "W"{$Validate=SetCredentials -SecureUser $SecureUserDB -Domain ($DomainB).split(".")[0]
                $SecureUser=($Domain+"\"+$UserAccount)
                $UserShare=($SecureUserDB.SubString(0,2)+"\"+$SecureUserDB.Substring(0,12))
                $ShareName=("\\"+$utshare+"\Users\"+$UserShare)
                Break}
        }
        $NetName=$ShareName.Replace("\","\\")
        $NetDrive = Get-WmiObject -Class Win32_mappedLogicalDisk -filter ("ProviderName='"+$NetName+"'")
        If($NetDrive.Name-ne$null){net use $NetDrive.Name /delete}
        Net Use ($Drive+":") $ShareName /user:$SecureUser $Validate /Persistent:NO;$Validate=$null
    }
    $LoopCount++
}While($LoopCount-le$Loops)
Set-Location -Path $CurrentLocation
