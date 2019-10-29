Clear-History;Clear-Host
#Load Configuration Manager PowerShell Module
Import-module($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5)+'\ConfigurationManager.psd1')

#Get SiteServer and SiteCode
$SiteServer=$($(Get-PSDrive -PSProvider CMSite).Root).Split(".")[0]
$SiteCode=$(Get-PSDrive -PSProvider CMSite).Name
Set-Variable -Name SiteName -Value $null
Switch($SiteCode){
    "A01"{$SiteName="ARDC";Break}
    "B01"{$SiteName="UDCC";Break}
    Default{$SiteName=$null;Break}
}

#Set location within the SCCM environment
Set-location $SiteCode":"

#Set Polling Schedule for Forest Discovery
$ForestSchedule=New-CMSchedule -RecurCount 7 -RecurInterval Days
Set-CMDiscoveryMethod -ActiveDirectoryForestDiscovery -Enabled $true -SiteCode $SiteCode -EnableActiveDirectorySiteBoundaryCreation $true -EnableSubnetBoundaryCreation $true -PollingSchedule $ForestSchedule

#Set Start Time
$DateTime20=(Get-Date -Year 2019 -Month 1 -Day 1 -Hour 20 -Minute 0 -Second 0).DateTime

#Set Polling Schedule for Active Directory Group Discovery
$GroupSchedule=New-CMSchedule -DayOfWeek Wednesday -Start $DateTime20
$CustomGroupScope=New-CMADGroupDiscoveryScope -Name "Custom Groups" -LdapLocation  "LDAP://OU=AllUsers,DC=utshare,DC=local" -RecursiveSearch $true
Set-CMDiscoveryMethod -ActiveDirectoryGroupDiscovery -Enabled $true -SiteCode $SiteCode -AddGroupDiscoveryScope $CustomGroupScope -PollingSchedule $GroupSchedule -EnableDeltaDiscovery $true

#Set Polling Schedule for Active Directory System Discovery
$SystemSchedule=New-CMSchedule -DayOfWeek Sunday -Start $DateTime20
Set-CMDiscoveryMethod -ActiveDirectorySystemDiscovery -Enabled $true -SiteCode $SiteCode -PollingSchedule $SystemSchedule -EnableDeltaDiscovery $true -DeltaDiscoveryMins 30 -ActiveDirectoryContainer @("LDAP://OU=AllServers,DC=utshare,DC=local","LDAP://OU=Domain Controllers,DC=utshare,DC=local","LDAP://OU=AllWrkstns,DC=utshare,DC=local","LDAP://DC=api,DC=utshare,DC=local","LDAP://DC=prd,DC=utshare,DC=local","LDAP://DC=uat,DC=utshare,DC=local") -RemoveActiveDirectoryContainer @("LDAP://OU=vdi-ardc,OU=AllWrkstns,DC=utshare,DC=local","LDAP://OU=vdi-udcc,OU=AllWrkstns,DC=utshare,DC=local")

#Set Polling Schedule for Active Directory User Discovery
$UserSchedule=New-CMSchedule -DayOfWeek Friday -Start $DateTime20
Set-CMDiscoveryMethod -ActiveDirectoryUserDiscovery -Enabled $true -SiteCode $SiteCode -PollingSchedule $UserSchedule -EnableDeltaDiscovery $true -DeltaDiscoveryMins 30 -AddActiveDirectoryContainer @("LDAP://OU=AllUsers,DC=utshare,DC=local","LDAP://DC=api,DC=utshare,DC=local","LDAP://DC=prd,DC=utshare,DC=local","LDAP://DC=uat,DC=utshare,DC=local")

#Set location back to operating system
Set-Location "$env:SystemRoot\System32"
