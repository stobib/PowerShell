<# join computer to domain and then reboot
#  2016/12/2 niall brady
#>
$domain = "windowsnoob"
$password = "P@ssw0rd" | ConvertTo-SecureString -asPlainText -Force
$joindomainuser = "Administrator"
$username = "$domain\$joindomainuser" 
$credential = New-Object System.Management.Automation.PSCredential($username,$password)
Add-Computer -DomainName $domain -Credential $credential
Restart-Computer