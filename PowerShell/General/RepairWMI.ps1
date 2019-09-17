Set-ExecutionPolicy -ExecutionPolicy ByPass
Set-ExecutionPolicy Unrestricted
Set-Variable -Name DomainName -Value $("$env:USERDNSDOMAIN").ToLower()
Net Time /DOMAIN:$DomainName /SET /Y
Clear-History;Clear-Host
Set-Variable -Name CurrentLocation -Value $env:SystemRoot\System32
Function PauseForCompletion($ProcessName){
    $ProcessID=(Get-Process -Name $ProcessName).Id
    Wait-Process -Id $ProcessID
}
Set-Variable -Name Remove_Account -Value "sy1000829946"
Set-Variable -Name Profile_Path -Value "$env:SystemDrive\Users"
$Remove_Account=$Profile_Path+"\"+$Remove_Account
If(Test-Path $Remove_Account){sysdm.cpl}
Function TimeStamp{$(Get-Date -UFormat "%D %T")}
$logfile="$env:temp\LocalPolicyCheck.log"
Function Test-IsRegistryPOLGood{
    $PathToMachineRegistryPOLFile="$env:SytemRoot\System32\GroupPolicy\Machine\Registry.pol"
    $PathToUserRegistryPOLFile="$env:SytemRoot\System32\GroupPolicy\User\Registry.pol"
    If(!(Test-Path -Path $PathToMachineRegistryPOLFile -PathType Leaf)){}
    Else{
        If(((Get-Content -Encoding Byte -Path $PathToMachineRegistryPOLFile -TotalCount 4)-join'')-ne'8082101103'){
            If(Test-Path -Path $PathToMachineRegistryPOLFile){
                Remove-Item $PathToMachineRegistryPOLFile -Force -Verbose
                Return $False
            }
        }
    }
    If(!(Test-Path -Path $PathToUserRegistryPOLFile -PathType Leaf)){}
    Else{
        If(((Get-Content -Encoding Byte -Path $PathToUserRegistryPOLFile -TotalCount 4)-join'')-ne'8082101103'){
            If(Test-Path -Path $PathToUserRegistryPOLFile){
                Remove-Item $PathToUserRegistryPOLFile -Force -Verbose
                Return $False
            }
        }
    }
    Return $true
}
$Compliance="Compliant"
If((Test-IsRegistryPOLGood)-eq$true){
    $Compliance="Compliant"
}Else{
    $Compliance="Non-Compliant"
}
$(TimeStamp)+" Local Policy Check Returned: "+$Compliance | Out-File -FilePath $Logfile -Append -Encoding ascii
$Compliance
If($Compliance-eq"Non-Compliant"){
    $Logfile="$PSScriptRoot\PolicyRemediator.log"
    $(TimeStamp)+" Checking local policy integrity" | Out-File -FilePath $Logfile -Append -Encoding ascii
    If(!(Test-Path -Path $PathToMachineRegistryPOLFile -PathType Leaf)){}
    Else{
        If(((Get-Content -Encoding Byte -Path $PathToMachineRegistryPOLFile -TotalCount 4)-join'')-ne'8082101103'){
            $(TimeStamp)+" Removing corrupt Machine Policy file" | Out-File -FilePath $Logfile -Append -Encoding ascii
            Try{
                ri $PathToMachineRegistryPOLFile -Confirm:$false -ErrorAction SilentlyContinue
            }
            Catch{
                $(TimeStamp)+" Failed to remove policy file - Exiting"+(Write-Error -Message $_) | Out-File -FilePath $Logfile -Append -Encoding ascii
                Exit 1
            }
        }
    }
    If(!(Test-Path -Path $PathToUserRegistryPOLFile -PathType Leaf)){}
    Else{
        If(((Get-Content -Encoding Byte -Path $PathToUserRegistryPOLFile -TotalCount 4)-join'')-ne'8082101103'){
            $(TimeStamp)+" Removing corrupt User Policy file" | Out-File -FilePath $Logfile -Append -Encoding ascii
            Try {
                ri $PathToUserRegistryPOLFile -Confirm:$false -ErrorAction SilentlyContinue
            }
            Catch {
                $(TimeStamp)+" Failed to remove user policy file - Exiting"+(Write-Error -Message $_) | Out-File -FilePath $Logfile -Append -Encoding ascii
                Exit 1
            }
        }
    }
}
For($Count=0;$Count-le1;$Count++){
    Switch($Count){
        0{$CertType="Root";Break}
        1{$CertType="CA";Break}
    }
    Set-Location Cert:\LocalMachine\$CertType;$CurrentPath=dir
    ForEach($Certificate in $CurrentPath){
        If($Certificate.Subject-like"*, DC=utshare, DC=local"){
            $CurrentThumb=$Certificate.Thumbprint
            Remove-Item -Path Cert:\LocalMachine\$CertType\$CurrentThumb -Verbose
        }
    }
}
Set-Location $CurrentLocation;gpupdate /force
Set-Variable -Name WMI_Path -Value "$env:SystemRoot\System32\wbem\repository"
Set-Variable -Name WMI_Path_Old -Value "$WMI_Path-old"
Set-Variable -Name SCCM_ARDC_Server -Value "w16asccmdb01.inf.utshare.local"
Set-Variable -Name SCCM_UDCC_Server -Value "w16bsccmdb01.inf.utshare.local"
Set-Variable -Name SCCM_ARDC_Share -Value "SMS_DFW"
Set-Variable -Name SCCM_UDCC_Share -Value "SMS_AUS"
Set-Variable -Name SCCM_APPS -Value "sources\apps"
Set-Variable -Name SCCM_Client -Value "Client\ccmsetup.exe"
Set-Variable -Name IP_Address -Value $null
Set-Variable -Name Octet_1 -Value $null
Set-Variable -Name Octet_2 -Value $null
Set-Variable -Name Octet_3 -Value $null
Set-Variable -Name Octet_4 -Value $null
Set-Variable -Name ByPass -Value $false
Set-Variable -Name Primary_Site -Value $null
Set-Variable -Name SCCM_Client_Install -Value $null
Stop-Service -Name "Winmgmt" -Force
$Services=Get-Service|Where-Object{($_.Status-eq'Running')}
ForEach($Service In $Services){
    Switch($Service.Name){
        "Winmgmt"{$ByPass=$true;Break}
        Default{Break}
    }
}
If($ByPass-eq$false){
    If(Test-Path $WMI_Path_Old){Remove-Item $WMI_Path_Old -Recurse -Force -Verbose}
    Rename-Item -Path $WMI_Path -NewName $WMI_Path_Old
    Start-Service -Name "Winmgmt"
}
$IP_Address=Get-NetIpAddress|Where-Object{$_.AddressFamily-eq"IPv4"}
If($IP_Address-eq$null){
    $IP_Address=((ipconfig|findstr [0-9].\.)[0]).Split()[-1]
}Else{
    $IP_Address=$IP_Address.IPAddress
}
ForEach($IPv4 In $IP_Address){
    $Parser=$IPv4.Split(".")
    For($O=0;$O-le3;$O++){
        Switch($O){
            0{$Octet_1=$Parser[$O];Break}
            1{$Octet_2=$Parser[$O];Break}
            2{$Octet_3=$Parser[$O];Break}
            3{$Octet_4=$Parser[$O];Break}
        }
    }
    If($Octet_1-eq10){
        If(($Octet_2-eq118)-or($Octet_2-eq119)){
            $Primary_Site="\\$SCCM_ARDC_Server\$SCCM_ARDC_Share"
        }
        If(($Octet_2-eq126)-or($Octet_2-eq127)){
            $Primary_Site="\\$SCCM_UDCC_Server\$SCCM_UDCC_Share"
        }
        $SCCM_Client_Install="$Primary_Site\$SCCM_CLient";Break
    }
}
Set-Variable -Name LocalInstall -Value "$env:USERPROFILE\Downloads\ccmsetup.exe"
Set-Location -Path "$env:SystemRoot\System32"
If(!(Test-Path "$env:SystemRoot\System32\cmtrace.exe")){
    If(($Octet_2-eq118)-or($Octet_2-eq119)){
        Copy-Item -Path "\\$SCCM_ARDC_Server\$SCCM_APPS\cmtrace.exe"
    }
    If(($Octet_2-eq126)-or($Octet_2-eq127)){
        Copy-Item -Path "\\$SCCM_UDCC_Server\$SCCM_APPS\cmtrace.exe"
    }
}
If(!(Test-Path "$env:SystemRoot\System32\reboot.cmd")){
    If(($Octet_2-eq118)-or($Octet_2-eq119)){
        Copy-Item -Path "\\$SCCM_ARDC_Server\$SCCM_APPS\reboot.cmd"
    }
    If(($Octet_2-eq126)-or($Octet_2-eq127)){
        Copy-Item -Path "\\$SCCM_UDCC_Server\$SCCM_APPS\reboot.cmd"
    }
}
If(!($Primary_Site-eq$null)){
    If(!(Test-Path $LocalInstall)){
        Copy-Item -Path "$SCCM_Client_Install" -Destination $LocalInstall
    }
    For($L=0;$L-le2;$L++){
        Switch($L){
            0{
                Start-Process -FilePath $LocalInstall -ArgumentList "/uninstall"
                PauseForCompletion("ccmsetup");Break}
            1{
                Remove-Item "$env:systemroot\ccm*" -Recurse -Force -Verbose;Break}
            2{
                Start-Process -FilePath $LocalInstall
                PauseForCompletion("ccmsetup");Break}
        }
    }
}
Set-ExecutionPolicy Restricted
Logoff
