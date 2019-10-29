cls
$path = Split-Path -parent "F:\Report\ExportADUsers\*.*"
$LogDate = get-date -f yyyyMMddhhmm
$csvfile = $path + "\ALLADUsers_$logDate.csv"
Import-Module ActiveDirectory
$SearchBase = "OU=AllUsers,DC=utshare,DC=local"
$GetAdminact = Get-Credential
$ADServer = 'dca01'
$AllADUsers = Get-ADUser -server $ADServer `
-Credential $GetAdminact -searchbase $SearchBase `
-Filter * -Properties * | Where-Object {$_.info -NE 'Migrated'}
$AllADUsers |
Select-Object @{Label = "First Name";Expression = {$_.GivenName}},
@{Label = "Last Name";Expression = {$_.Surname}},
@{Label = "Display Name";Expression = {$_.DisplayName}},
@{Label = "Logon Name";Expression = {$_.sAMAccountName}},
@{Label = "Full address";Expression = {$_.StreetAddress}},
@{Label = "City";Expression = {$_.City}},
@{Label = "State";Expression = {$_.st}},
@{Label = "Post Code";Expression = {$_.PostalCode}},
@{Label = "Country/Region";Expression = {if (($_.Country -eq 'GB')  ) {'United Kingdom'} Else {''}}},
@{Label = "Job Title";Expression = {$_.Title}},
@{Label = "Company";Expression = {$_.Company}},
@{Label = "Description";Expression = {$_.Description}},
@{Label = "Department";Expression = {$_.Department}},
@{Label = "Office";Expression = {$_.OfficeName}},
@{Label = "Phone";Expression = {$_.telephoneNumber}},
@{Label = "Email";Expression = {$_.Mail}},
@{Label = "Manager";Expression = {%{(Get-AdUser $_.Manager -server $ADServer -Properties DisplayName).DisplayName}}},
@{Label = "Account Status";Expression = {if (($_.Enabled -eq 'TRUE')  ) {'Enabled'} Else {'Disabled'}}},
@{Label = "Last LogOn Date";Expression = {$_.lastlogondate}} | 
Export-Csv -Path $csvfile -NoTypeInformation
