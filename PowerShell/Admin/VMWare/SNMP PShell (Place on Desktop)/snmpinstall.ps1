####################################
# Last update: 20150310pra
# Description: Powershell script to install and configure SNMP Services on Windows 2008R2, 2012 and 2012R2 Server (SNMP Service, SNMP WMI Provider)
# start As Administrator with C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -Command "&{ \\Servername\InstallSNMP\installsnmp.ps1}"
# Script Location: \\Servername\InstallSNMP\installsnmp.ps1
####################################


#Variables :)
$CommString = @("public4D1QV3s68qsr") # ADD YOUR COMM STRING(s) in format @("Community1","Community2")

#Import ServerManger Module
Import-Module ServerManager

#Check if SNMP-Service is already installed
$check = Get-WindowsFeature -Name SNMP-Service

If ($check.Installed -ne "True") 
    {
    #Install/Enable SNMP-Service
    Write-Host "SNMP Service Installing..."
    # Get OS Version to use the right install command
    [int]$verMajor = [environment]::OSVersion.Version | ft -property Major -HideTableHeaders -auto | Out-String
    [int]$verMinor = [environment]::OSVersion.Version | ft -property Minor -HideTableHeaders -auto | Out-String
    if ($verMajor -eq 6)
        {
        $winVer = switch ($verMinor)
            {
            0 {"Win2008"}
            1 {"Win2008R2"}
            2 {"Win2012"}
            3 {"Win2012R2"}
            }
        }
    #Install SNMP on 2008 (R2)
    if ($winVer -eq "Win2008" -or $winVer -eq "Win2008R2")
        {
        Get-WindowsFeature -name SNMP* | Add-WindowsFeature | Out-Null
        }
    #Install SNMP on 20012 (R2)
    if ($winVer -eq "Win2012" -or $winVer -eq "Win2012R2")
        {
        Get-WindowsFeature -name SNMP* | Add-WindowsFeature -IncludeManagementTools | Out-Null
        }
    }

$check = Get-WindowsFeature -Name SNMP-Service

##Verify Windows Services Are Enabled
If ($check.Installed -eq "True")
    {
    Write-Host "Configuring SNMP Services..."

    #Set SNMP Permitted Manager(s) ** WARNING : This will over write current settings **
#    reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" /v 1 /t REG_SZ /d localhost /f | Out-Null

    #Set SNMP Traps and SNMP Community String(s) - *Read Only*
    Foreach ($String in $CommString)
        {
        reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\ValidCommunities" /v $String /t REG_DWORD /d 4 /f | Out-Null
        }
        reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" /v 1 /f 
    }
Else 
    {
    Write-Host "Error: SNMP Services Not Installed"
    }