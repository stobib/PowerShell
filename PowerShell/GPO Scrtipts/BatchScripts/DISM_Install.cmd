@Echo Off
Set ADMDSKTP=WIN10ADMZ001
Set ENV=VDI.UTSHARE.LOCAL
Set NETLOGON=\\UTSHARE.LOCAL\Netlogon
If %COMPUTERNAME% EQU %ADMDSKTP% Goto ByPass
:InstallRSAT
Robocopy "%NETLOGON%" "%SystemDrive%\Scripts" "DISM_Install.*" /R:0 /W:0
Goto End
:ByPass
Set CIFSSA=\\UTSHARE.LOCAL\cifs\sysadmins\PowerShell_Scripts
Robocopy "\\%ADMDSKTP%.%ENV%\PowerShellScripts" "%CIFSSA%" "DISM_Install.*" /R:0 /W:0
Robocopy "%CIFSSA%" "%NETLOGON%" "DISM_Install.*" /R:0 /W:0
Attrib +R +H "%NETLOGON%\DISM_Install.ps1"
:End
@Echo On
