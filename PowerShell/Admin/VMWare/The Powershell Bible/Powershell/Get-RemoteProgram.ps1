<#
.Synopsis
Generates a list of installed programs on a computer

.DESCRIPTION
This script generates a list by querying the registry and returning the installed programs of a local or remote computer.

.NOTES   
Name: Get-RemoteProgram
Author: Jaap Brasser
Version: 1.0
DateCreated: 2013-08-23
DateUpdated: 2013-08-23
Blog: http://www.jaapbrasser.com

.LINK
http://www.jaapbrasser.com

.PARAMETER ComputerName
The computer to which connectivity will be checked

.EXAMPLE
Get-RemoteProgram

Description:
Will generate a list of installed programs on local machine

.EXAMPLE
Get-RemoteProgram -ComputerName server01,server02

Description:
Will generate a list of installed programs on server01 and server02
#>
Function Get-RemoteProgram {
    param(
        [CmdletBinding()]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )
    foreach ($Computer in $ComputerName) {
        $RegBase = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$Computer)
        $RegUninstall = $RegBase.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')
        $RegUninstall.GetSubKeyNames() | 
        ForEach-Object {
            $DisplayName = ($RegBase.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$_")).GetValue('DisplayName')
            if ($DisplayName) {
                New-Object -TypeName PSCustomObject -Property @{
                    ComputerName = $Computer
                    ProgramName = $DisplayName
                }
            }
        }
    }
}