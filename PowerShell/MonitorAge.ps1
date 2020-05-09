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
# SIG # Begin signature block
# MIIFlAYJKoZIhvcNAQcCoIIFhTCCBYECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUWLKzcxB0Ogimyw6VBa/GDKW1
# yh6gggMiMIIDHjCCAgagAwIBAgIQFqx6NdMXQoxKtTdo3UZAtjANBgkqhkiG9w0B
# AQUFADAnMSUwIwYDVQQDDBxTZWxmLVNpZ25lZCBmb3IgQ29kZSBTaWduaW5nMB4X
# DTIwMDUwODE1NTkwMloXDTIxMDUwODE2MTkwMlowJzElMCMGA1UEAwwcU2VsZi1T
# aWduZWQgZm9yIENvZGUgU2lnbmluZzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBAMIkkGdy9lmv5WpYD7TUQVQ9VnQvSVFjRyGF1q5F6zg6IWWtXBaA7XDE
# 3UTptTsXCzLUmXpjN9iJ9xro527T1BWPewWl16Yp+r7bfl+uhO5UI4c5rYT/n0+t
# bGcev6DnG9B4oEcRRIgZkd2+zM9Sq18OP1nE9tkrLY6yPBM2u8Zoxe+oyDV39+Lo
# shD0oKSD/67tFXjCKEHfH12I7V1fIxgib8tskGqIb/ck7Q2vlDfVpA09vaQ1fjEW
# piMHrndHi563tKJuCEYci50BtELhY/2rAxdxlxqQUQuSRMb/h+iXk/ejpwZao5m7
# U/TSWjE6ipDQd/4RqfYQg8GYXTfCSo0CAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeA
# MBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQjlDzMb8Imjxs6ALRLr0B9
# +afCAjANBgkqhkiG9w0BAQUFAAOCAQEAZB2FDwujDqqIf0LhPsoWQlspfL/HiV8O
# 0EriT1spX/EubNGt7ddc5IsT5BiGrdd8mdL1+UXcwflhMK8EucaHknfrmng94ZhE
# QUJpheEtsu6JvgafZokZ4vUav1wUbsWVO766k8U78hV0meh5xGWFWeCuAWnLVqs9
# qUs1HbyJMpvHr10ArGKeiJ07t79c2kbkIBN7f20J1Sq2YjKr2c+pxLkuRhf5GBL8
# ukkPwWKqKb/ZsODu9DHatNznVzSYZnqjUmiS5TFZexCt/VtW8Xhd/13SMsfc/flm
# issYI+BdsukaRlnR4vPdwdPVGa1e7YCF77ZFZ9MdCygoih2AYezbUTGCAdwwggHY
# AgEBMDswJzElMCMGA1UEAwwcU2VsZi1TaWduZWQgZm9yIENvZGUgU2lnbmluZwIQ
# Fqx6NdMXQoxKtTdo3UZAtjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU5xkrFsZev3kkAyigYQBL
# E1/VN1UwDQYJKoZIhvcNAQEBBQAEggEAYR53VeVk52u4MBcTaJcI2Mwn27S1Bw8F
# XLVHKSGNAjeRc5RmcZRHj7Ihdyj8a+NwyDZfFfDm+YKX9VwwvytUDrFxP10HyEWI
# o9ash0ci4aFc18A8xJRIzIvMBEMxerzNb/3E03b15FeiJMzhHz8XZHN3gY1ex9S5
# ZO565T+NjV7nx68rFmX6b6YC5QY0YSSIXkBIickM/+1hz+HShewQxscHb60mkGdm
# mpcYUc+dsUOqRuhDpsCKJe/oySiAfWOcQMrdHBgXAqKCez8y4kdLj/kb5BtHwS3z
# gn1h59Yd4PFbPGraxgWUvGg45HhlTZMtM3nSzmcKMgScRGx5GohhGw==
# SIG # End signature block
