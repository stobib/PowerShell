[CmdletBinding()]
param(
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Username,
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][uint64]$MaxPwdAge,
    [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][int]$Duration=5000
)
$DefaultParameterValues=@{"Username"="sy1000364788";"MaxPwdAge"=365}
If(!($Username)){$Username=($DefaultParameterValues.Username)}
If(!($MaxPwdAge)){$MaxPwdAge=($DefaultParameterValues.MaxPwdAge)}
Clear-History;Clear-Host
Import-Module ActiveDirectory
[string]$Global:Organization="UT System Administration, Information Security Office"
[string]$Global:PowerShellPath=($env:SystemRoot+"\System32\WindowsPowerShell\v1.0\powershell.exe")
Do{
    If($Username-eq""){$Username=(([Security.Principal.WindowsIdentity]::GetCurrent()).name).split("\")[1]}
    [uint64]$PasswordAge=(New-TimeSpan -Start (Get-ADUser -Identity $Username -Properties PasswordLastSet).passwordlastset -End (Get-Date).Date).Days
    $Global:ADUserAccount=Get-ADUser -Identity $Username -Properties *
    If($PasswordAge-ge$MaxPwdAge){
        $TextMessage=(“Hello ”+$ADUserAccount.GivenName+", your password's age is "+$PasswordAge+" days old.  It has met or exceeded the Maximum Password Age set by policy.")
        Add-Type -AssemblyName System.Windows.Forms
        Remove-Event BalloonClicked_event -ea SilentlyContinue
        Unregister-Event -SourceIdentifier BalloonClicked_event -ea silentlycontinue
        Remove-Event BalloonClosed_event -ea SilentlyContinue
        Unregister-Event -SourceIdentifier BalloonClosed_event -ea silentlycontinue
        Remove-Event Disposed -ea SilentlyContinue
        Unregister-Event -SourceIdentifier Disposed -ea silentlycontinue
        If(-NOT $Global:Balloon){
            $Global:Balloon=New-Object System.Windows.Forms.NotifyIcon
            [void](Register-ObjectEvent -InputObject $Balloon -EventName MouseDoubleClick -SourceIdentifier IconClicked -Action{
                Write-Verbose 'Disposing of balloon'
                $Global:Balloon.Dispose()
                Unregister-Event -SourceIdentifier IconClicked
                Remove-Job -Name IconClicked
                Remove-Variable -Name Balloon -Scope Global
            })
        }
        [System.Windows.Forms.ToolTipIcon]$MessageType="Info"
        $IconPath=Get-Process -Id $PID|Select-Object -ExpandProperty Path
        $Balloon.Icon=[System.Drawing.Icon]::ExtractAssociatedIcon($IconPath)
        $Balloon.BalloonTipIcon=“Info”
        $Balloon.BalloonTipTitle=$Organization
        $Balloon.BalloonTipText=$TextMessage
        $Balloon.Visible=$true
        Register-ObjectEvent $Balloon BalloonTipClicked BalloonClicked_event -Action{
            Invoke-Expression “cmd.exe /C start https://selfserve.utshare.utsystem.edu/”
#            Start-Process -FilePath $env:ComSpec -ArgumentList "/c",$PowerShellPath,"-noexit",($env:SystemDrive+"\Scripts\MaxPassAge.ps1")
            $Balloon.Dispose()
        }|Out-Null
        Register-ObjectEvent $Balloon BalloonTipClosed BalloonClosed_event -Action{
            $Balloon.Dispose()
        }|Out-Null
        $Balloon.ShowBalloonTip($Duration)
        Start-Sleep -Seconds ([math]::Round(.15*60))
    }Else{
        Start-Sleep -Seconds ([math]::Round(15*60))
    }
}Until($PasswordAge-lt$MaxPwdAge)