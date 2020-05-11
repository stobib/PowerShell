[CmdletBinding()]
param(
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Username,
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][uint64]$MaxPwdAge,
    [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][int]$Duration=5000
)
$DefaultParameterValues=@{"Username"=($env:USERNAME);"MaxPwdAge"=365}
If(!($Username)){$Username=($DefaultParameterValues.Username)}
If(!($MaxPwdAge)){$MaxPwdAge=($DefaultParameterValues.MaxPwdAge)}
$ErrorActionPreference='SilentlyContinue'
$SecurityPolicy="our new Active Directory (AD) password policy"
#  $Username="sy1000364788"  # - Testing Script
Clear-History;Clear-Host
Import-Module ActiveDirectory
$Global:ClearEvents=@('IconClicked','BalloonClicked_event','BalloonClosed_event','Disposed')
[string]$Global:Organization="UT System Administration, Information Security Office"
If($Username-eq""){$Username=(([Security.Principal.WindowsIdentity]::GetCurrent()).name).split("\")[1]}
[uint64]$PasswordAge=(New-TimeSpan -Start (Get-ADUser -Identity $Username -Properties PasswordLastSet).passwordlastset -End (Get-Date).Date).Days
$Global:ADUserAccount=Get-ADUser -Identity $Username -Properties *
If($PasswordAge-ge$MaxPwdAge){
#Load the required assemblies
    Add-Type -AssemblyName System.Windows.Forms
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
            Write-Host 'Opening webpage from taskbar doubleclick'
            Invoke-Expression 'start "https://selfserve.utshare.utsystem.edu"'
            Write-Host 'Disposing of balloon for icon double-click event.'
            $Global:PasswordNotification.Dispose()
            Unregister-Event -SourceIdentifier IconClicked
            Remove-Job -Name IconClicked
            Remove-Variable -Name PasswordNotification -Scope Global
        })
#Balloon message clicked
        [void](Register-ObjectEvent -InputObject $PasswordNotification -EventName BalloonTipClicked -SourceIdentifier BalloonClicked_event -Action{
            Write-Host 'Opening webpage from balloon click'
            Invoke-Expression 'start "https://selfserve.utshare.utsystem.edu"'
            #Get rid of the icon after action is taken
            Write-Host 'Disposing of balloon for balloon click event.'
            $Global:PasswordNotification.Dispose()
            Unregister-Event -SourceIdentifier BalloonClicked_event -ErrorAction SilentlyContinue
            Remove-Job -Name BalloonClicked_event -ErrorAction SilentlyContinue
            Remove-Variable -Name PasswordNotification -Scope Global
        })
    }
#Define various parts of the notification
    $PasswordNotification.Icon=[System.Drawing.SystemIcons]::Information
    $PasswordNotification.BalloonTipTitle=$Organization
    $PasswordNotification.BalloonTipIcon=“Info”
#Make balloon tip visible when called
    $PasswordNotification.Visible=$True
#Call the balloon notification
    [boolean]$bFifthMinute=$false
    [uint16]$intHour=0
    Do{
        $intHour++
        $Hour=""
        $intMinute=0
        Switch($intHour){
            1{$Hour="first";Break}
            2{$Hour="second";Break}
            3{$Hour="third";Break}
            4{$Hour="fourth";Break}
            5{$Hour="fifth";Break}
            6{$Hour="sixth";Break}
            7{$Hour="seventh";Break}
            8{$Hour="eighth";Break}
        }
        $HourMessage=($Hour+" hour")
        Write-Host ("Launching the balloon for "+$HourMessage+".")
        Do{
            $intSecond=0
            [string]$StrMin=$intMinute
            $MinuteMessage=($StrMin+" minute(s) past the "+$HourMessage+".")
            Switch($intMinute){
                {($_-eq0)-or($_-eq5)-or($_-eq10)-or($_-eq15)-or($_-eq20)-or($_-eq25)-or($_-eq30)-or($_-eq35)-or($_-eq40)-or($_-eq45)-or($_-eq50)-or($_-eq55)}
                    {Write-Host ("Launching the balloon for "+$MinuteMessage+"")
                    $bFifthMinute=$true
                    Break}
            }
            $intMinute++
            Do{
                Try{
                    Switch($intSecond){
                        {($_-eq0)-and($bFifthMinute-eq$true)}{
                            [string]$HourOfDay=""
                            [int]$HourOfDay=(Get-Date).Hour
                            Switch($HourOfDay){
                                {($_-lt12)}{$Greeting="morning";Break}
                                {($_-lt18)}{$Greeting="afternoon";Break}
                                Default{$Greeting="evening";Break}
                            }
                            $TextMessage=(“Good "+$Greeting+" ”+$ADUserAccount.GivenName+",`nIAW: "+$SecurityPolicy+", your password needs to be changed.  Age: ["+$PasswordAge+"]")
                            $PasswordNotification.BalloonTipText=$TextMessage
                            $PasswordNotification.ShowBalloonTip($Duration)
                            $bFifthMinute=$false
                            Break}
                        Default{Break}
                    }
                    $intSecond++
                }Catch{
                    Exit
                }Finally{
                    Start-Sleep -Milliseconds 1
                }
            }Until($intSecond-eq60)
        }Until($intMinute-eq60)
    }Until($intHour-eq8)
}
Set-Location ($env:SystemRoot+"\System32")

# SIG # Begin signature block
# MIIFlAYJKoZIhvcNAQcCoIIFhTCCBYECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUbEBWjBu/k5CsvQJkfTPeQ0fr
# GdKgggMiMIIDHjCCAgagAwIBAgIQULR7cS3qdZtE8haNxd7nHzANBgkqhkiG9w0B
# AQUFADAnMSUwIwYDVQQDDBxTZWxmLVNpZ25lZCBmb3IgQ29kZSBTaWduaW5nMB4X
# DTIwMDUwOTE2MjgyM1oXDTIxMDUwOTE2NDgyM1owJzElMCMGA1UEAwwcU2VsZi1T
# aWduZWQgZm9yIENvZGUgU2lnbmluZzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBALeE4bh/pLCtJl5T2WiWNTT00H5IROcbPWI/cchnjK8mpjq4rLrY5gR8
# 6VPPpJc//y444p/f5C/H9NLH4e7nUzvh9QtaDXKUnn4DhuqgO1ALiqAY96pTTWhE
# T4y9kDZGPc0seFxEVXd+cMdEJ2Yek3RiqfRU5B/L+DHjvShRHsHVy8e5mjFBj49I
# yRluA+Ma2TpB4/4q/xii8bTLLLh7Gmkbg1vrEWjr8uUbHuJDOSmQbd1uA+QM2dDD
# Ky+9RLkDVUuiwCz1ASjjoYBrM/Qfpl/0zipFHPWGhp6936U3hIULsXQYe7ss2aYJ
# KaMs7yp4pHcGZ52LxHmz/BijA4KnWXECAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeA
# MBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBShh3p+bQXi7G4nd4M2tOP0
# ZQgLojANBgkqhkiG9w0BAQUFAAOCAQEALtFUfDgwTmL2LpZPyCbz6ijclrj9Ht/W
# SWVzvJSMtLQIBHIa9ZEbtg8336ULCt6xV2G2RZwa1ap9bOEjp22VltEDMrlkjlXZ
# kwE64+F6Pl+wNY/wncGZmEyeWFJlg0VVC6iwO5DT7A0K0kn6HhPOHuAozP9hoLeX
# FXeSIHgQymZMXBDpmEJSk1LdUw3HOM54aasdIHyhzikGe0ztXNq0e/DO+PmbfBsT
# R3S67LVBLWO5XZjJATJkEZyCdoTWQR/cxxKNf0X5QprPGK00GyOpBCiWe6I1FBfU
# dZ0cv/zM1sNQzq5TPKOA2w3VIAwLi7M75zR7+rGlVF2gzuYWROiQWDGCAdwwggHY
# AgEBMDswJzElMCMGA1UEAwwcU2VsZi1TaWduZWQgZm9yIENvZGUgU2lnbmluZwIQ
# ULR7cS3qdZtE8haNxd7nHzAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUYr7d/vCOEtr0wzYtPkpw
# KJSG2UYwDQYJKoZIhvcNAQEBBQAEggEAYtRNaERFtKlqpp0H+jfpsKtKjCKT6qvZ
# I0eQUg8kcTRyHsy5hxm+BKR51kuUtXhoxcaOev8/NjkhgcpmixZ76bAd0gBmhV4K
# m1ur4FFHR2RxrDo9jI4OWsRE0QPFHb70CeniJzHoCuNva99Vjszq+t1ngnQSYOfM
# /yhG8P6+9WGPA1TV35FZhMXxy/CGGIbB5Qlg2NAN6wp0kkrOahX6iZtj2BvFP/MV
# LV5nfyrAk1C9+VINsgGNW+3F+96OxIJvwkUh5rNwiGEsxjYZrgsxdmNXgqQagELG
# MZpa3884JJemmb/XiQ2x2oazl/i0VczNq8mGcWf2VhjcpBRR1WfDfw==
# SIG # End signature block
