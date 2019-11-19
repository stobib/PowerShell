@Echo Off
Set UptimePS1=E:\GitHUB\falcon\PowerShell\GetUptime.ps1
Set ENV=prd
Set S=1
:Main
Set Host=zahy%ENV%ntz0%S%.%ENV%.utshare.local
ping -n 4 -w 5 %Host%
shutdown /a /m \\%Host%
powershell %UptimePS1% %Host%
Set /A S=%S%+1
If %S% EQU 4 Set S=1
If %S% EQU 1 Goto Change
Goto Main
:Change
If %ENV% EQU tst Goto Prod 
Set ENV=tst
Goto Main
:Prod
Set ENV=prd
goto Main
