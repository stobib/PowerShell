[string]$Domain=(($env:USERDNSDOMAIN).Split(".")[0]).ToUpper()
$Action=New-ScheduledTaskAction -Execute ($env:SystemDrive+"\Scripts\MonitorAge.ps1")
$Person=New-ScheduledTaskPrincipal ($Domain+"\zasvccm_cp")
$Trigger=New-ScheduledTaskTrigger -AtLogOn
$Settings=New-ScheduledTaskSettingsSet
$Create=New-ScheduledTask -Action $Action -Principal $Person -Trigger $Trigger -Settings $Settings
Register-ScheduledTask MonitorPasswordAge -InputObject $Create