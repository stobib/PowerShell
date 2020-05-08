[CmdletBinding()]
param(
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Username,
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][uint64]$MaxPwdAge,
    [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][int]$Duration=1000
)
$DefaultParameterValues=@{"Username"="sy1000364788";"MaxPwdAge"=365}
If(!($Username)){$Username=($DefaultParameterValues.Username)}
If(!($MaxPwdAge)){$MaxPwdAge=($DefaultParameterValues.MaxPwdAge)}
Clear-History;Clear-Host
Import-Module ActiveDirectory
$Global:ClearEvents=@('IconClicked','BalloonClicked_event','BalloonClosed_event','Disposed')
[string]$Global:Organization="UT System Administration, Information Security Office"
If($Username-eq""){$Username=(([Security.Principal.WindowsIdentity]::GetCurrent()).name).split("\")[1]}
[uint64]$PasswordAge=(New-TimeSpan -Start (Get-ADUser -Identity $Username -Properties PasswordLastSet).passwordlastset -End (Get-Date).Date).Days
$Global:ADUserAccount=Get-ADUser -Identity $Username -Properties *
If($PasswordAge-ge$MaxPwdAge){
    $TextMessage=(“Hello ”+$ADUserAccount.GivenName+", your password's age is "+$PasswordAge+" days old.  It has met or exceeded the Maximum Password Age set by policy.")
#Load the required assemblies
    Add-Type -AssemblyName System.Windows.Forms
#    [void][System.Reflection.Assembly]::LoadWithPartialName(“System.Windows.Forms”)
#Remove any registered events related to notifications
    ForEach($EventName In $ClearEvents){
        Remove-Event $EventName -ea SilentlyContinue
        Unregister-Event -SourceIdentifier $EventName -ea silentlycontinue
    }
    If(-NOT $Global:PasswordNotification){
#Create the notification object
        $Global:PasswordNotification=New-Object System.Windows.Forms.NotifyIcon
## Register a click event with action to take based on event
    #TaskbarIcon MouseDoubleClick message
        [void](Register-ObjectEvent -InputObject $PasswordNotification -EventName MouseDoubleClick -SourceIdentifier IconClicked -Action{
            Write-Verbose 'Opening webpage from taskbar doubleclick'
            Invoke-Expression 'start "https://selfserve.utshare.utsystem.edu"'
            Write-Verbose 'Disposing of balloon'
            $Global:PasswordNotification.Dispose()
            Unregister-Event -SourceIdentifier IconClicked
            Remove-Job -Name IconClicked
            Remove-Variable -Name PasswordNotification -Scope Global
        })
#Balloon message clicked
        [void](Register-ObjectEvent -InputObject $PasswordNotification -EventName BalloonTipClicked -SourceIdentifier BalloonClicked_event -Action{
            Write-Verbose 'Opening webpage from balloon click'
            Invoke-Expression 'start "https://selfserve.utshare.utsystem.edu"'
            #Get rid of the icon after action is taken
            $PasswordNotification.Dispose()
            Unregister-Event -SourceIdentifier BalloonClicked_event -ErrorAction SilentlyContinue
            Remove-Job -Name BalloonClicked_event -ErrorAction SilentlyContinue
            Remove-Variable -Name PasswordNotification -Scope Global
        })
#Balloon message closed
        [void](Register-ObjectEvent -InputObject $PasswordNotification -EventName BalloonTipClosed -SourceIdentifier BalloonClosed_event -Action{
            Write-Verbose 'Disposing of balloon'
            $PasswordNotification.Dispose()
            Unregister-Event -SourceIdentifier BalloonClosed_event -ErrorAction SilentlyContinue
            Remove-Job -Name BalloonClosed_event -ErrorAction SilentlyContinue
            Remove-Variable -Name PasswordNotification -Scope Global
        })
    }
#Define various parts of the notification
    $PasswordNotification.Icon=[System.Drawing.SystemIcons]::Information
    $PasswordNotification.BalloonTipTitle=$Organization
    $PasswordNotification.BalloonTipIcon=“Info”
    $PasswordNotification.BalloonTipText=$TextMessage
#Make balloon tip visible when called
    $PasswordNotification.Visible=$True
#Call the balloon notification
    Write-Verbose 'Launching of balloon'
    $PasswordNotification.ShowBalloonTip($Duration)
}