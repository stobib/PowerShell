Set-ExecutionPolicy -ExecutionPolicy ByPass
Set-ExecutionPolicy Unrestricted
Set-Variable -Name DomainName -Value $("$env:USERDNSDOMAIN").ToLower()
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
Set-Variable -Name Environment -Value $null
Set-Variable -Name Primary_Site -Value $null
Set-Variable -Name SCCM_Client_Install -Value $null
Set-Variable -Name CurrentLocation -Value $env:SystemRoot\System32
Set-Variable -Name Remove_Account -Value "sy1000829946"
Set-Variable -Name Profile_Path -Value "$env:SystemDrive\Users"
Net Time /DOMAIN:$DomainName /SET /Y
Clear-History;Clear-Host
Function PauseForCompletion($ProcessName){
    $ProcessID=(Get-Process -Name $ProcessName).Id
    Wait-Process -Id $ProcessID
}
Function Test-IsRegistryPOLGood{
    $PathToMachineRegistryPOLFile="$env:SytemRoot\System32\GroupPolicy\Machine\Registry.pol"
    $PathToUserRegistryPOLFile="$env:SytemRoot\System32\GroupPolicy\User\Registry.pol"
    If(!(Test-Path -Path $PathToMachineRegistryPOLFile -PathType Leaf)){}
    Else{
        If(((Get-Content -Encoding Byte -Path $PathToMachineRegistryPOLFile -TotalCount 4)-join'')-ne'8082101103'){
            If(Test-Path -Path $PathToMachineRegistryPOLFile){
                Remove-Item $PathToMachineRegistryPOLFile -Force
                Return $False
            }
        }
    }
    If(!(Test-Path -Path $PathToUserRegistryPOLFile -PathType Leaf)){}
    Else{
        If(((Get-Content -Encoding Byte -Path $PathToUserRegistryPOLFile -TotalCount 4)-join'')-ne'8082101103'){
            If(Test-Path -Path $PathToUserRegistryPOLFile){
                Remove-Item $PathToUserRegistryPOLFile -Force
                Return $False
            }
        }
    }
    Return $true
}
Function TimeStamp{$(Get-Date -UFormat "%D %T")}
For($Count=0;$Count-le1;$Count++){
    Switch($Count){
        0{$CertType="Root";Break}
        1{$CertType="CA";Break}
    }
    Set-Location Cert:\LocalMachine\$CertType;$CurrentPath=dir
    ForEach($Certificate in $CurrentPath){
        If($Certificate.Subject-like"*, DC=utshare, DC=local"){
            $CurrentThumb=$Certificate.Thumbprint
            Remove-Item -Path Cert:\LocalMachine\$CertType\$CurrentThumb
        }
    }
}
Set-Location $CurrentLocation
$IP_Address=Get-NetIpAddress|Where-Object{$_.AddressFamily-eq"IPv4"}
If(!($IP_Address-eq$null)){
    ForEach($IPv4 In $IP_Address.IPAddress){
        $Parser=$IPv4.Split(".")
        For($O=0;$O-le3;$O++){
            Switch($O){
                0{$Octet_1=$Parser[$O];Break}
                1{
                    $Octet_2=$Parser[$O]
                    If($Octet_1-eq10){
                        If(($Octet_2-eq118)-or($Octet_2-eq119)){
                            $Primary_Site="\\$SCCM_ARDC_Server\$SCCM_ARDC_Share"
                        }
                        If(($Octet_2-eq126)-or($Octet_2-eq127)){
                            $Primary_Site="\\$SCCM_UDCC_Server\$SCCM_UDCC_Share"
                        }
                        $SCCM_Client_Install="$Primary_Site\$SCCM_CLient"
                    };Break}
                2{
                    $Octet_3=$Parser[$O]
                    Switch($Octet_3){
                        {($_-eq0)-or($_-eq1)}{$Environment="inf";Break}
                        {($_-ge4)-and($_-le7)-or
                            ($_-ge20)-and($_-le23)-or
                            ($_-ge36)-and($_-le39)-or
                            ($_-ge52)-and($_-le55)-or
                            ($_-ge68)-and($_-le71)-or
                            ($_-ge84)-and($_-le87)}{$Environment="prd";Break}
                        {($_-ge8)-and($_-le11)-or
                            ($_-ge24)-and($_-le27)-or
                            ($_-ge40)-and($_-le43)-or
                            ($_-ge56)-and($_-le59)-or
                            ($_-ge72)-and($_-le75)-or
                            ($_-ge88)-and($_-le91)}{$Environment="nrp";Break}
                        {($_-ge12)-and($_-le15)-or
                            ($_-ge28)-and($_-le31)-or
                            ($_-ge44)-and($_-le47)-or
                            ($_-ge60)-and($_-le63)-or
                            ($_-ge76)-and($_-le79)-or
                            ($_-ge92)-and($_-le95)}{$Environment="non";Break}
                        {($_-eq18)-or($_-eq19)}{$Environment="vdi";Break}
                    };Break}
                3{$Octet_4=$Parser[$O];Break}
            }
            If($Octet_1-eq127){Break}
        }
    }
    Set-Variable -Name Counter -Value 0
    Set-Variable -Name Service -Value $null
    Set-Variable -Name ThisComputer -Value $("$env:COMPUTERNAME.$Environment.$env:USERDNSDOMAIN").ToLower()
    $Remove_Account=$Profile_Path+"\"+$Remove_Account
    If(Test-Path $Remove_Account){
        explorer $Remove_Account
        sysdm.cpl
    }
    $logfile="$env:temp\LocalPolicyCheck.log"
    $Compliance="Compliant"
    If((Test-IsRegistryPOLGood)-eq$true){
        $Compliance="Compliant"
    }Else{
        $Compliance="Non-Compliant"
    }
    $(TimeStamp)+" Local Policy Check Returned: "+$Compliance | Out-File -FilePath $Logfile -Append -Encoding ascii
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
    gpupdate /force
    Do{
        $Counter++
        $Service=Get-Service -Name "CcmExec"
        If($Service-eq$null){Break}
        Switch($Service.Status){
            'Starting'{Break}
            'Running'{$Service=Stop-Service -Name "CcmExec" -Force;Break}
            'StopPending'{
                If($Counter-ge500){
                    (Get-WmiObject -ComputerName $ThisComputer -Class Win32_Process -Filter "name like 'CcmExe%'").terminate()
                };Break}
        }
    }Until($Service.Status-eq'Stopped')
    $Service=Stop-Service -Name "Winmgmt" -Force
    Do{
        $Service=Get-Service -Name "Winmgmt"
        If($Service.Status-eq'Stopped'){
            If(Test-Path $WMI_Path_Old){Remove-Item $WMI_Path_Old -Recurse -Force}
            Rename-Item -Path $WMI_Path -NewName $WMI_Path_Old
            $Service=Start-Service -Name "Winmgmt"
        }
    }While(($Service.Status-eq'Stopped')-or($Service.Status-eq'Stopping'))
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
                    Remove-Item "$env:systemroot\ccm*" -Recurse -Force;Break}
                2{
                    Start-Process -FilePath $LocalInstall
                    PauseForCompletion("ccmsetup");Break}
            }
        }
    }
}
Set-ExecutionPolicy Restricted
Logoff
