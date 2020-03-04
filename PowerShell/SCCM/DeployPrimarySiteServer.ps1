Clear-History;Clear-Host
Set-Location -Path ($env:SystemRoot+"\System32")
Set-Variable -Name Domain -Value $env:USERDNSDOMAIN.ToLower()
Set-Variable -Name FolderList -Value @("ClientHealth","Distribution","DFSRoots\SCCM","DFSRoots\sccmsrc","Downloads","InetPub","MSCA"
,"Program Files","Program Files\Update Services\Logfiles\WSUSTemp","Program Files (x86)","RemoteInstall","Sources","SystemLogs","WSUS"
,"WSUS\UpdateServicesPackages","WSUS\WsusContent")
ForEach($Folder In $FolderList){
    If(!(Test-Path -Path ("E:\"+$Folder))){
        mkdir -Path ("E:\"+$Folder)
    }
    IF($Folder-eq"InetPub"){
        If(!(Test-Path -Path "C:\InetPub")){
            If(!(Test-Path -Path .\junction64.exe)){
                Copy-Item -Path ("\\sccmcasdba01.inf."+$Domain+"\Sources\apps\*.*") -Destination ($env:SystemRoot+"\System32") -Force
            }
            .\junction64.exe "C:\InetPub" "E:\InetPub" -accepteula
        }
    }
    Switch($Folder){
        {$_-like"*DFSRoots*"}{Break}
        {($_-like"*Program*")-and($_-notlike"*WSUSTemp*")}{Get-Acl -Path ("C:\"+$Folder)|Set-Acl -Path ("E:\"+$Folder);Break}
        Default{Get-Acl -Path "C:\Windows"|Set-Acl -Path ("E:\"+$Folder);Break}
    }
}
Robocopy ("\\sccmcasdba01.inf."+$Domain+"\Sources") "E:\Sources" /E /MIR /XD "WSUS"
If(!(Test-Path -Path "C:\Scripts")){
    .\junction64.exe "C:\Scripts" "E:\Sources\Scripts"
}
If(!(Test-Path -Path "C:\Program Files\Update Services")){
    .\junction64.exe "C:\Program Files\Update Services" "E:\Program Files\Update Services"
}