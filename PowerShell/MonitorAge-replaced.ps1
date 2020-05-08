[CmdletBinding()]
param(
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Username,
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][uint64]$MaxPwdAge
)
$DefaultParameterValues=@{"MaxPwdAge"=365}
If(!($MaxPwdAge)){$MaxPwdAge=($DefaultParameterValues.MaxPwdAge)}
Import-Module ActiveDirectory
$Global:Organization="UT System Administration, Information Security Office"
Do{
    If($Username-eq""){$Username=(([Security.Principal.WindowsIdentity]::GetCurrent()).name).split("\")[1]}
    $PasswordAge=(New-TimeSpan -Start (Get-ADUser -Identity $Username -Properties PasswordLastSet).passwordlastset -End (Get-Date).Date).Days
    $Global:ADUserAccount=Get-ADUser -Identity $Username -Properties *
    If($PasswordAge-ge$MaxPwdAge){
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Reflection.Assembly]::LoadWithPartialName(“System.Windows.Forms”)
        Remove-Event BalloonClicked_event -ea SilentlyContinue
        Unregister-Event -SourceIdentifier BalloonClicked_event -ea silentlycontinue
        Remove-Event BalloonClosed_event -ea SilentlyContinue
        Unregister-Event -SourceIdentifier BalloonClosed_event -ea silentlycontinue
        Remove-Event Disposed -ea SilentlyContinue
        Unregister-Event -SourceIdentifier Disposed -ea silentlycontinue
        $Global:Reminder=New-Object System.Windows.Forms.NotifyIcon 
        $Reminder.Icon=[System.Drawing.SystemIcons]::Information
        $Reminder.BalloonTipTitle=(“Hello ”+$ADUserAccount.GivenName+"!")
        $Reminder.BalloonTipIcon=“Warning”
        $Reminder.BalloonTipText=("Your password's age is "+$PasswordAge+" days old and has met or exceeded the Maximum Password Age set by the "+$Organization+".")
        $Reminder.Visible=$True
        Register-ObjectEvent $Reminder BalloonTipClicked BalloonClicked_event -Action{
            Start-Process -FilePath ($env:SystemRoot+"\System32\WindowsPowerShell\v1.0\powershell.exe") -ArgumentList ($env:SystemDrive+"\Scripts\MaxPassAge.ps1") -WindowStyle Normal
            $Reminder.Dispose()
        }|Out-Null
        Register-ObjectEvent $Reminder BalloonTipClosed BalloonClosed_event -Action{
            $Reminder.Dispose()
        }|Out-Null
        $Reminder.ShowBalloonTip(5000)
    }Else{
        Start-Sleep -Seconds ([math]::Round(60*.15))
    }
}Until($PasswordAge-lt$MaxPwdAge)