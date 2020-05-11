@Echo Off
Set ADMDSKTP=WIN10ADMZ001
Set ENV=VDI.%USERDNSDOMAIN%
Set NETLOGON=\\%USERDNSDOMAIN%\Netlogon
If %COMPUTERNAME% EQU %ADMDSKTP% Goto ByPass
:InstallRSAT
Robocopy "%NETLOGON%" "%SystemDrive%\Scripts" "DISM_Install.*" /R:0 /W:0
Start "" "%SystemDrive%\Scripts\DISM_Install.lnk"
Goto End
:ByPass
Set CIFSSA=\\%USERDNSDOMAIN%\cifs\sysadmins\PowerShell_Scripts
Robocopy "\\%ADMDSKTP%.%ENV%\PowerShellScripts" "%CIFSSA%" "DISM_Install.*" /R:0 /W:0
Robocopy "%CIFSSA%" "%NETLOGON%" "DISM_Install.*" /R:0 /W:0
Attrib +R +H "%NETLOGON%\DISM_Install.ps1"
:End
@Echo On
