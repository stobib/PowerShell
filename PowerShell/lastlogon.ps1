Clear-History;Clear-Host
Set-Variable -Name AdminShare -Value \\utshare.local\cifs\SysAdmins
Set-Variable -Name FilePath -Value ($AdminShare+"\ADUsers")
Set-Variable -Name FileName -Value ($FilePath+"\enabled_accounts.csv")
If(!(Test-Path -Path $FilePath)){New-Item -Path $AdminShare -Name "ADUsers" -ItemType Directory}
Get-ADUser -Filter {enabled -eq $true} -Properties LastLogonTimeStamp |
Select-Object Name,@{Name="Stamp"; Expression={[DateTime]::FromFileTime($_.lastLogonTimestamp).ToString('yyyy-MM-dd_hh:mm:ss')}} |
Sort-Object Name | Out-File -FilePath $FileName -NoClobber