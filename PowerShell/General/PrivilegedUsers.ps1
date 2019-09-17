<#
Get-ADGroupMember "administrators" -Recursive|Where-Object {$_.Name -Like "*"}|%{$group=$_;get-aduser $_ -Properties Name|Select @{n="Group";e={$group}},Name,SurName,GivenName,ObjectClass}|Out-File 'E:\Results\administrators.log'
Get-ADGroupMember "Backup Operators" -Recursive|Where-Object {$_.Name -Like "*"}|%{$group=$_;get-aduser $_ -Properties Name|Select @{n="Group";e={$group}},Name,SurName,GivenName,ObjectClass}|Out-File 'E:\Results\BackupOperators.log'
Get-ADGroupMember "Enterprise Admins" -Recursive|Where-Object {$_.Name -Like "*"}|%{$group=$_;get-aduser $_ -Properties Name|Select @{n="Group";e={$group}},Name,SurName,GivenName,ObjectClass}|Out-File 'E:\Results\EnterpriseAdmins.log'
Get-ADGroupMember "Domain Admins" -Recursive|Where-Object {$_.Name -Like "*"}|%{$group=$_;get-aduser $_ -Properties Name|Select @{n="Group";e={$group}},Name,SurName,GivenName,ObjectClass}|Out-File 'E:\Results\DomainAdmins.log'
#Get-ADGroupMember "utshare" -Recursive|Where-Object {$_.Name -Like "*"}|%{$group=$_;get-aduser $_ -Properties Name|Select @{n="Group";e={$group}},Name,SurName,GivenName,ObjectClass}|Out-File 'E:\Results\utshare.log'
#>
$TestAcct="sy1000829946"
#Get-ADComputer -Filter {name -like $TestAcct} -Properties *
Get-ADUser -Filter {name -like $TestAcct} -Properties *