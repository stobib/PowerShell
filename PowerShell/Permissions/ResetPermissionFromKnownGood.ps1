Clear-History;Clear-Host
Set-Variable -Name CAS -Value "sccmcasdba01.inf.utshare.local"
Set-Variable -Name PSS -Value ($env:COMPUTERNAME+".inf."+$env:USERDNSDOMAIN).ToLower()
Set-Variable -Name SrcPath -Value ("\\"+$CAS+"\Admin$\System32\inetsrv")
Set-Variable -Name DesPath -Value ("\\"+$PSS+"\Admin$\System32\inetsrv")
If(Test-Path-eq$DesPath){
	Copy-Item -Path $DesPath -Destination ($DesPath+"-old") -Recurse
}
RoboCopy $SrcPath $DesPath /E /MIR /R:0 /W:0 /REG
$Folders=Get-ChildItem -Directory -Path $SrcPath -Recurse
ForEach($Folder In $Folders){
	$SrcFullPath=$Folder.FullName
    $DesFullPath=$SrcFullPath.replace($CAS,$PSS)
    Get-Acl -Path $SrcFullPath | Set-Acl -Path $DesFullPath
}
