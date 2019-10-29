<#
# install some roles and features for Configuration Manager
# requirements are listed here https://technet.microsoft.com/library/gg682077.aspx#BKMK_SiteSystemRolePrereqs
#
# https://technet.microsoft.com/en-us/library/jj205467.aspx
# This example installs all roles, role services and features that are specified in a configuration file named DeploymentConfigTemplate.xml. 
# The configuration file was created by clicking Export configuration settings on the Confirm installation selections page of the Server Manager.
# 
# Please make sure that your source files (Server 2016 Media) are in the path listed below, or adjust as necessary.
#
# niall brady 2016/12/5
#
#>

    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] “Administrator”))

    {
        Write-Warning “You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!”
        Break
    }

$Scriptspath = "E:\Sources\scripts"
$SourceFiles = "E:\Sources\SXS"
Write-Host "Installing roles and features, please wait... "  -nonewline
Install-WindowsFeature -ConfigurationFilePath $Scriptspath\DeploymentConfigTemplate.xml -Source $SourceFiles
