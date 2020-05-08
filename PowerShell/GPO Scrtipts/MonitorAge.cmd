@Echo Off
Set FileName=MonitorAge.ps1
Set FileNames=*Age.*
Set LocalPath=%SystemDrive%\Scripts
Set UNCPath=\\utshare.local\NETLOGON
Set UsersDesktop=%USERPROFILE%\Desktop
Set AllUsersDesktop=%SystemDrive%\Users\Public\Desktop
Set PShell=%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe
If Not Exist %LocalPath% MD %LocalPath%
CD %LocalPath%
%PShell% Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -ErrorAction SilentlyContinue
%PShell% Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy ByPass -ErrorAction SilentlyContinue
If %Computername% EQU WIN10ADMZ001 Goto Upload
If Exist "%UNCPath%\Monitor Password Age.lnk" Robocopy "%UNCPath%" "%UsersDesktop%" "Monitor Password Age.lnk" /R:0 /W:0
If Exist "%AllUsersDesktop%\Monitor Password Age.lnk" %PShell% Remove-Item '%AllUsersDesktop%\Monitor Password Age.lnk' -Force
CLS
:Download
Robocopy "%UNCPath%" "%LocalPath%" "%FileNames%" /R:0 /W:0
If %Computername% EQU WIN10ADMZ001 Goto ByPass
Start "" "%UsersDesktop%\Monitor Password Age.lnk"
Goto End
:Upload
%PShell% Get-ExecutionPolicy -List
Set DevPath=\\utshare.local\cifs\SysAdmins\PowerShell_Scripts
Robocopy "%DevPath%" "%UNCPath%" "%FileNames%" /R:0 /W:0
Attrib +R +H "%UNCPath%\%FileName%"
Goto Download
:ByPass
%PShell% -noexit
:End
@Echo On