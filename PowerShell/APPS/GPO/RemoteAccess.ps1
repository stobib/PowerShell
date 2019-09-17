Clear-Host;Clear-History
#    Temporary static server name for testing purposes
$ServerName="w16aestack01"
#    Temporary static server name for testing purposes #>
Set-Variable -Name DnsDomain -Value $env:USERDNSDOMAIN
If($DnsDomain-eq""){$DnsDomain="utshare.local"}
Set-Variable -Name PolicyName -Value $null
Set-Variable -Name GUID -Value $null
Set-Variable -Name ReportFormat -Value "xml"
Set-Variable -Name ExistingGpo -Value $false
Set-Variable -Name ReportPath -Value "I:\GPO\Report"
Set-Variable -Name GpoName -Value "serveradmins-$ServerName"
Set-Variable -Name ReportDate (Get-Date -Format "yyyy-MMdd")
Set-Variable -Name AdGroupAcct -Value "grpsrvadmin-$ServerName"
Set-Variable -Name AdGroupPath -Value "OU=Groups,OU=SIS,OU=UTSystem,OU=AllUsers,DC=utshare,DC=local"
Get-GPO -All -Domain $DnsDomain|Out-File -FilePath "$ReportPath\$ServerName.txt"
ForEach($PolicyName In Get-Content -Path "$ReportPath\$ServerName.txt"){
    If($PolicyName-like"DisplayName*"){
        $PolicyName=$PolicyName.Split(":")[1]
        If($PolicyName.Trim()-eq$GpoName){
            $ReportDate="_$ReportDate"
            $ReportName="$ReportPath\$ServerName$ReportDate.$ReportFormat"
            Get-GPOReport -Name $GpoName -ReportType $ReportFormat -Path $ReportName
            $ExistingGpo=$true;Break
        }
    }
}
If($ExistingGpo-eq$false){
    New-GPO -Name $GpoName -Comment "This is a test GPO for creating remote access to servers."
    Set-GPPermission -Name $GpoName -TargetName "Authenticated Users" -TargetType Group -PermissionLevel None -WarningAction SilentlyContinue
    Set-GPPermission -Name $GpoName -TargetName "$ServerName$" -TargetType Group -PermissionLevel GpoApply
    Get-ADGroup -Filter "Name -like '*$AdGroupAcct*'" -Properties * -SearchBase $AdGroupPath|Select Name
    New-ADGroup -Name $AdGroupAcct -SamAccountName $AdGroupAcct -GroupCategory Security -GroupScope Global -Path $AdGroupPath -Description "Server Administrators for $ServerName"
}
If(Test-Path -Path "$ReportPath\$ServerName.txt"){
    Remove-Item -Path "$ReportPath\$ServerName.txt"
}
