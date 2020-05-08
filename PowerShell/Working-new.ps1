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
[string]$Global:Organization="UT System Administration, Information Security Office"

If($Username-eq""){$Username=(([Security.Principal.WindowsIdentity]::GetCurrent()).name).split("\")[1]}
[uint64]$PasswordAge=(New-TimeSpan -Start (Get-ADUser -Identity $Username -Properties PasswordLastSet).passwordlastset -End (Get-Date).Date).Days
$Global:ADUserAccount=Get-ADUser -Identity $Username -Properties *
If($PasswordAge-ge$MaxPwdAge){
    $TextMessage=(“Hello ”+$ADUserAccount.GivenName+", your password's age is "+$PasswordAge+" days old.  It has met or exceeded the Maximum Password Age set by policy.")
    #Load the required assemblies
    [void] [System.Reflection.Assembly]::LoadWithPartialName(“System.Windows.Forms”)
    #Remove any registered events related to notifications
    Remove-Event BalloonClicked_event -ea SilentlyContinue
    Unregister-Event -SourceIdentifier BalloonClicked_event -ea silentlycontinue
    Remove-Event BalloonClosed_event -ea SilentlyContinue
    Unregister-Event -SourceIdentifier BalloonClosed_event -ea silentlycontinue
    Remove-Event Disposed -ea SilentlyContinue
    Unregister-Event -SourceIdentifier Disposed -ea silentlycontinue
    #Create the notification object
    $PasswordNotification=New-Object System.Windows.Forms.NotifyIcon 
    #Define various parts of the notification
    $PasswordNotification.Icon=[System.Drawing.SystemIcons]::Information
    $PasswordNotification.BalloonTipTitle=$Organization
    $PasswordNotification.BalloonTipIcon=“Info”
    $PasswordNotification.BalloonTipText=$TextMessage
    #Make balloon tip visible when called
    $PasswordNotification.Visible=$True
    ## Register a click event with action to take based on event
    #Balloon message clicked
    Register-ObjectEvent $PasswordNotification BalloonTipClicked BalloonClicked_event -Action{
        Invoke-Expression 'start "https://selfserve.utshare.utsystem.edu"'
        #Get rid of the icon after action is taken
        $PasswordNotification.Dispose()
        }|Out-Null
    #Balloon message closed
    Register-ObjectEvent $PasswordNotification BalloonTipClosed BalloonClosed_event -Action{
        $PasswordNotification.Dispose()
        }|Out-Null
    #Call the balloon notification
    $PasswordNotification.ShowBalloonTip($Duration)
}