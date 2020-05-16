Clear-History;Clear-Host
# Script Body >>>--->> Unique code for Windows PowerShell scripting
$State=(Get-WindowsCapability -Name RSAT*ActiveDirectory* -Online).state
If($State-eq"NotPresent"){
    Add-WindowsCapability –online –Name “Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0”
}
# Script Body <<---<<< Unique code for Windows PowerShell scripting