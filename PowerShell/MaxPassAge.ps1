[CmdletBinding()]
param(
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Username,
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][uint64]$MaxPwdAge,
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string[]]$LogFileNames=@()
)
# NOTE: The below default parameter value option can be used to set default values to command line parameters
$DefaultParameterValues=@{"LogFileNames"="MaxPwdAge";"MaxPwdAge"=365}
If(!($LogFileNames)){$LogFileNames+=($DefaultParameterValues.LogFileNames)}
If(!($MaxPwdAge)){$MaxPwdAge=($DefaultParameterValues.MaxPwdAge)}
<#             http://msdn.microsoft.com/en-us/library/x83z1d9f(v=vs.84).aspx
             intButton=object.Popup(strText,[nSecondsToWait],[strTitle],[nType])              #>
<# Button Types
                    Decimal value    Hexadecimal value    Description
                    0                0x0                  Show OK button.
                    1                0x1                  Show OK and Cancel buttons.
                    2                0x2                  Show Abort, Retry, and Ignore buttons.
                    3                0x3                  Show Yes, No, and Cancel buttons.
                    4                0x4                  Show Yes and No buttons.
                    5                0x5                  Show Retry and Cancel buttons.
                    6                0x6                  Show Cancel, Try Again, and Continue buttons.
#>#             Button Types
<# Icon Types
                    Decimal value    Hexadecimal value    Description
                    16               0x10                 Show "Stop Mark" icon.
                    32               0x20                 Show "Question Mark" icon.
                    48               0x30                 Show "Exclamation Mark" icon.
                    64               0x40                 Show "Information Mark" icon.
#>#             Icon Types
<# Return Value
                    Decimal value    Description
                    -1               The user did not click a button before nSecondsToWait seconds elapsed.
                    1                OK button
                    2                Cancel button
                    3                Abort button
                    4                Retry button
                    5                Ignore button
                    6                Yes button
                    7                No button
                    10               Try Again button
                    11               Continue button
#>#             Return Value
[datetime]$Global:StartTime=Get-Date -Format o
[datetime]$Global:EndTime=0
$Global:LogonServer=$null
Clear-History;Clear-Host
[boolean]$Global:bElevated=([System.Security.Principal.WindowsIdentity]::GetCurrent()).Groups -contains "S-1-5-32-544"
If($bElevated){
    Set-Variable -Name RestartNeeded -Value 0
    Set-Variable -Name Repositories -Value @('PSGallery')
    Set-Variable -Name PackageProviders -Value @('Nuget')
    Set-Variable -Name ModuleList -Value @('Rsat.ActiveDirectory.')
    Set-Variable -Name OriginalPref -Value $ProgressPreference
    # PowerShell Version (.NetFramework Error Checking) >>>--->
    [int]$PSVersion=([string]$PSVersionTable.PSVersion.Major+"."+[string]$PSVersionTable.PSVersion.Minor)
                                                                                                    If($PSVersion-lt7){
    $ProgressPreference="SilentlyContinue"
    Write-Host ("Please be patient while prerequisite modules are installed and loaded.")
    $NugetPackage=Find-PackageProvider -Name $PackageProviders
                        ForEach($Provider In $PackageProviders){
    $FindPackage=Find-PackageProvider -Name $Provider
    $GetPackage=Get-PackageProvider -Name $Provider
    If($FindPackage.Version-ne$GetPackage.Version){
        Install-PackageProvider -Name $FindPackage.Name -Force -Scope CurrentUser
    }
    }
        ForEach($Repository In $Repositories){
    Set-PSRepository -Name $Repository -InstallationPolicy Trusted
    }
                                ForEach($ModuleName In $ModuleList){
    $RSATCheck=Get-WindowsCapability -Name ($ModuleName+"*") -Online|Select-Object -Property Name,State
    If($RSATCheck.State-eq"NotPresent"){
        $InstallStatus=Add-WindowsCapability -Name $RSATCheck.Name -Online
        If($InstallStatus.RestartNeeded-eq$true){
            $RestartNeeded=1
        }
    }
    }
    Write-Host ("THe prerequisite modules are now installed and ready to process this script.")
    $ProgressPreference=$OriginalPref
    }
    # PowerShell Version (.NetFramework Error Checking) <---<<<
}
Import-Module ActiveDirectory
$ErrorActionPreference='SilentlyContinue'
[string]$Global:DomainUser=($env:USERNAME.ToLower())
[string]$Global:Domain=($env:USERDNSDOMAIN.ToLower())
[string]$Global:ScriptPath=$MyInvocation.MyCommand.Definition
[string]$Global:ScriptName=$MyInvocation.MyCommand.Name
Set-Location ($ScriptPath.Replace($ScriptName,""))
Set-Variable -Name System32 -Value ($env:SystemRoot+"\System32")
Switch($DomainUser){
    Default{$DomainUser=(($DomainUser+"@"+$Domain).ToLower());Break}
}
# Process Existing Log Files
[string]$Global:LogLocation=($ScriptPath.Replace($ScriptName,"")+"Logs\"+$ScriptName.Replace(".ps1",""))
[string]$Global:LogDate=Get-Date -Format "yyyy-MMdd"
[string[]]$LogFiles=@()
[int]$intCount=0
ForEach($LogFile In $LogFileNames){
    $intCount++
    New-Variable -Name "LogFN$($intCount)" -Value ([string]($LogLocation+"\"+$LogFile+$LogDate+".log"))
    $LogFiles+=(Get-Variable -Name "LogFN$($intCount)").Value
}
ForEach($LogFile In $LogFiles){
    If(Test-Path -Path $LogFile){
        $FileName=(Split-Path -Path $LogFile -Leaf).Replace(".log","")
        $Files=Get-Item -Path ($LogLocation+"\*.*")
        [int]$FileCount=0
        ForEach($File In $Files){
            If(!($File.Mode-eq"d----")-and($File.Name-like($FileName+"*"))){
                $FileCount++
            }
        }
        If($FileCount-gt0){
            Rename-Item -Path $LogFile -NewName ($FileName+"("+$FileCount+").log")
        }
    }
}
Clear-History;Clear-Host
# Script Body >>>--->> Unique code for Windows PowerShell scripting
[string]$Script:Greeting=""
If($Username-eq""){$Username=(([Security.Principal.WindowsIdentity]::GetCurrent()).name).split("\")[1]}
$PasswordAge=(New-TimeSpan -Start (Get-ADUser -Identity $Username -Properties PasswordLastSet).passwordlastset -End (Get-Date).Date).Days
$Global:ADUserAccount=Get-ADUser -Identity $Username -Properties *
If($PasswordAge-ge$MaxPwdAge){
        # Form design variables
    [uint16]$Script:FormWidth=536
    [uint16]$Script:FormHeight=280
    [uint16]$Script:MessageLabelTop=10
    [uint16]$Script:MessageLabelLeft=10
    [uint16]$Script:MessageLabelWidth=0
    [uint16]$Script:MessageLabelHeight=0
    [uint16]$Script:PasswordBoxTop=0
    [uint16]$Script:PasswordBoxLeft=0
    [uint16]$Script:PasswordBoxWidth=0
    [uint16]$Script:PasswordBoxHeight=0
    [uint16]$Script:YesButtonTop=0
    [uint16]$Script:YesButtonLeft=0
    [uint16]$Script:YesButtonWidth=90
    [uint16]$Script:YesButtonHeight=30
    [uint16]$Script:NoButtonTop=0
    [uint16]$Script:NoButtonLeft=0
    [uint16]$Script:NoButtonWidth=90
    [uint16]$Script:NoButtonHeight=30
    [string[]]$Script:Passwords=@()
    Do{
        [string]$PasswordLastSet=([datetime]($ADUserAccount.passwordlastset).Date).ToString("MM/dd/yyyy")
        [int]$HourOfDay=(Get-Date).Hour
        Switch($HourOfDay){
            {($_-lt12)}{$Greeting="morning";Break}
            {($_-lt18)}{$Greeting="afternoon";Break}
            Default{$Greeting="evening";Break}
        }
        $MessageTitle=("Maximum Password Age (Alert!)")
        $MessageBody=("Good "+$Greeting+" "+$ADUserAccount.GivenName+",`n`n")
        If(!($Passwords)){
            $MessageBody+=("Your password was last set on "+$PasswordLastSet+" which is "+$PasswordAge+" days ago.")
            $MessageBody+=("  The University of Texas System policy for maximum password age is "+$MaxPwdAge+" days.`n`n")
            $MessageBody+=("Please use this message box to change your password or press for key combination [Ctrl+Alt+End]")
            $MessageBody+=(" to enter the security menu on the remote desktop.`n`nIf you would like to use this form to ")
            $MessageBody+=("change your '"+$Domain+"' domain password, please enter the new password below and click the 'Yes' button.")
        }Else{
            $MessageBody+=("Your new password needs to be verified to ensure you typed it correctly.  Please retype ")
            $MessageBody+=("the password to confirm they were typed identically.  Only an exact match will be processed.")
        }
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
            # Form design
        $PopupMsg=New-Object System.Windows.Forms.Form
        $PopupMsg.Text=$MessageTitle
        $PopupMsg.Size=New-Object System.Drawing.Size($FormWidth,$FormHeight)
        $PopupMsg.StartPosition='CenterScreen'
            # Form Label values
        $MessageLabel=New-Object System.Windows.Forms.Label
        $MessageLabelWidth=[math]::Round($FormWidth-($MessageLabelLeft*2.5))
        $MessageLabelHeight=[math]::Round($MessageLabel.Font.Height*10)
        $MessageLabel.Location=New-Object System.Drawing.Point($MessageLabelLeft,$MessageLabelTop)
        $MessageLabel.Size=New-Object System.Drawing.Size($MessageLabelWidth,$MessageLabelHeight)
        $MessageLabel.Text=$MessageBody
        $PopupMsg.Controls.Add($MessageLabel)
            # Form Textbox values
        $PasswordBox=New-Object System.Windows.Forms.TextBox
        $PasswordBoxTop=[math]::Round(($MessageLabelTop*2)+$MessageLabelHeight)
        $PasswordBoxLeft=$MessageLabelLeft
        $PasswordBoxWidth=[math]::Round($MessageLabelWidth-($MessageLabelWidth/28))
        $PasswordBoxHeight=[math]::Round($PasswordBox.Font.Height*3)
        $PasswordBox.Location=New-Object System.Drawing.Point($PasswordBoxLeft,$PasswordBoxTop)
        $PasswordBox.Size=New-Object System.Drawing.Size($PasswordBoxWidth,$PasswordBoxHeight)
        $PasswordBox.PasswordChar="*"
        $PasswordBox.WordWrap=$false
        $PasswordBox.MaxLength=256
        $PasswordBox.Text=""
        $PopupMsg.Controls.Add($PasswordBox)
            # Botton variables
        $YesButton=New-Object System.Windows.Forms.Button
        $YesButtonTop=[math]::Round(($MessageLabelHeight+$PasswordBoxHeight)+$YesButtonHeight)
        $YesButtonLeft=[math]::Round(($FormWidth*.475)-($YesButtonWidth))
        $NoButtonLeft=[math]::Round($YesButtonLeft+($YesButtonWidth))
        $YesButton.Location=New-Object System.Drawing.Point($YesButtonLeft,$YesButtonTop)
        $YesButton.Size=New-Object System.Drawing.Size($YesButtonWidth,$YesButtonHeight)
        If(!($Passwords)){
            $YesButton.Text='&Yes'
            $YesButton.DialogResult=[System.Windows.Forms.DialogResult]::Yes
        }Else{
            $YesButton.Text='&OK'
            $YesButton.DialogResult=[System.Windows.Forms.DialogResult]::OK
        }
        $PopupMsg.AcceptButton=$YesButton
        $PopupMsg.Controls.Add($YesButton)
            # ["No"|Cancel] button design and action
        $NoButton=New-Object System.Windows.Forms.Button
        $NoButtonTop=$YesButtonTop
        $NoButton.Location=New-Object System.Drawing.Point($NoButtonLeft,$NoButtonTop)
        $NoButton.Size=New-Object System.Drawing.Size($NoButtonWidth,$NoButtonHeight)
        If(!($Passwords)){
            $NoButton.Text='&No'
        }Else{
            $NoButton.Text='&Cancel'
        }
        $NoButton.DialogResult=[System.Windows.Forms.DialogResult]::Cancel
        $PopupMsg.Controls.Add($NoButton)
            # Form Controls
        $PopupMsg.TopMost=$true
        $PopupMsg.Add_Shown({$PasswordBox.Select()})
            # Form results actions
        $Result=$PopupMsg.ShowDialog()
        $MinimumRequirement=$false
        Switch($Result){
            "Yes"{
                If($PasswordBox.Text-eq""){
                    Write-Host ("Sorry "+$ADUserAccount.GivenName+", but the password field is blank.  Please try again!")
                }Else{
                    [boolean]$bErrMsg=$false
                    [string]$ErrorTtl=""
                    [string]$ErrorMsg=""
                    Try{
                        $TestAgainstGPO=Get-ADDefaultDomainPasswordPolicy -Current LoggedOnUser
                        If($PasswordBox.Text.Length-ge$TestAgainstGPO.MinPasswordLength){
                            If(($PasswordBox.Text-cmatch'[a-z]')-and($PasswordBox.Text-cmatch'[A-Z]')-and($PasswordBox.Text-match'\d')-and($PasswordBox.Text.length-match'^([7-9]|[1][0-9]|[2][0-5])$')-and($PasswordBox.Text-match'!|@|#|%|^|&|$|_')){ 
                                $SecurePassword=ConvertTo-SecureString $PasswordBox.Text -AsPlainText -Force
                                If($SecurePassword){
                                    $Passwords+=$PasswordBox.Text
                                }
                            }Else{
                                $bErrMsg=$true
                                $ErrorTtl=("Password Complexity")
                                $ErrorMsg=("The password must meet 3 of the 4 complexity rules.  Uppercase, lowercase, numbers, and/or special characters.")
                            }
                        }Else{
                            $bErrMsg=$true
                            $ErrorTtl=("Minimum Password Length")
                            $ErrorMsg=("The password that you entered is too short.  The minimum length is "+$TestAgainstGPO.MinPasswordLength+" characters.")
                        }
                        If($bErrMsg){
                            $ErrorBox=New-Object -ComObject WScript.Shell
                            $intButton=$ErrorBox.Popup($ErrorMsg,10,$ErrorTtl,64)
                        }
                    }Catch{}
                }
                Break
            }
            "OK"{
                ForEach($Password In $Passwords){
                    If($Password-ceq$PasswordBox.Text){
                        $SecurePassword=ConvertTo-SecureString $PasswordBox.Text -AsPlainText -Force
                        If($SecurePassword){
                            $MinimumRequirement=$true
                        }
                    }
                    Break
                }
            }
            Default{
                $Result="Cancel"
                Break
            }
        }
        If($MinimumRequirement){
            Set-ADAccountPassword -Identity $ADUserAccount.sAMAccountName -NewPassword $SecurePassword
            ((Get-ADUser -Identity $ADUserAccount.Name -Properties PasswordLastSet).PasswordLastSet).Date.ToString("dddd, MMMM dd, yyyy")
            $Result="Cancel"
        }
    }Until($Result-eq"Cancel")
}
# Script Body <<---<<< Unique code for Windows PowerShell scripting
If($EndTime-eq0){
    [datetime]$EndTime=Get-Date -Format o
    $RunTime=(New-TimeSpan -Start $StartTime -End $EndTime)
    Write-Host ("Script runtime: ["+$RunTime+"]")
}Else{
    Write-Host ("Script runtime: ["+$RunTime.Hours+":"+$RunTime.Minutes+":"+$RunTime.Seconds+"."+$RunTime.Milliseconds+"]")
}
Set-Location $System32
$ProgressPreference=$OriginalPreference