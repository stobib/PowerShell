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
Function Get-ExistingFile{
    $Results=Get-ChildItem -Path $WorkingPath -File
    ForEach($File In $Results){
        $Properties=Get-ItemProperty "$File"
        $CreationDate=(Get-ChildItem $Properties.Name).CreationTime
        $KeyDate=(Get-Date $CreationDate -Format g).Split(" ")[0]
        $KeyTime=(Get-Date $CreationDate -Format g).Split(" ")[1]
        $KeyDays=(Get-Date $CreationDate).DayOfYear
        $KeyYear=$KeyDate.Split("/")[2]
        $KeyDate=[Int]$KeyYear+$KeyDays
        $KeyTime=$KeyTime.Split(":")
        $KeyTime=$KeyTime[0]+$KeyTime[1]
        [Int]$KeyPair=$KeyTime+$KeyDate
        $KeyPair=$KeyPair/2
        $FileName=$($File.Name).Split(".")[0]
        If($FileName.length-notin"8,12,16"){
            $KeyFile="$($File.Name)"
            $Key=$($KeyFile).Split(".")[0]
            $KeyCode=$Key-$KeyPair
            If(([System.Text.Encoding]::Unicode).GetByteCount($KeyCode)*8-notin"128,192,256"){
                Set-Variable -Name "EncryptionKeyFile" -Value "$WorkingPath\$KeyFile"
                $SecureKey=ConvertTo-SecureString -String $KeyCode -AsPlainText -Force
                $PrivateKey=Get-Content -Path $EncryptionKeyFile|ConvertTo-SecureString -SecureKey $SecureKey
                $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PrivateKey)
                $Mask=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                Break
            }
        }
    }
}
Function Process-SecureString{[CmdletBinding()]param([String][Parameter(Position=0,Mandatory=$true)]$Key,[String][Parameter(Position=1,Mandatory=$true)]$Password)
}
Function Process-String{[CmdletBinding()]param([String][Parameter(Position=0,Mandatory=$true)]$Key,[String][Parameter(Position=1,Mandatory=$true)]$PassPhrase,[String][Parameter(Position=2,Mandatory=$true)]$Password)
    $Base=$PassPhrase.Length/$Key.Length
    $Base=[Math]::Truncate($Base)
    $PassPhrase=$PassPhrase.Substring(0,($PassPhrase.Length-$Key.Length))
    $PassPhrase=$PassPhrase.Substring(0,($PassPhrase.Length-$Password.Length))
    $Mask=$PassPhrase.Length/8
    $Mask=[Math]::Truncate($Mask)
    [Int]$a=0;[Int]$b=0;[Int]$c=0;[Int]$d=0;[Int]$e=0;[Int]$f=0;[Int]$g=0
    Try{
        Do{
            ForEach($Char In $PassPhrase.Substring($a,1)){
                Switch($b){
                    {($_-in0,8,16,24,32,40,48,56,64,72,80,88,96,104,112,120,128,136,144,152,160,168,176,184,192,200,208,216,224,232,240,248)}{
                        $Part1+=$Char;Break}
                    {($_-in1,9,17,25,33,41,49,57,65,73,81,89,97,105,113,121,129,137,145,153,161,169,177,185,193,201,209,217,225,233,241,249)}{
                        $Part2+=$Char;Break}
                    {($_-in2,10,18,26,34,42,50,58,66,74,82,90,98,106,114,122,130,138,146,154,162,170,178,186,194,202,210,218,226,234,242,250)}{
                        $Part3+=$Char;Break}
                    {($_-in3,11,19,27,35,43,51,59,67,75,83,91,99,107,115,123,131,139,147,155,163,171,179,187,195,203,211,219,227,235,243,251)}{
                        $Part4+=$Char;Break}
                    {($_-in4,12,20,28,36,44,52,60,68,76,84,92,100,108,116,124,132,140,148,156,164,172,180,188,196,204,212,220,228,236,244,252)}{
                        $Part5+=$Char;Break}
                    {($_-in5,13,21,29,37,45,53,61,69,77,85,93,101,109,117,125,133,141,149,157,165,173,181,189,197,205,213,221,229,237,245,253)}{
                        $Part6+=$Char;Break}
                    {($_-in6,14,22,30,38,46,54,62,70,78,86,94,102,110,118,126,134,142,150,158,166,174,182,190,198,206,214,222,230,238,246,254)}{
                        $Part7+=$Char;Break}
                    {($_-in7,15,23,31,39,47,55,63,71,79,87,95,103,111,119,127,135,143,151,159,167,175,183,191,199,207,215,223,231,239,247,255)}{
                        $Part8+=$Char;Break}
                }
                $a++;$b++
                If($b-eq$Base){
                    $b=0
                }
            }
        }Until($a-eq$PassPhrase.Length)
        Do{
            Switch($c){
                {($_-in0,8)}{
                    $e=((1..$Part1.Length)|Get-Random -Count 1)
                    [char]$Key1=($ExtAskii+$Key.Substring($_,1))
                    $l=$Part1.Substring(0,$e)
                    $r=$Part1.Substring($e,($Part1.Length-$l.Length))
                    $Part1=$l+$Key1+$r
                    Break
                }
                {($_-in1,9)}{
                    $e=((1..$Part2.Length)|Get-Random -Count 1)
                    [char]$Key2=($ExtAskii+$Key.Substring($_,1))
                    $l=$Part2.Substring(0,$e)
                    $r=$Part2.Substring($e,($Part2.Length-$l.Length))
                    $Part2=$l+$Key2+$r
                    Break
                }
                {($_-in2,10)}{
                    $e=((1..$Part3.Length)|Get-Random -Count 1)
                    [char]$Key3=($ExtAskii+$Key.Substring($_,1))
                    $l=$Part3.Substring(0,$e)
                    $r=$Part3.Substring($e,($Part3.Length-$l.Length))
                    $Part3=$l+$Key3+$r
                    Break
                }
                {($_-in3,11)}{
                    $e=((1..$Part4.Length)|Get-Random -Count 1)
                    [char]$Key4=($ExtAskii+$Key.Substring($_,1))
                    $l=$Part4.Substring(0,$e)
                    $r=$Part4.Substring($e,($Part4.Length-$l.Length))
                    $Part4=$l+$Key4+$r
                    Break
                }
                {($_-in4,12)}{
                    $e=((1..$Part5.Length)|Get-Random -Count 1)
                    [char]$Key5=($ExtAskii+$Key.Substring($_,1))
                    $l=$Part5.Substring(0,$e)
                    $r=$Part5.Substring($e,($Part5.Length-$l.Length))
                    $Part5=$l+$Key5+$r
                    Break
                }
                {($_-in5,13)}{
                    $e=((1..$Part6.Length)|Get-Random -Count 1)
                    [char]$Key6=($ExtAskii+$Key.Substring($_,1))
                    $l=$Part6.Substring(0,$e)
                    $r=$Part6.Substring($e,($Part6.Length-$l.Length))
                    $Part6=$l+$Key6+$r
                    Break
                }
                {($_-in6,14)}{
                    $e=((1..$Part7.Length)|Get-Random -Count 1)
                    [char]$Key7=($ExtAskii+$Key.Substring($_,1))
                    $l=$Part7.Substring(0,$e)
                    $r=$Part7.Substring($e,($Part7.Length-$l.Length))
                    $Part7=$l+$Key7+$r
                    Break
                }
                {($_-in7,15)}{
                    $e=((1..$Part8.Length)|Get-Random -Count 1)
                    [char]$Key8=($ExtAskii+$Key.Substring($_,1))
                    $l=$Part8.Substring(0,$e)
                    $r=$Part8.Substring($e,($Part8.Length-$l.Length))
                    $Part8=$l+$Key8+$r
                    Break
                }
            }
            $c++
        }Until($c-eq$Key.Length)
        Do{
            Switch($d){
                {($_-in0,8,16,24,32,40,48,56,64,72,80,88,96,104,112,120,128,136,144,152,160,168,176,184,192,200,208,216,224,232,240,248)}{
                    $e=(($g..($g+7))|Get-Random -Count 1)
                    [int][char]$f=$Password.Substring($_,1);[char]$Key1=($ExtAspii+$f)
                    $l=$Part1.Substring(0,$e);$r=$Part1.Substring($e,($Part1.Length-$l.Length))
                    $Part1=$l+$Key1+$r
                    Break
                }
                {($_-in1,9,17,25,33,41,49,57,65,73,81,89,97,105,113,121,129,137,145,153,161,169,177,185,193,201,209,217,225,233,241,249)}{
                    $e=(($g..($g+7))|Get-Random -Count 1)
                    [int][char]$f=$Password.Substring($_,1);[char]$Key2=($ExtAspii+$f)
                    $l=$Part2.Substring(0,$e);$r=$Part2.Substring($e,($Part2.Length-$l.Length))
                    $Part2=$l+$Key2+$r
                    Break
                }
                {($_-in2,10,18,26,34,42,50,58,66,74,82,90,98,106,114,122,130,138,146,154,162,170,178,186,194,202,210,218,226,234,242,250)}{
                    $e=(($g..($g+7))|Get-Random -Count 1)
                    [int][char]$f=$Password.Substring($_,1);[char]$Key3=($ExtAspii+$f)
                    $l=$Part3.Substring(0,$e);$r=$Part3.Substring($e,($Part3.Length-$l.Length))
                    $Part3=$l+$Key3+$r
                    Break
                }
                {($_-in3,11,19,27,35,43,51,59,67,75,83,91,99,107,115,123,131,139,147,155,163,171,179,187,195,203,211,219,227,235,243,251)}{
                    $e=(($g..($g+7))|Get-Random -Count 1)
                    [int][char]$f=$Password.Substring($_,1);[char]$Key4=($ExtAspii+$f)
                    $l=$Part4.Substring(0,$e);$r=$Part4.Substring($e,($Part4.Length-$l.Length))
                    $Part4=$l+$Key4+$r
                    Break
                }
                {($_-in4,12,20,28,36,44,52,60,68,76,84,92,100,108,116,124,132,140,148,156,164,172,180,188,196,204,212,220,228,236,244,252)}{
                    $e=(($g..($g+7))|Get-Random -Count 1)
                    [int][char]$f=$Password.Substring($_,1);[char]$Key5=($ExtAspii+$f)
                    $l=$Part5.Substring(0,$e);$r=$Part5.Substring($e,($Part5.Length-$l.Length))
                    $Part5=$l+$Key5+$r
                    Break
                }
                {($_-in5,13,21,29,37,45,53,61,69,77,85,93,101,109,117,125,133,141,149,157,165,173,181,189,197,205,213,221,229,237,245,253)}{
                    $e=(($g..($g+7))|Get-Random -Count 1)
                    [int][char]$f=$Password.Substring($_,1);[char]$Key6=($ExtAspii+$f)
                    $l=$Part6.Substring(0,$e);$r=$Part6.Substring($e,($Part6.Length-$l.Length))
                    $Part6=$l+$Key6+$r
                    Break
                }
                {($_-in6,14,22,30,38,46,54,62,70,78,86,94,102,110,118,126,134,142,150,158,166,174,182,190,198,206,214,222,230,238,246,254)}{
                    $e=(($g..($g+7))|Get-Random -Count 1)
                    [int][char]$f=$Password.Substring($_,1);[char]$Key7=($ExtAspii+$f)
                    $l=$Part7.Substring(0,$e);$r=$Part7.Substring($e,($Part7.Length-$l.Length))
                    $Part7=$l+$Key7+$r
                    Break
                }
                {($_-in7,15,23,31,39,47,55,63,71,79,87,95,103,111,119,127,135,143,151,159,167,175,183,191,199,207,215,223,231,239,247,255)}{
                    $e=(($g..($g+7))|Get-Random -Count 1)
                    [int][char]$f=$Password.Substring($_,1);[char]$Key8=($ExtAspii+$f)
                    $l=$Part8.Substring(0,$e);$r=$Part8.Substring($e,($Part8.Length-$l.Length))
                    $Part8=$l+$Key8+$r
                    Break
                }
            }
            $d++
            Switch($d){
                {($_-in8,16,24,32,40,48,56,64,72,80,88,96,104,112,120,128,136,144,152,160,168,176,184,192,200,208,216,224,232,240,248)}
                    {$g+=$d;Break}
            }
        }Until($d-eq$Password.Length)
        Return $Part1+$Part2+$Part3+$Part4+$Part5+$Part6+$Part7+$Part8
    }Catch [Exception]{
        If($_.Exception.Message-eq"Cannot find a variable with the name '$Item'."){
        }Else{
            $Message=$_.Exception.Message
            Write-Host $Message -ForegroundColor Yellow -BackgroundColor DarkRed
        }
    }Finally{
        ClearVariables -VariableList 'Part1','Part2','Part3','Part4','Part5','Part6','Part7','Part8'
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
ClearVariables -VariableList 'KeyDate','KeyDays','KeyTime','KeyYear''Part1','Part2','Part3','Part4','Part5','Part6','Part7','Part8'
Set-Location -Path "$($env:USERProfile)\Documents"
Set-Variable -Name "AuthUser" -Value "stobib@hotmail.com"
Set-Variable -Name "WorkingPath" -Value "$env:USERProfile\Documents\Passwords"
Set-Variable -Name "SecureFile" -Value "$WorkingPath\Encrypted.pwd"
Set-Variable -Name "Characters" -Value ""
Set-Variable -Name "PrivateKey" -Value ""
Set-Variable -Name "SecureKey" -Value ""
Set-Location -Path $WorkingPath
[Int]$ExtAskii=48
[Int]$ExtAspii=130
[String]$Key=0
[Int]$Min=128
[Int]$Max=2048
$Results=
If(Test-Path -Path $SecureFile){
    $Results=Get-ExistingFile
}Else{
    Do{
        $Prompt="Enter the length you want to use for the security key: [8,12,16]"
        [Int]$RandomKey=Read-Host -Prompt $Prompt
        If($RandomKey-notin8,12,16){
            $Valid=$false
        }Else{
            $Valid=$true
        }
        Clear
    }While($Valid-eq$false)
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
    [Int]$KeyCode=$Key
    $Prompt="Enter the amount of characters you want to use for the encryption key: [min $Min, max $Max]"
    Do{
        [Int]$Characters=Read-Host -Prompt $Prompt
        If(($Characters-ge$Min)-and($Characters-le$Max)){
        }Else{
            $Prompt="Please enter a value between the minimum '$Min' and maximum '$Max' range"
        }
        Clear
    }Until(($Characters-ge$Min)-and($Characters-le$Max))
    For($i=0;$i-le$Characters;$i++){
        Switch($i){
            {($_-gt0)-and($_-le$Characters)}{$Set=-join((65..90)+(97..122)|Get-Random -Count 1|%{[Char]$_});Break}
            Default{$PrivateKey="";$Set="";Break}
        }
        $PrivateKey+=$Set
    }
    $KeyDate=(Get-Date -Format g).Split(" ")[0]
    $KeyTime=(Get-Date -Format g).Split(" ")[1]
    $KeyDays=(Get-Date).DayOfYear
    $KeyYear=$KeyDate.Split("/")[2]
    $KeyDate=[Int]$KeyYear+$KeyDays
    $KeyTime=$KeyTime.Split(":")
    $KeyTime=$KeyTime[0]+$KeyTime[1]
    [Int]$KeyPair=$KeyTime+$KeyDate
    $KeyPair=($KeyPair/2)+$KeyCode
    Set-Variable -Name "EncryptionKeyFile" -Value "$WorkingPath\$KeyPair.key"
    $SecureKey=ConvertTo-SecureString -String $Key -AsPlainText -Force
    ConvertTo-SecureString $PrivateKey -AsPlainText -Force|ConvertFrom-SecureString -SecureKey $SecureKey
    Protect-String $PrivateKey $Key|Out-File -Filepath $EncryptionKeyFile
    $Prompt="Enter the password that you want to set for account: [$AuthUser]"
    $SecureString=Read-Host -Prompt "Enter your [$AuthUser] credentials" -AsSecureString
    $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    $UnSecureString=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    $PrivateWord=Process-String $Key $PrivateKey $UnSecureString
    Protect-String $PrivateWord $Key|Out-File -Filepath $SecureFile
}
Clear-Host
$UnEncrypted=Process-SecureString $KeyPair $PrivateWord
Try{
    $Validate=Get-Content -Path $SecureFile|ConvertTo-SecureString -SecureKey $SecureKey -ErrorAction Stop
    $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Validate)
    $Validate=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}Catch [Exception]{
    $Message="Error: [Validation]: $($_.Exception.Message)";Write-Host $Message -ForegroundColor Yellow -BackgroundColor DarkRed
}Finally{
    ClearVariables -VariableList 'AuthUser','BSTR','Characters','EncryptedString','EncryptionKeyFile','File','FileName','i','Key','Mask','Max','Message','Min','PrivateKey','Prompt','RandomKey','Results','SecureFile','SecureKey','SecureString','Set','Validate','WorkingPath'
    Set-Location -Path "$env:SystemRoot\System32"
}