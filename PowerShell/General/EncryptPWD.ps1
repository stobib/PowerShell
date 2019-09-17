<#Function ClearVariables{[CmdletBinding(SupportsShouldProcess)]param()
    If($StartupVariables){
        $UserVariables=Get-Variable -Exclude $StartupVariables -Scope Global
        ForEach($UserItem In $UserVariables){
            Try{
                Clear-Variable -Name "UserItem" -Force -Scope Global -ErrorAction SilentlyContinue
            }Catch [Exception]{
                If($($_.Exception.Message)-eq"Cannot find a variable with the name '$($UserItem.Name)'."){
                }Else{
                    $Message="Error: [ClearVariables]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Yellow -BackgroundColor DarkRed
                }
            }
        }
    }
}#>
Function ClearVariables{[CmdletBinding()]param([Parameter(Mandatory=$true)]$VariableList=@())
    Try{
        ForEach($Item In $VariableList){
            If($Item.length-lt1){
            }Else{
                Set-Variable -Name $Item -Value $null
                Clear-Variable -Name $Item -Scope Global -Force -ErrorAction SilentlyContinue
            }
        }
    }Catch [Exception]{
        If($_.Exception.Message-eq"Cannot find a variable with the name '$Item'."){
        }Else{
            $Message=$_.Exception.Message
            Write-Host $Message -ForegroundColor Yellow -BackgroundColor DarkRed
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
Clear-Host;Clear-History
Set-Location -Path "$($env:USERProfile)\Documents"
Set-Variable -Name "AuthUser" -Value "bstobie@utsystem.edu"
Set-Variable -Name "WorkingPath" -Value "$env:USERProfile\Documents\Passwords"
Set-Variable -Name "SecureFile" -Value "$WorkingPath\Encrypted.pwd"
Set-Variable -Name "EncryptionKeyFile" -Value ""
Set-Variable -Name "Characters" -Value ""
Set-Variable -Name "PrivateKey" -Value ""
Set-Variable -Name "SecureKey" -Value ""
[String]$Key=0
[Int]$Min=8
[Int]$Max=1024
$Prompt="Enter the length you want to use for the security key: [up to 16 bytes]"
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
    $SecureString=Read-Host -Prompt "Enter your [$AuthUser] credentials" -AsSecureString
    $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    $EncryptedString=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    $EncryptedString|ConvertTo-SecureString -AsPlainText -Force|ConvertFrom-SecureString -SecureKey $SecureKey|Out-File -FilePath $SecureFile
}
Clear-Host;Clear-History
Try{
    $Validate=Get-Content -Path $SecureFile|ConvertTo-SecureString -SecureKey $SecureKey -ErrorAction Stop
    $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Validate)
    $Validate=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}Catch [Exception]{
    $Message="Error: [Validation]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Yellow -BackgroundColor DarkRed
}Finally{
    ClearVariables -VariableList 'AuthUser','BSTR','Characters','EncryptedString','EncryptionKeyFile','File','FileName','i','Key','Max','Message','Min','PrivateKey','Prompt','RandomKey','Results','SecureFile','SecureKey','SecureString','Set','Validate','WorkingPath'
}