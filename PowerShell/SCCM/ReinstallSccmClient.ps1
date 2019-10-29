CLS
$SysRoot=$env:SystemRoot
$SysDir=$SysRoot+"\System32"
Set-Location $SysDir
If(Test-Path $SysDir"\CMTrace.exe"="False"){Copy-Item "\\w16sccmmgra01.inf.utshare.local\SMSSETUP\TOOLS\CMTrace.exe" -Destination $SysDir}
If(Test-Path -Path $SysRoot"\ccm"="True"){Start-Process -FilePath "\\w16sccmmgra01.inf.utshare.local\SMSSETUP\Client\ccmsetup.exe" "/uninstall" -Wait}
Start-Process -FilePath "\\w16sccmmgra01.inf.utshare.local\SMSSETUP\Client\ccmsetup.exe"
Start-Process -FilePath "$SysDir\CMTrace.exe" "C:\Windows\ccmsetup\Logs\ccmsetup.log"